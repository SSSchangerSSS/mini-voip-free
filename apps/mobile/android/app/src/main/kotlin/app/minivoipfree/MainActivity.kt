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

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterBridge.instance.attachEngine(applicationContext, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FlutterBridge.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "configure" -> result.success(null)
                        "getCapabilities" -> result.success(
                            mapOf(
                                "microphone" to granted("android.permission.RECORD_AUDIO"),
                                "notifications" to granted("android.permission.POST_NOTIFICATIONS"),
                                "callstyle" to true,
                                "voipPush" to true,
                                "platform" to "android",
                            ),
                        )
                        "getPushToken" -> result.success(SmiFirebaseTokenHolder.token)
                        "reportOutgoing" -> result.success(null)
                        "updateCallState" -> result.success(null)
                        "endCall" -> {
                            val callId = call.argument<String>("nativeCallUuid")
                            if (callId != null) {
                                SmiCallStore.instance.enqueueEnd(applicationContext, callId, "ended")
                            }
                            SmiTelecomCallService.suppressRingIfPending(applicationContext, callId ?: "")
                            result.success(null)
                        }
                        "setMuted" -> result.success(null)
                        "setSpeaker" -> result.success(null)
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
                result.success(null)
            }
            "delete" -> {
                SecureStore.delete(applicationContext, key)
                result.success(null)
            }
            else -> result.error("INVALID", "unknown op", null)
        }
    }

    private fun granted(permission: String): Boolean =
        checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED
}

/** Android Keystore + AES-GCM with fresh IV (spec 10.1). No biometric gate per call. */
object SecureStore {
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val MASTER_ALIAS = "smi_master_key"
    private const val TRANSFORM = "AES/GCM/NoPadding"

    fun write(ctx: Context, key: String, value: String) {
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.ENCRYPT_MODE, masterKey())
        val iv = cipher.iv
        val ct = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        prefs(ctx).edit()
            .putString("iv:$key", Base64.encodeToString(iv, Base64.NO_WRAP))
            .putString("ct:$key", Base64.encodeToString(ct, Base64.NO_WRAP))
            .apply()
    }

    fun read(ctx: Context, key: String): String? {
        val iv = Base64.decode(prefs(ctx).getString("iv:$key", null) ?: return null, Base64.NO_WRAP)
        val ct = Base64.decode(prefs(ctx).getString("ct:$key", null) ?: return null, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.DECRYPT_MODE, masterKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ct), Charsets.UTF_8)
    }

    fun delete(ctx: Context, key: String) {
        prefs(ctx).edit().remove("iv:$key").remove("ct:$key").apply()
    }

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences("smi_secure", Context.MODE_PRIVATE)

    private fun masterKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (ks.getKey(MASTER_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                MASTER_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(false) // no biometric gate per call (spec 10.1)
                .build(),
        )
        return generator.generateKey()
    }
}

/** FCM token hand-off from the messaging service to the method channel. */
object SmiFirebaseTokenHolder {
    @Volatile
    var token: String? = null
}

/** installationId helper (CSPRNG UUID, spec 4.1) used before Dart is alive. */
object SmiIds {
    fun newInstallationId(): String = UUID.randomUUID().toString()

    fun supportsCallStyle(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
}
