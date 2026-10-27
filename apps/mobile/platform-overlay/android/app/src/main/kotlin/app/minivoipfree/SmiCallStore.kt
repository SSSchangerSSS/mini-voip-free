package app.minivoipfree

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Native event backlog + device bookkeeping (spec 10.1/10.3). Persisted in the
 * app-private noBackupFilesDir as JSON — call METADATA only; credentials, SIP
 * secrets and tokens never live here (secure values flow through the platform
 * secure store instead).
 */
class SmiCallStoreImpl {

    private val lock = Any()

    fun deviceGeneration(ctx: Context): Int =
        prefs(ctx).getInt(KEY_GENERATION, 1)

    fun setDeviceGeneration(ctx: Context, generation: Int) {
        prefs(ctx).edit().putInt(KEY_GENERATION, generation).apply()
    }

    fun pushTokenChanged(ctx: Context, token: String) {
        enqueue(ctx, eventId = "ptc-${UUID.randomUUID()}", type = "pushTokenChanged",
                payload = JSONObject().put("pushToken", token))
        FlutterBridge.instance.dispatchIfAlive("pushTokenChanged", payloadOf(ctx, token))
    }

    fun enqueueIncoming(ctx: Context, callId: String, caller: String, expiresAtEpoch: Long) {
        enqueue(ctx, eventId = "inc-$callId", type = "incomingReported",
                payload = JSONObject()
                    .put("callId", callId)
                    .put("callerExtension", caller)
                    .put("expiresAtEpoch", expiresAtEpoch))
    }

    fun enqueueAnswer(ctx: Context, callId: String) {
        enqueue(ctx, eventId = "ans-$callId", type = "answerRequested",
                payload = JSONObject().put("callId", callId))
    }

    fun enqueueEnd(ctx: Context, callId: String, reason: String) {
        enqueue(ctx, eventId = "end-$callId-$reason", type = "endRequested",
                payload = JSONObject().put("callId", callId).put("reason", reason))
    }

    private fun enqueue(ctx: Context, eventId: String, type: String, payload: JSONObject) {
        synchronized(lock) {
            val arr = readAll(ctx)
            // dedupe by eventId
            for (i in 0 until arr.length()) {
                if (arr.getJSONObject(i).optString("eventId") == eventId) return
            }
            val entry = JSONObject()
                .put("eventId", eventId)
                .put("type", type)
                .put("nativeTimestamp", System.currentTimeMillis())
                .put("payload", payload)
            arr.put(entry)
            while (arr.length() > 64) arr.remove(0) // bounded, spec 10.1
            file(ctx).writeText(arr.toString())
        }
    }

    /** Returns pending events and removes them from storage ONLY on ack (spec 10.3). */
    fun pendingEvents(ctx: Context): JSONArray = synchronized(lock) { readAll(ctx) }

    fun ack(ctx: Context, eventId: String) {
        synchronized(lock) {
            val arr = readAll(ctx)
            val out = JSONArray()
            for (i in 0 until arr.length()) {
                if (arr.getJSONObject(i).optString("eventId") != eventId) out.put(arr.getJSONObject(i))
            }
            file(ctx).writeText(out.toString())
        }
    }

    private fun readAll(ctx: Context): JSONArray = synchronized(lock) {
        val f = file(ctx)
        if (!f.exists()) return JSONArray()
        runCatching { JSONArray(f.readText()) }.getOrDefault(JSONArray())
    }

    private fun file(ctx: Context): File =
        File(ctx.noBackupFilesDir, "smi_native_events.json")

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences("smi_device", Context.MODE_PRIVATE)

    private fun payloadOf(ctx: Context, token: String): JSONObject =
        JSONObject().put("pushToken", token)

    companion object {
        private const val KEY_GENERATION = "deviceGeneration"
    }
}

/**
 * Access point for the native event backlog (spec 10.3). Lives in its own
 * Firebase-free file so the app builds in `--android-no-push` mode too, where
 * SmiFirebaseMessagingService.kt is intentionally excluded (PREFLIGHT B3).
 */
object SmiCallStore {
    val instance = SmiCallStoreImpl()
}
