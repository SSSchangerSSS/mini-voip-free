package app.minivoipfree

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.time.Instant
import java.util.UUID

/**
 * The ONE FCM receiver of the app (spec 9.4). Parses the push schema defensively
 * (type/range/UUID — never crash on malformed input), then either:
 *  - incoming_call → post a CallStyle notification and start the phoneCall foreground
 *    service, and forward the event to the Flutter engine if it is alive (the event is
 *    also queued natively so a cold start replays it, spec 10.3);
 *  - cancel_call   → best-effort ring suppression only; correctness never DEPENDS on it
 *    (spec 5.4: server deadline + SIP CANCEL are authoritative).
 * No long-running work happens here (onMessageReceived constraint, [S11][S12]).
 */
class SmiFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        SmiCallStore.instance.pushTokenChanged(applicationContext, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data ?: return
        val type = data["type"] ?: return
        val schemaVersion = data["schemaVersion"]?.toIntOrNull() ?: return
        if (schemaVersion != 1) return

        when (type) {
            "incoming_call" -> handleIncoming(data)
            "cancel_call" -> handleCancel(data)
            else -> { /* unknown type — ignored, never crash (spec 9.1) */ }
        }
    }

    private fun handleIncoming(data: Map<String, String>) {
        val callId = data["callId"]?.let { runCatching { UUID.fromString(it) }.getOrNull() } ?: return
        val caller = data["callerExtension"]?.takeIf { it.matches(Regex("1[0-9][0-9]")) } ?: return
        val generation = data["deviceGeneration"]?.toIntOrNull() ?: return
        val expiresAtEpoch = data["expiresAt"]?.let {
            runCatching { Instant.parse(it).epochSecond }.getOrNull()
        } ?: return

        if (SmiCallStore.instance.deviceGeneration(applicationContext) != generation) {
            Log.i(TAG, "stale push for generation $generation — ignored")
            return
        }
        // The device may have been re-bound; the server remains the final authority —
        // this check is only a fast local filter.

        SmiCallStore.instance.enqueueIncoming(
            applicationContext,
            callId = callId.toString(),
            caller = caller,
            expiresAtEpoch = expiresAtEpoch,
        )

        SmiTelecomCallService.startForIncoming(applicationContext, callId.toString(), caller, expiresAtEpoch)
        postCallNotification(callId.toString(), caller)
    }

    private fun handleCancel(data: Map<String, String>) {
        val callId = data["callId"] ?: return
        SmiTelecomCallService.suppressRingIfPending(applicationContext, callId)
    }

    private fun postCallNotification(callId: String, caller: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_CALLS, "تماس‌ها", NotificationManager.IMPORTANCE_HIGH)
            )
        }

        val fullScreen = Intent(this, MainActivity::class.java).apply {
            action = SmiTelecomCallService.ACTION_ANSWER_FROM_NOTIFICATION
            putExtra(SmiTelecomCallService.EXTRA_CALL_ID, callId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        // full-screen intent availability is Android-14+ permission-gated ([S15]); when
        // unavailable the heads-up notification below still appears.
        val fullScreenPending = PendingIntent.getActivity(
            this, callId.hashCode(), fullScreen,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_CALLS)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("تماس ورودی")
            .setContentText("داخلی $caller")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPending, true)
            .setOngoing(true)
            .build()
        manager.notify(callId.hashCode(), notification)
    }

    companion object {
        private const val TAG = "SmiFcm"
        private const val CHANNEL_CALLS = "smi_calls"
    }
}
