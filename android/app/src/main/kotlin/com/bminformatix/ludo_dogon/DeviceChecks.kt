package com.bminformatix.ludo_dogon

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

/**
 * Vérifications du téléphone pour le jeu en Bluetooth : version d'Android,
 * services Google Play, Bluetooth, localisation, Wi-Fi, et ouverture des
 * réglages correspondants.
 */
class DeviceChecks(private val activity: Activity) {
    private val context: Context = activity.applicationContext
    private var pendingBluetooth: MethodChannel.Result? = null

    fun info(): Map<String, Any?> = mapOf(
        "sdk" to Build.VERSION.SDK_INT,
        "release" to Build.VERSION.RELEASE,
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "playServices" to playServicesVersion(),
        "bluetooth" to bluetoothState(),
        "location" to locationEnabled(),
        "wifi" to wifiEnabled(),
    )

    private fun playServicesVersion(): String? = try {
        val pm = context.packageManager
        val info = pm.getPackageInfo("com.google.android.gms", 0)
        info.versionName ?: "?"
    } catch (e: Exception) {
        null
    }

    /** "on", "off" ou "absent" (pas de Bluetooth sur ce téléphone). */
    fun bluetoothState(): String = try {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        when {
            adapter == null -> "absent"
            adapter.isEnabled -> "on"
            else -> "off"
        }
    } catch (e: SecurityException) {
        "unknown"
    }

    fun locationEnabled(): Boolean = try {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    } catch (e: Exception) {
        true
    }

    private fun wifiEnabled(): Boolean = try {
        val wm = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wm.isWifiEnabled
    } catch (e: Exception) {
        false
    }

    /** Demande à l'utilisateur d'activer le Bluetooth (fenêtre Android). */
    fun requestBluetooth(result: MethodChannel.Result) {
        if (bluetoothState() == "on") {
            result.success(true)
            return
        }
        try {
            pendingBluetooth?.success(false)
            pendingBluetooth = result
            activity.startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQUEST_BT)
        } catch (e: Exception) {
            pendingBluetooth = null
            openSettings(Settings.ACTION_BLUETOOTH_SETTINGS)
            result.success(false)
        }
    }

    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_BT) return false
        pendingBluetooth?.success(bluetoothState() == "on")
        pendingBluetooth = null
        return true
    }

    fun openSettings(action: String) {
        try {
            activity.startActivity(Intent(action))
        } catch (e: Exception) {
            openAppSettings()
        }
    }

    fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.fromParts("package", context.packageName, null)
            activity.startActivity(intent)
        } catch (e: Exception) {
            // Rien à faire.
        }
    }

    companion object {
        const val REQUEST_BT = 4242
    }
}
