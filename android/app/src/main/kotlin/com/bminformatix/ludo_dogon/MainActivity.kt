package com.bminformatix.ludo_dogon

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Donne la version d'Android au jeu (les autorisations Bluetooth en dépendent).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ludo_dogon/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "sdkInt") {
                    result.success(Build.VERSION.SDK_INT)
                } else {
                    result.notImplemented()
                }
            }
    }
}
