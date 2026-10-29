package app.minivoipfree

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.ServiceCompat
import org.json.JSONObject
import java.time.Instant

/**
 * phoneCall foreground service during a call (spec 9.4, [S13][S14]):
 *  - publishes a CallStyle incoming-call notification within the system window;
 *  - hosts the call lifecycle so the microphone policy and lifecycle survive
 *    Activity teardown;
 *  - STOPS itself after the last call ends and removes the ongoing notification.
 *
 * Full-screen intent usage respects `canUseFullScreenIntent` on Android 14+ ([S15]);
 * when unavailable, the heads-up notification is still shown. Telecom (Connection
 * / CallControl) integration is completed in P3 — this scaffold keeps a single
 * call slot and never claims default-dialer behaviour.
 */
class SmiTelecomCallService : Service() {

    override fun onCreate() {
        super.onCreate()
        // Every supported release (Android 8+) requires an existing channel
        // before a foreground notification can be posted.
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "تماس‌ها", NotificationManager.IMPORTANCE_HIGH),
        )
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callId = intent?.getStringExtra(EXTRA_CALL_ID)
        val caller = intent?.getStringExtra(EXTRA_CALLER) ?: ""
        val expiresAt = intent?.getLongExtra(EXTRA_EXPIRES_AT, 0L) ?: 0L

        when (intent?.action) {
            ACTION_ANSWER_FROM_NOTIFICATION -> {
                SmiCallStore.instance.enqueueAnswer(applicationContext, callId ?: return START_NOT_STICKY)
                FlutterBridge.instance.dispatchIfAlive(
                    "answerRequested",
                    JSONObject().put("callId", callId),
                )
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_DECLINE_FROM_NOTIFICATION -> {
                SmiCallStore.instance.enqueueEnd(applicationContext, callId ?: "", "declined")
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                startInForeground(callId ?: "unknown", caller, expiresAt)
            }
        }
        return START_NOT_STICKY
    }

    private fun startInForeground(callId: String, caller: String, expiresAtEpoch: Long) {
        val open = PendingIntent.getActivity(
            this, callId.hashCode(),
            Intent(this, MainActivity::class.java).apply {
                putExtra(EXTRA_CALL_ID, callId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val answer = PendingIntent.getService(
            this, (callId + "a").hashCode(),
            Intent(this, SmiTelecomCallService::class.java).apply {
                action = ACTION_ANSWER_FROM_NOTIFICATION
                putExtra(EXTRA_CALL_ID, callId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val decline = PendingIntent.getService(
            this, (callId + "d").hashCode(),
            Intent(this, SmiTelecomCallService::class.java).apply {
                action = ACTION_DECLINE_FROM_NOTIFICATION
                putExtra(EXTRA_CALL_ID, callId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val callerPerson = Person.Builder().setName("داخلی $caller").build()
        val remainingSec = maxOf(1L, expiresAtEpoch - Instant.now().epochSecond)

        val notification: Notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_call)
                .setContentTitle("تماس ورودی")
                .setContentText("داخلی $caller")
                .setOngoing(true)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .addPerson(callerPerson.uri.toString())
                .setStyle(
                    NotificationCompat.CallStyle.forIncomingCall(
                        callerPerson, decline, answer,
                    ).setIsVideo(false),
                )
                .setTimeoutAfter(remainingSec * 1000)
                .build()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        const val CHANNEL_ID = "smi_calls"
        const val ACTION_ANSWER_FROM_NOTIFICATION = "app.minivoipfree.ANSWER"
        const val ACTION_DECLINE_FROM_NOTIFICATION = "app.minivoipfree.DECLINE"
        const val EXTRA_CALL_ID = "callId"
        const val EXTRA_CALLER = "caller"
        const val EXTRA_EXPIRES_AT = "expiresAtEpoch"
        private const val NOTIFICATION_ID = 4101

        fun startForIncoming(ctx: Context, callId: String, caller: String, expiresAtEpoch: Long) {
            val i = Intent(ctx, SmiTelecomCallService::class.java).apply {
                putExtra(EXTRA_CALL_ID, callId)
                putExtra(EXTRA_CALLER, caller)
                putExtra(EXTRA_EXPIRES_AT, expiresAtEpoch)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        /** Best-effort ring suppression on FCM cancel (never load-bearing, spec 5.4). */
        fun suppressRingIfPending(ctx: Context, callId: String) {
            val manager = ctx.getSystemService(NotificationManager::class.java)
            manager.cancel(callId.hashCode())
            manager.cancel(NOTIFICATION_ID)
        }
    }
}
