package com.example.exercise_app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "com.example.exercise_app/threshold_alert"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "startAlertService" -> {
            AlertForegroundService.start(applicationContext)
            result.success(null)
          }
          "stopAlertService" -> {
            AlertForegroundService.stop(applicationContext)
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }
}
