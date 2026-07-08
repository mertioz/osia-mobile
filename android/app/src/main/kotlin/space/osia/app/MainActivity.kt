package space.osia.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "space.osia.app/background_connection"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(
                    BackgroundConnectionForegroundService.start(this)
                )
                "stop" -> {
                    BackgroundConnectionForegroundService.stop(this)
                    result.success(null)
                }
                "isRunning" -> result.success(
                    BackgroundConnectionForegroundService.isRunning
                )
                else -> result.notImplemented()
            }
        }
    }
}
