package com.ejerciciosapp.ejercicios_app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ejerciciosapp/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // true en Google TV / Android TV
                    "isTv" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK),
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
