package app.minivoipfree

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.SecureRandom

/**
 * The single owner of the `smi.phone/native/v1` channels (spec 10.2/10.3).
 * A warm FlutterEngine is cached so incoming calls can reach Dart without a new
 * engine; events are also queued natively so a cold start replays them after
 * getPendingEvents + ack. No secrets cross this channel as broadcast.
 */
object FlutterBridge {
    const val METHOD_CHANNEL = "smi.phone/native/v1"
    const val EVENT_CHANNEL = "smi.phone/native/v1/events"

    val instance = FlutterBridgeImpl()
}

class FlutterBridgeImpl {
    private var methodSink: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var engine: FlutterEngine? = null

    fun attachEngine(context: Context, newEngine: FlutterEngine) {
        engine = newEngine
        FlutterEngineCache.getInstance().put(ENGINE_ID, newEngine)
        methodSink = MethodChannel(newEngine.dartExecutor.binaryMessenger, FlutterBridge.METHOD_CHANNEL)
        EventChannel(newEngine.dartExecutor.binaryMessenger, FlutterBridge.EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    fun dispatchIfAlive(type: String, payload: JSONObject) {
        val e = JSONObject()
            .put("eventId", "evt-${System.nanoTime()}")
            .put("type", type)
            .put("nativeTimestamp", System.currentTimeMillis())
            .put("payload", payload)
        methodSink?.invokeMethod("nativeEvent", e.toString())
    }

    companion object {
        const val ENGINE_ID = "smi_main_engine"
    }
}
