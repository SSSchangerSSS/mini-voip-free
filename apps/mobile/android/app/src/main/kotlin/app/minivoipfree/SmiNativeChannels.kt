package app.minivoipfree

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SmiNativeChannels(private val applicationContext: Context) {
    private var mediaLoggingPrepared=false

    fun attach(flutterEngine: FlutterEngine) {
        FlutterBridge.instance.attachEngine(applicationContext, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FlutterBridge.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "verifyDeveloperPassword" -> SmiDeveloperGate.verify(applicationContext,call.argument<String>("password")?:"",result)
                        "configure" -> {
                            if(!mediaLoggingPrepared){
                                // Configure native debug output BEFORE Flutter injects its LogSink.
                                org.webrtc.PeerConnectionFactory.initialize(org.webrtc.PeerConnectionFactory.InitializationOptions.builder(applicationContext).setEnableInternalTracer(false).createInitializationOptions())
                                org.webrtc.Logging.enableLogToDebugOutput(org.webrtc.Logging.Severity.LS_NONE)
                                mediaLoggingPrepared=true
                            }
                            SmiIncomingService.start(applicationContext); result.success(null)
                        }
                        "suppressMediaLogs" -> { SmiCalls.suppressMediaLogs(); result.success(null) }
                        "updateReception" -> { SmiIncomingService.status(call.argument<Boolean>("registered")?:false); result.success(null) }
                        "openReceptionSetting" -> SmiReceptionSettings.open(applicationContext,call.argument<String>("target")?:"",result)
                        "openIncomingSettings" -> {
                            val full=Build.VERSION.SDK_INT>=34 && !applicationContext.getSystemService(android.app.NotificationManager::class.java).canUseFullScreenIntent()
                            val power=applicationContext.getSystemService(android.os.PowerManager::class.java)
                            val i=if(!power.isIgnoringBatteryOptimizations(applicationContext.packageName)) android.content.Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,android.net.Uri.parse("package:"+applicationContext.packageName))
                                else if(full) android.content.Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT",android.net.Uri.parse("package:"+applicationContext.packageName))
                                else android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE,applicationContext.packageName)
                            applicationContext.startActivity(i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK));result.success(null)
                        }
                        "getCapabilities" -> result.success(
                            mapOf(
                                "microphone" to granted("android.permission.RECORD_AUDIO"),
                                "notifications" to (if(Build.VERSION.SDK_INT>=33)granted("android.permission.POST_NOTIFICATIONS") else applicationContext.getSystemService(android.app.NotificationManager::class.java).areNotificationsEnabled()),
                                "fullScreenIntent" to (Build.VERSION.SDK_INT<34 || applicationContext.getSystemService(android.app.NotificationManager::class.java).canUseFullScreenIntent()),
                                "callstyle" to true,
                                "voipPush" to false,
                                "directIncoming" to true,
                                "standbyRunning" to SmiIncomingService.running,
                                "incomingChannelEnabled" to ((applicationContext.getSystemService(android.app.NotificationManager::class.java).getNotificationChannel(SmiCallNotifications.CHANNEL)?.importance ?: android.app.NotificationManager.IMPORTANCE_HIGH)>android.app.NotificationManager.IMPORTANCE_NONE),
                                "batteryUnrestricted" to applicationContext.getSystemService(android.os.PowerManager::class.java).isIgnoringBatteryOptimizations(applicationContext.packageName),
                                "platform" to "android",
                                "apiLevel" to Build.VERSION.SDK_INT,
                                "vendorBackgroundSetup" to SmiReceptionSettings.vendorSetupRequired(),
                                "vendorAutostartStatus" to (if(SmiReceptionSettings.vendorSetupRequired())"unknown" else "notApplicable"),
                            ),
                        )
                        "getPushToken" -> result.success(null)
                        "reportOutgoing" -> SmiCalls.begin(applicationContext,call.argument<String>("attemptId")!!,"تماس خروجی","",false,java.time.Instant.now().epochSecond+40,result)
                        "reportIncoming" -> SmiCalls.begin(applicationContext,call.argument<String>("callId")!!,call.argument<String>("callerName")?:"",call.argument<String>("caller")?:"",true,java.time.Instant.parse(call.argument<String>("expiresAt")).epochSecond,result)
                        "updateCallState" -> SmiCalls.changeState(call.argument<String>("nativeCallUuid")!!,call.argument<String>("state")!!,result)
                        "endCall" -> { SmiCalls.end(applicationContext,call.argument<String>("nativeCallUuid")?:"",false); result.success(null) }
                        "setMuted" -> result.success(null)
                        "setSpeaker" -> SmiCalls.speaker(call.argument<Boolean>("speakerOn")?:false,result)
                        "getPendingEvents" -> result.success(
                            SmiCallStore.instance.pendingEvents(applicationContext).toString(),
                        )
                        "ackEvent" -> {
                            val eventId = call.argument<String>("eventId")
                            if (eventId != null) SmiCallStore.instance.ack(applicationContext, eventId)
                            result.success(null)
                        }
                        "secureStore" -> handleSecureStore(call, result)
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    private fun handleSecureStore(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val op = call.argument<String>("op")
        val key = call.argument<String>("key") ?: return result.error("INVALID", "key required", null)
        val value = call.argument<String>("value")
        when (op) {
            "read" -> result.success(SecureStore.read(applicationContext, key))
            "write" -> {
                if (value == null) return result.error("INVALID", "value required", null)
                SecureStore.write(applicationContext, key, value)
                if(key=="smi.deviceGeneration") SmiCallStore.instance.setDeviceGeneration(applicationContext,value.toIntOrNull()?:1)
                result.success(null)
            }
            "delete" -> {
                SecureStore.delete(applicationContext, key)
                if(key=="smi.extension" || key=="smi.password")SmiIncomingService.stop(applicationContext)
                result.success(null)
            }
            else -> result.error("INVALID", "unknown op", null)
        }
    }

    private fun granted(permission: String): Boolean =
        applicationContext.checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED
}
