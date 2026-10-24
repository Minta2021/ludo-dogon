package com.bminformatix.ludo_dogon

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sounds: SoundPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Donne la version d'Android au jeu (les autorisations Bluetooth en dépendent).
        MethodChannel(messenger, "ludo_dogon/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "sdkInt") {
                    result.success(Build.VERSION.SDK_INT)
                } else {
                    result.notImplemented()
                }
            }

        // Sons du jeu.
        val player = SoundPlayer(applicationContext)
        sounds?.release()
        sounds = player
        MethodChannel(messenger, "ludo_dogon/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        player.play(call.argument<String>("name") ?: "")
                        result.success(null)
                    }
                    "isEnabled" -> result.success(player.enabled)
                    "setEnabled" -> {
                        player.enabled = call.argument<Boolean>("enabled") ?: true
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        super.onDestroy()
    }
}
