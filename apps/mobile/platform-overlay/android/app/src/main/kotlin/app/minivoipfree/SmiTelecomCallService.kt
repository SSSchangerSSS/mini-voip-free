package app.minivoipfree
import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.os.*
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import java.time.Instant

class SmiCallNotifications(private val service:SmiIncomingService) {
    private fun <T> system(c:Class<T>):T=service.getSystemService(c)
    private var current:String?=null
    private var lastNumber=""
    private var lastName=""
    private var lastExpiry=0L
    private var ringing=true
    private val main=Handler(Looper.getMainLooper())
    init {
        // A process restart cannot keep the old call/media session alive.
        system(NotificationManager::class.java).apply{cancel(4101);cancel(4102)}
        val channel=NotificationChannel(CHANNEL,"تماس‌های داخلی",NotificationManager.IMPORTANCE_HIGH)
        channel.setSound(Settings.System.DEFAULT_RINGTONE_URI,AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
        channel.enableVibration(true);system(NotificationManager::class.java).createNotificationChannel(channel)
        val active=NotificationChannel(ACTIVE_CHANNEL,"مکالمه داخلی",NotificationManager.IMPORTANCE_LOW)
        active.setSound(null,null);active.enableVibration(false)
        system(NotificationManager::class.java).createNotificationChannel(active)
    }
    fun show(i:Intent):Int {
        val id=i.getStringExtra("callId")?:return Service.START_NOT_STICKY
        if((i.action==CONNECTED || i.action==SILENCE) && current!=id)return Service.START_NOT_STICKY
        if(current!=null && current!=id){
            main.removeCallbacksAndMessages(null)
            service.clearCall()
            system(NotificationManager::class.java).apply{cancel(4101);cancel(4102)}
        }
        val number=i.getStringExtra("number")?:lastNumber;val name=i.getStringExtra("name")?:lastName
        // Once answered/silenced, a delayed duplicate START must never restart the ringtone.
        val wasRinging=current==id && ringing
        val incoming=if(i.action==CONNECTED || i.action==SILENCE || SmiCalls.ringingSuppressed(id) || (current==id && !ringing))false else i.getBooleanExtra("incoming",true)
        val expiry=i.getLongExtra("expiry",lastExpiry)
        lastNumber=number;lastName=name;lastExpiry=expiry;ringing=incoming;current=id
        val open=PendingIntent.getActivity(service,id.hashCode(),Intent(service,MainActivity::class.java).setAction(OPEN).putExtra("callId",id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val answer=PendingIntent.getActivity(service,(id+"answer").hashCode(),Intent(service,MainActivity::class.java).setAction(ANSWER).putExtra("callId",id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val end=PendingIntent.getBroadcast(service,(id+"end").hashCode(),Intent(service,SmiCallActionReceiver::class.java).setAction(if(incoming)DECLINE else END).putExtra("callId",id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val person=Person.Builder().setName(if(name.isBlank())"داخلی $number" else "$name · $number").setImportant(true).build()
        val builder=NotificationCompat.Builder(service,if(incoming)CHANNEL else ACTIVE_CHANNEL).setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle(if(incoming)"تماس ورودی" else "تماس داخلی").setContentText(person.name)
            .setCategory(NotificationCompat.CATEGORY_CALL).setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true).setOnlyAlertOnce(true).setSilent(!incoming).setContentIntent(open).setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(if(incoming)NotificationCompat.CallStyle.forIncomingCall(person,end,answer) else NotificationCompat.CallStyle.forOngoingCall(person,end))
        if(incoming && (Build.VERSION.SDK_INT<34 || system(NotificationManager::class.java).canUseFullScreenIntent()))builder.setFullScreenIntent(open,true)
        val notification=builder.build()
        if(incoming)notification.flags=notification.flags or Notification.FLAG_INSISTENT
        // Switch the existing service's foreground notification first. The previous
        // ID can then be cancelled explicitly, stopping INSISTENT sound/vibration.
        service.presentCall(if(incoming)4101 else 4102,notification,SmiCalls.active)
        if(wasRinging && !incoming)system(NotificationManager::class.java).cancel(4101)
        if(incoming)main.postDelayed({if(current==id&&!SmiCalls.active)SmiCalls.end(service,id,false)},maxOf(1,expiry-Instant.now().epochSecond)*1000)
        // API26-28 permit this lock-screen fallback; newer releases own FSI policy.
        val power=system(PowerManager::class.java)
        val notifications=system(NotificationManager::class.java)
        val legacyAllowed=notifications.areNotificationsEnabled() && notifications.currentInterruptionFilter==NotificationManager.INTERRUPTION_FILTER_ALL && (notifications.getNotificationChannel(CHANNEL)?.importance?:0)>=NotificationManager.IMPORTANCE_HIGH
        if(incoming && legacyAllowed && Build.VERSION.SDK_INT<29 && (!power.isInteractive || system(KeyguardManager::class.java).isKeyguardLocked)) {
            @Suppress("DEPRECATION")
            val wake=power.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,"mini-voip-free:incoming-screen")
            wake.acquire(10000)
            service.startActivity(Intent(service,MainActivity::class.java).setAction(OPEN).putExtra("callId",id).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
        }
        return Service.START_NOT_STICKY
    }
    fun end(id:String){
        if(current!=id)return
        current=null;ringing=false;main.removeCallbacksAndMessages(null)
        service.clearCall()
        system(NotificationManager::class.java).apply{cancel(4101);cancel(4102)}
    }
    fun dispose(){main.removeCallbacksAndMessages(null);system(NotificationManager::class.java).apply{cancel(4101);cancel(4102)}}
    companion object {
        const val ACTIVE_CHANNEL="smi_calls_active"
        const val SILENCE="app.minivoipfree.SILENCE_RINGING"
        const val CONNECTED="app.minivoipfree.CONNECTED"
        const val OPEN="app.minivoipfree.INCOMING"
        const val ANSWER="app.minivoipfree.ANSWER"
        const val DECLINE="app.minivoipfree.DECLINE"
        const val END="app.minivoipfree.END"
        const val CHANNEL="smi_calls_v2"
    }
}
/** Notification operations reuse the live standby service; no new background FGS start. */
object SmiTelecomCallService {
    const val OPEN=SmiCallNotifications.OPEN
    const val ANSWER=SmiCallNotifications.ANSWER
    const val DECLINE=SmiCallNotifications.DECLINE
    const val END=SmiCallNotifications.END
    private var presenter:SmiCallNotifications?=null
    fun attach(service:SmiIncomingService){presenter=SmiCallNotifications(service)}
    fun detach(){presenter?.dispose();presenter=null}
    fun connected(ctx:Context,id:String){presenter?.show(Intent().setAction(SmiCallNotifications.CONNECTED).putExtra("callId",id))}
    fun silence(ctx:Context,id:String){presenter?.show(Intent().setAction(SmiCallNotifications.SILENCE).putExtra("callId",id))}
    fun end(ctx:Context,id:String){presenter?.end(id)}
    fun start(ctx:Context,id:String,name:String,number:String,incoming:Boolean,expiry:Long){
        val p=presenter?:throw IllegalStateException("Incoming standby service is not running")
        p.show(Intent().putExtra("callId",id).putExtra("name",name).putExtra("number",number).putExtra("incoming",incoming).putExtra("expiry",expiry))
    }
}

class SmiCallActionReceiver:BroadcastReceiver() {
    override fun onReceive(ctx:Context,i:Intent){
        val id=i.getStringExtra("callId")?:return
        when(i.action){SmiTelecomCallService.DECLINE->SmiCalls.intent(ctx,id,"declineRequested");SmiTelecomCallService.END->SmiCalls.intent(ctx,id,"endRequested")}
    }
}
