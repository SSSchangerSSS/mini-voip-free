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
        // Dart listens on EventChannel, not a nativeEvent MethodChannel call.
        // StandardMessageCodec supports maps; JSONObject is not codec-safe.
        val event = mutableMapOf<String, Any?>(
            "eventId" to "evt-${System.nanoTime()}",
            "type" to type,
            "nativeTimestamp" to java.time.Instant.now().toString(),
        )
        payload.keys().forEach { key ->
            val value = payload.opt(key)
            event[key] = if (value == JSONObject.NULL) null else value
        }
        // EventChannel platform messages must be delivered on the main thread.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(event)
        }
    }

    companion object {
        const val ENGINE_ID = "smi_main_engine"
    }
}
