package com.bminformatix.ludo_dogon

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sounds: SoundPlayer? = null
    private var checks: DeviceChecks? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // État du téléphone pour le Bluetooth (version d'Android, réglages…).
        val device = DeviceChecks(this)
        checks = device
        MethodChannel(messenger, "ludo_dogon/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "info" -> result.success(device.info())
                    "requestBluetooth" -> device.requestBluetooth(result)
                    "openBluetoothSettings" -> {
                        device.openSettings(Settings.ACTION_BLUETOOTH_SETTINGS)
                        result.success(null)
                    }
                    "openLocationSettings" -> {
                        device.openSettings(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        device.openAppSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
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

    // Retour de la fenêtre d'activation du Bluetooth.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        checks?.onActivityResult(requestCode)
    }

    override fun onDestroy() {
        sounds?.release()
        sounds = null
        super.onDestroy()
    }
}
