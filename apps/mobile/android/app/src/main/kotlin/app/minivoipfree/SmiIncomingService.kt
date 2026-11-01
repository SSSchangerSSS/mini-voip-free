package app.minivoipfree

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.wifi.WifiManager
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import org.json.JSONObject

/** Local PBX standby: no cloud SDK, account, token or public Internet required. */
class SmiIncomingService:Service() {
    private val handler=Handler(Looper.getMainLooper())
    private var wake:PowerManager.WakeLock?=null
    private var wifi:WifiManager.WifiLock?=null
    private var registered=false
    private var inCall=false
    private var callNotification:Notification?=null
    private var callNotificationId=0
    private val tick=object:Runnable{override fun run(){
        FlutterBridge.instance.dispatchIfAlive("receptionCheckRequested",JSONObject())
        handler.postDelayed(this,5000)
    }}
    private val network=object:ConnectivityManager.NetworkCallback(){
        override fun onAvailable(n:Network){handler.post{FlutterBridge.instance.dispatchIfAlive("receptionCheckRequested",JSONObject())}}
        override fun onLost(n:Network){handler.post{registered=false;showStatus()}}
    }
    override fun onBind(intent:Intent?)=null
    override fun onCreate(){
        super.onCreate();running=true;instance=this
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(CHANNEL,"آماده‌باش تماس داخلی",NotificationManager.IMPORTANCE_LOW))
        showStatus()
        SmiTelecomCallService.attach(this)
        wake=getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"mini-voip-free:incoming").apply{setReferenceCounted(false);acquire()}
        @Suppress("DEPRECATION")
        wifi=(applicationContext.getSystemService(WIFI_SERVICE) as WifiManager).createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF,"mini-voip-free:incoming").apply{setReferenceCounted(false);acquire()}
        getSystemService(ConnectivityManager::class.java).registerDefaultNetworkCallback(network)
        handler.post(tick)
    }
    override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
        if(!hasAccount(this)){stopSelf();return START_NOT_STICKY}
        SmiEngine.get(applicationContext)
        return START_STICKY
    }
    private fun showStatus(){
        val open=PendingIntent.getActivity(this,4201,Intent(this,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n=NotificationCompat.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("تماس داخلی · اتصال مستقیم")
            .setContentText(if(registered){if(SmiReceptionSettings.vendorSetupRequired())"اتصال آماده؛ تنظیمات HyperOS نیازمند بررسی" else "آماده دریافت تماس از سرور شرکت"} else "دریافت آماده نیست؛ برنامه را برای بررسی باز کنید")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true).setSilent(true).build()
        ServiceCompat.startForeground(this,if(callNotification!=null)callNotificationId else 4201,callNotification?:n,(if(Build.VERSION.SDK_INT>=34)ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0) or (if(inCall && Build.VERSION.SDK_INT>=29)ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL else 0))
    }
    fun presentCall(id:Int,notification:Notification,active:Boolean){
        callNotificationId=id;callNotification=notification;inCall=active
        showStatus()
        getSystemService(NotificationManager::class.java).cancel(4201)
    }
    fun clearCall(){callNotification=null;callNotificationId=0;inCall=false;showStatus()}
    override fun onTaskRemoved(rootIntent:Intent?){
        // Removing the UI task must not remove the user-enabled standby engine.
        FlutterBridge.instance.dispatchIfAlive("receptionCheckRequested",JSONObject())
        super.onTaskRemoved(rootIntent)
    }
    override fun onDestroy(){
        SmiTelecomCallService.detach()
        running=false;instance=null;handler.removeCallbacksAndMessages(null)
        runCatching{getSystemService(ConnectivityManager::class.java).unregisterNetworkCallback(network)}
        wake?.let{if(it.isHeld)it.release()};wifi?.let{if(it.isHeld)it.release()}
        super.onDestroy()
    }
    companion object {
        const val CHANNEL="smi_direct_incoming"
        var running=false;private set
        private var instance:SmiIncomingService?=null
        fun hasAccount(ctx:Context)=!SecureStore.read(ctx,"smi.extension").isNullOrBlank()&&!SecureStore.read(ctx,"smi.password").isNullOrBlank()
        fun start(ctx:Context){if(hasAccount(ctx))ctx.startForegroundService(Intent(ctx,SmiIncomingService::class.java))}
        fun stop(ctx:Context){ctx.stopService(Intent(ctx,SmiIncomingService::class.java))}
        fun status(ready:Boolean){instance?.let{if(it.registered!=ready){it.registered=ready;it.showStatus()}}}
    }
}
class SmiBootReceiver:BroadcastReceiver(){
    override fun onReceive(ctx:Context,intent:Intent){
        if(intent.action !in listOf(Intent.ACTION_BOOT_COMPLETED,Intent.ACTION_MY_PACKAGE_REPLACED))return
        try{SmiIncomingService.start(ctx)}catch(e:Exception){Log.w("SmiIncoming","Standby start unavailable: ${e.javaClass.simpleName}")}
    }
}
