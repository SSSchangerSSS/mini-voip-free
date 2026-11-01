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
