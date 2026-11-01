package app.minivoipfree
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

object SmiEngine {
    private var engine: FlutterEngine? = null
    fun get(context: Context): FlutterEngine {
        engine?.let{return it}
        val fresh=FlutterEngine(context.applicationContext)
        engine=fresh
        SmiNativeChannels(context.applicationContext).attach(fresh)
        fresh.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return fresh
    }
}
