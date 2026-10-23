/// Autorisations Android nécessaires au Bluetooth (Nearby Connections).
///
/// Elles dépendent de la version d'Android :
/// * Android 13 et plus : « Appareils à proximité » (Bluetooth + Wi-Fi) ;
/// * Android 12L : Bluetooth ;
/// * Android 12 : Bluetooth + localisation ;
/// * Android 11 et moins : localisation.
///
/// Elles correspondent aux déclarations de AndroidManifest.xml.
library;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NearbyReadiness {
  const NearbyReadiness({
    required this.granted,
    required this.permanentlyDenied,
    required this.locationServiceOn,
    required this.needsLocation,
  });

  /// Toutes les autorisations nécessaires sont accordées.
  final bool granted;

  /// L'utilisateur a refusé définitivement : il faut passer par les réglages.
  final bool permanentlyDenied;

  /// La localisation (GPS) est activée sur le téléphone.
  final bool locationServiceOn;

  /// Cette version d'Android a besoin de la localisation pour le Bluetooth.
  final bool needsLocation;
}

abstract final class NearbyPermissions {
  static const _channel = MethodChannel('ludo_dogon/device');

  /// Version de l'API Android (null si inconnue).
  static Future<int?> androidSdk() async {
    try {
      return await _channel.invokeMethod<int>('sdkInt');
    } on Object {
      return null;
    }
  }

  /// Demande les autorisations utiles et indique si l'on peut continuer.
  static Future<NearbyReadiness> request() async {
    final sdk = await androidSdk();
    const bluetooth = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];
    final List<Permission> needed;
    if (sdk == null) {
      needed = [Permission.location, ...bluetooth];
    } else if (sdk >= 33) {
      needed = [...bluetooth, Permission.nearbyWifiDevices];
    } else if (sdk == 32) {
      needed = bluetooth;
    } else if (sdk == 31) {
      needed = [...bluetooth, Permission.location];
    } else {
      needed = [Permission.location];
    }

    final statuses = await needed.request();
    final notGranted = [
      for (final e in statuses.entries)
        if (!e.value.isGranted && !e.value.isLimited) e.value,
    ];
    final needsLocation = sdk == null || sdk <= 31;
    var locationOn = true;
    try {
      locationOn = await Permission.location.serviceStatus.isEnabled;
    } on Object {
      locationOn = true;
    }
    return NearbyReadiness(
      // Si la version est inconnue, on tente quand même la connexion.
      granted: notGranted.isEmpty || sdk == null,
      permanentlyDenied: notGranted.any((s) => s.isPermanentlyDenied),
      locationServiceOn: locationOn,
      needsLocation: needsLocation,
    );
  }

  static Future<bool> openSettings() => openAppSettings();
}
