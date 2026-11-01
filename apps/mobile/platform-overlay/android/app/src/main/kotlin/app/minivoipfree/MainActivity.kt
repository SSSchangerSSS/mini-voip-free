package app.minivoipfree
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine = SmiEngine.get(context)
    override fun shouldDestroyEngineWithHost(): Boolean = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) { /* channels/plugins installed by SmiEngine */ }
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); visible=java.lang.ref.WeakReference(this); clearOldAppTasks(); handle(intent) }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); handle(intent) }
    override fun onResume() {
        super.onResume()
        if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED && !getPreferences(0).getBoolean("notificationAsked",false)) {
            getPreferences(0).edit().putBoolean("notificationAsked",true).apply()
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),4102)
        }
    }
    private var setupResult:io.flutter.plugin.common.MethodChannel.Result?=null
    override fun onRequestPermissionsResult(code:Int,permissions:Array<out String>,results:IntArray){
        super.onRequestPermissionsResult(code,permissions,results)
        if(code==4210){setupResult?.success(if(results.isNotEmpty() && results[0]==android.content.pm.PackageManager.PERMISSION_GRANTED)"granted" else "denied");setupResult=null}
    }
    private fun clearOldAppTasks() {
        // Upgrading from singleTop can leave old call tasks in Recents. Remove
        // only this app's other tasks; the retained engine and account survive.
        val manager=getSystemService(android.app.ActivityManager::class.java)
        for(task in manager.appTasks){
            @Suppress("DEPRECATION")
            val otherId=if(Build.VERSION.SDK_INT>=29)task.taskInfo.taskId else task.taskInfo.persistentId
            if(otherId!=taskId)runCatching{task.finishAndRemoveTask()}.onFailure{
                android.util.Log.w("SmiTask","Old task cleanup unavailable: ${it.javaClass.simpleName}")
            }
        }
    }
    private fun handle(i: Intent?) {
        if(i?.action!=SmiTelecomCallService.OPEN && i?.action!=SmiTelecomCallService.ANSWER) return
        if(Build.VERSION.SDK_INT>=27){setShowWhenLocked(true);setTurnScreenOn(true)}
        else window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        val id=i.getStringExtra("callId")?:return
        if(i.action==SmiTelecomCallService.ANSWER) SmiCalls.intent(applicationContext,id,"answerRequested")
        i.action=SmiTelecomCallService.OPEN // Never replay answer on Activity recreation.
    }
    override fun onDestroy(){setupResult?.error("ACTIVITY_CLOSED","Setup screen closed",null);setupResult=null;if(visible?.get()===this)visible=null;super.onDestroy()}
    companion object {
        private var visible:java.lang.ref.WeakReference<MainActivity>?=null
        fun requestSetupPermission(permission:String,result:io.flutter.plugin.common.MethodChannel.Result){
            val activity=visible?.get()
            if(activity==null || activity.isFinishing){result.error("ACTIVITY_REQUIRED","Open the app to set up calling",null);return}
            if(activity.checkSelfPermission(permission)==android.content.pm.PackageManager.PERMISSION_GRANTED){result.success("alreadyGranted");return}
            if(activity.setupResult!=null){result.error("PERMISSION_PENDING","A permission request is already open",null);return}
            val prefs=activity.getPreferences(0)
            val asked=prefs.getBoolean("setupAsked:"+permission,false) || (permission==android.Manifest.permission.POST_NOTIFICATIONS && prefs.getBoolean("notificationAsked",false))
            if(asked && !activity.shouldShowRequestPermissionRationale(permission)){
                if(permission==android.Manifest.permission.POST_NOTIFICATIONS){
                    activity.startActivity(android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(android.provider.Settings.EXTRA_APP_PACKAGE,activity.packageName))
                    result.success("notifications")
                }else{
                    activity.startActivity(android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:"+activity.packageName)))
                    result.success("appInfoFallback")
                }
                return
            }
            prefs.edit().putBoolean("setupAsked:"+permission,true).apply()
            activity.setupResult=result
            activity.requestPermissions(arrayOf(permission),4210)
        }
        fun releaseCallWindow(){visible?.get()?.let{activity->activity.runOnUiThread{
            if(Build.VERSION.SDK_INT>=27){activity.setShowWhenLocked(false);activity.setTurnScreenOn(false)}
            else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }}}
    }

}
