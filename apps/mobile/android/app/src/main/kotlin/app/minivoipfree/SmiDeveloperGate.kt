package app.minivoipfree

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/** UI configuration gate only; does not replace server authentication or TLS. */
object SmiDeveloperGate {
    @Synchronized fun verify(ctx:Context,password:String,result:MethodChannel.Result) {
        val prefs=ctx.getSharedPreferences("smi-developer-gate",Context.MODE_PRIVATE)
        if(BuildConfig.SMI_DEVELOPER_HASH.isEmpty() || password.length>256 || prefs.getLong("blockedUntil",0)>System.currentTimeMillis()) {
            result.success(false);return
        }
        Thread {
            val valid=try {
                val spec=PBEKeySpec(password.toCharArray(),Base64.decode(BuildConfig.SMI_DEVELOPER_SALT,Base64.NO_WRAP),120000,256)
                val actual=SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
                spec.clearPassword()
                MessageDigest.isEqual(actual,Base64.decode(BuildConfig.SMI_DEVELOPER_HASH,Base64.NO_WRAP))
            } catch(_:Exception){false}
            synchronized(this) {
                val count=if(valid)0 else prefs.getInt("failures",0)+1
                prefs.edit().putInt("failures",if(count>=5)0 else count).putLong("blockedUntil",if(count>=5)System.currentTimeMillis()+60000 else 0).apply()
            }
            Handler(Looper.getMainLooper()).post{result.success(valid)}
        }.start()
    }
}
