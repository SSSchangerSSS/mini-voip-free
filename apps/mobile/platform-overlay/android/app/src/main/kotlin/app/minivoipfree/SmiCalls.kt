package app.minivoipfree
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telecom.DisconnectCause
import androidx.core.telecom.*
import com.cloudwebrtc.webrtc.audio.AudioSwitchManager
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import org.json.JSONObject

object SmiCalls {
    private val jobs=CoroutineScope(SupervisorJob()+Dispatchers.Main.immediate)
    private var manager:CallsManager?=null
    private var context:Context?=null
    var id:String?=null;private set
    var active=false;private set
    private var incoming=false
    private var ringSilenced=false
    fun ringingSuppressed(callId:String)=id!=callId || ringSilenced
    private var control:CallControlScope?=null
    private var ready:CompletableDeferred<Unit>?=null
    private var callJob:Job?=null
    private var endpoints:List<CallEndpointCompat> = emptyList()
    private var desiredSpeaker=false
    private var actualSpeaker:Boolean?=null
    fun suppressMediaLogs() {
            org.webrtc.PeerConnectionFactory.shutdownInternalTracer()
            // Pinned WebRTC SDK keeps native debug output separate from injected LogSink.
            // Disable that output after Flutter factory initialization (decision0013).
            val sink=org.webrtc.PeerConnectionFactory::class.java.getDeclaredMethod("nativeDeleteLoggable")
            sink.isAccessible=true
            sink.invoke(null)
            val logging=org.webrtc.Logging::class.java.getDeclaredMethod("nativeEnableLogToDebugOutput",Int::class.javaPrimitiveType)
            logging.isAccessible=true
            logging.invoke(null,org.webrtc.Logging.Severity.LS_NONE.ordinal)
            android.util.Log.i("SmiMediaPrivacy","APPLIED") // Fixed metadata only; never SDP or credentials.
    }
    fun begin(ctx:Context,callId:String,name:String,number:String,isIncoming:Boolean,expiry:Long,result:MethodChannel.Result?) {
        if(id!=null && id!=callId){result?.error("NATIVE_BUSY","Another native call is active",null);return}
        if(id==callId){replyReady(result);return}
        try {
            context=ctx.applicationContext
            val cm=manager?:CallsManager(ctx).also{it.registerAppWithTelecom(CallsManager.CAPABILITY_BASELINE);manager=it}
            suppressMediaLogs()
            AudioSwitchManager.setAudioSessionManagementEnabled(false) // Telecom is the sole audio-route owner.
            id=callId;incoming=isIncoming;active=false;ringSilenced=false;desiredSpeaker=false;actualSpeaker=null;ready=CompletableDeferred()
            SmiTelecomCallService.start(ctx,callId,name,number,isIncoming,expiry)
            val callReady=ready!!
            callJob=jobs.launch {
                try {
                    cm.addCall(CallAttributesCompat(if(name.isBlank())"داخلی $number" else "$name · $number",Uri.parse("smi:$number"),if(isIncoming)CallAttributesCompat.DIRECTION_INCOMING else CallAttributesCompat.DIRECTION_OUTGOING,callType=CallAttributesCompat.CALL_TYPE_AUDIO_CALL,callCapabilities=0),
                        onAnswer={intent(ctx,callId,"answerRequested")},
                        onDisconnect={intent(ctx,callId,if(isIncoming&&!active)"declineRequested" else "endRequested")},
                        onSetActive={},onSetInactive={throw IllegalStateException("Hold is not supported")}) {
                        control=this
                        callReady.complete(Unit)
                        launch{availableEndpoints.collect{endpoints=it;selectRoute(desiredSpeaker)}}
                        launch{currentCallEndpoint.collect{actualSpeaker=it.type==CallEndpointCompat.TYPE_SPEAKER;FlutterBridge.instance.dispatchIfAlive("capabilityChanged",JSONObject().put("callId",callId).put("speakerOn",actualSpeaker))}}
                        launch{isMuted.drop(1).collect{FlutterBridge.instance.dispatchIfAlive("capabilityChanged",JSONObject().put("callId",callId).put("muted",it))}}
                    }
                } catch(e:Exception){callReady.completeExceptionally(e)}
                finally {if(id==callId){id=null;control=null;ready=null;MainActivity.releaseCallWindow();SmiTelecomCallService.end(ctx,callId)}}
            }
            replyReady(result)
        } catch(e:Exception){id=null;result?.error("NATIVE_CALL_UNAVAILABLE",e.javaClass.simpleName,null)}
    }
    private fun replyReady(result:MethodChannel.Result?) {if(result!=null)jobs.launch{try{withTimeout(8000){ready?.await()};actualSpeaker?.let{FlutterBridge.instance.dispatchIfAlive("capabilityChanged",JSONObject().put("callId",id).put("speakerOn",it))};result.success(null)}catch(e:Exception){result.error("NATIVE_CALL_UNAVAILABLE",e.javaClass.simpleName,null)}}}
    fun changeState(callId:String,state:String,result:MethodChannel.Result) {jobs.launch {
        try {
            if(callId==id) {
                if(state=="answering"){
                    ringSilenced=true
                    context?.let{SmiTelecomCallService.silence(it,callId)}
                    result.success(null);return@launch
                }
                val c=control?:throw IllegalStateException("Native call not ready")
                if(state=="answered"&&!active){check(c.answer(CallAttributesCompat.CALL_TYPE_AUDIO_CALL) is CallControlResult.Success);active=true}
                if(state=="connected"&&!active){check(c.setActive() is CallControlResult.Success);active=true}
                context?.let{SmiTelecomCallService.connected(it,callId)}
                selectRoute(desiredSpeaker)
            }
            result.success(null)
        }catch(e:Exception){result.error("NATIVE_STATE_FAILED",e.javaClass.simpleName,null)}
    }}
    fun speaker(enabled:Boolean,result:MethodChannel.Result){jobs.launch{try{desiredSpeaker=enabled;check(selectRoute(enabled));result.success(null)}catch(e:Exception){result.error("AUDIO_ROUTE_UNAVAILABLE",e.javaClass.simpleName,null)}}}
    private suspend fun selectRoute(speaker:Boolean):Boolean {
        val order=if(speaker)listOf(CallEndpointCompat.TYPE_SPEAKER) else listOf(CallEndpointCompat.TYPE_WIRED_HEADSET,CallEndpointCompat.TYPE_BLUETOOTH,CallEndpointCompat.TYPE_EARPIECE,CallEndpointCompat.TYPE_SPEAKER)
        val target=order.firstNotNullOfOrNull{type->endpoints.firstOrNull{it.type==type}}?:return false
        return control?.requestEndpointChange(target) is CallControlResult.Success
    }
    fun intent(ctx:Context,callId:String,type:String) {
        if(callId!=id)return
        ringSilenced=true
        SmiTelecomCallService.silence(ctx,callId)
        when(type){"answerRequested"->SmiCallStore.instance.enqueueAnswer(ctx,callId);"declineRequested"->SmiCallStore.instance.enqueueDecline(ctx,callId);else->SmiCallStore.instance.enqueueEnd(ctx,callId,"ended")}
        FlutterBridge.instance.dispatchIfAlive(type,JSONObject().put("callId",callId))
        SmiEngine.get(ctx)
    }
    fun end(ctx:Context,callId:String,rejected:Boolean) {
        if(callId!=id)return
        ringSilenced=true
        SmiTelecomCallService.silence(ctx,callId)
        val c=control;val job=callJob;id=null;control=null;active=false;MainActivity.releaseCallWindow()
        jobs.launch{try{c?.disconnect(DisconnectCause(if(rejected)DisconnectCause.REJECTED else DisconnectCause.LOCAL))}finally{job?.cancel();if(id==null)SmiTelecomCallService.end(ctx,callId)}}
    }
}
