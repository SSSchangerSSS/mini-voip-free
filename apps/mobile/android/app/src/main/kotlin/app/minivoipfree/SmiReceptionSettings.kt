package app.minivoipfree

import android.Manifest
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** User-initiated setup only. Never grants permissions or guesses OEM permission state. */
object SmiReceptionSettings {
    fun vendorSetupRequired():Boolean = listOf(Build.MANUFACTURER,Build.BRAND).any {
        it.lowercase(Locale.ROOT) in listOf("xiaomi","poco","redmi")
    }
    fun open(ctx:Context,target:String,result:MethodChannel.Result) {
        when(target){
            "microphone" -> {MainActivity.requestSetupPermission(Manifest.permission.RECORD_AUDIO,result);return}
            "notifications" -> {
                if(Build.VERSION.SDK_INT>=33 && ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){
                    MainActivity.requestSetupPermission(Manifest.permission.POST_NOTIFICATIONS,result);return
                }
                launch(ctx,Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,ctx.packageName),"notifications",result)
            }
            "battery" -> {
                val power=ctx.getSystemService(android.os.PowerManager::class.java)
                if(power.isIgnoringBatteryOptimizations(ctx.packageName)){result.success("alreadyGranted");return}
                launch(ctx,Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,Uri.parse("package:"+ctx.packageName)),"battery",result)
            }
            "fullscreen" -> {
                if(Build.VERSION.SDK_INT<34 || ctx.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()){result.success("alreadyGranted");return}
                launch(ctx,Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,Uri.parse("package:"+ctx.packageName)),"fullscreen",result)
            }
            "autostart" -> {
                if(vendorSetupRequired()){
                    // Optional HyperOS route: discover an exported, accessible activity.
                    // Existence/launching is NOT evidence that autostart is enabled.
                    val intent=Intent().setComponent(ComponentName("com.miui.securitycenter","com.miui.permcenter.autostart.AutoStartManagementActivity"))
                    val info=ctx.packageManager.resolveActivity(intent,0)?.activityInfo
                    if(info!=null && info.exported && (info.permission==null || ctx.checkSelfPermission(info.permission)==PackageManager.PERMISSION_GRANTED)){
                        try {ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));result.success("vendorAutostart");return}
                        catch(_:android.content.ActivityNotFoundException){}
                        catch(_:SecurityException){}
                    }
                }
                appInfo(ctx,result,"appInfoFallback")
            }
            "appInfo" -> appInfo(ctx,result,"appInfo")
            else -> result.error("INVALID_SETTING","Unknown setup step",null)
        }
    }
    private fun appInfo(ctx:Context,result:MethodChannel.Result,route:String){
        ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+ctx.packageName)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));result.success(route)
    }
    private fun launch(ctx:Context,intent:Intent,route:String,result:MethodChannel.Result){
        try {ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));result.success(route)}
        catch(_:android.content.ActivityNotFoundException){appInfo(ctx,result,"appInfoFallback")}
        catch(_:SecurityException){appInfo(ctx,result,"appInfoFallback")}
    }
}
