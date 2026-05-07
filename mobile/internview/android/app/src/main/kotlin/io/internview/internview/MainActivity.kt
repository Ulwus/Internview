package io.internview.internview

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "internview/media_projection_fgs"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "start" -> {
          val intent = Intent(this, MediaProjectionForegroundService::class.java)
          if (Build.VERSION.SDK_INT >= 26) {
            startForegroundService(intent)
          } else {
            startService(intent)
          }
          result.success(null)
        }
        "stop" -> {
          stopService(Intent(this, MediaProjectionForegroundService::class.java))
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }
}
