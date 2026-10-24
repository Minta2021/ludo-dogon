/// Ce qu'il faut sur le téléphone pour jouer en Bluetooth : autorisations,
/// Bluetooth activé, localisation activée, services Google Play.
///
/// Selon la version d'Android, Nearby Connections demande :
/// * Android 12 et plus : Bluetooth (recherche, visibilité, connexion) ;
/// * Android 13 et plus : en plus, « Appareils Wi-Fi à proximité » ;
/// * jusqu'à Android 12L : la localisation (obligatoire).
/// La localisation est aussi demandée sur les versions récentes : beaucoup
/// de téléphones ne trouvent les autres appareils qu'avec elle.
library;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'net_log.dart';

/// État du téléphone, lu par MainActivity (DeviceChecks.kt).
class DeviceInfo {
  const DeviceInfo({
    required this.sdk,
    required this.release,
    required this.manufacturer,
    required this.model,
    required this.playServices,
    required this.bluetooth,
    required this.location,
    required this.wifi,
  });

  factory DeviceInfo.fromMap(Map<Object?, Object?> m) => DeviceInfo(
        sdk: (m['sdk'] as num?)?.toInt() ?? 0,
        release: m['release'] as String? ?? '?',
        manufacturer: m['manufacturer'] as String? ?? '',
        model: m['model'] as String? ?? '',
        playServices: m['playServices'] as String?,
        bluetooth: m['bluetooth'] as String? ?? 'unknown',
        location: m['location'] as bool? ?? true,
        wifi: m['wifi'] as bool? ?? false,
      );

  final int sdk;
  final String release;
  final String manufacturer;
  final String model;

  /// Version des services Google Play, ou null s'ils sont absents.
  final String? playServices;

  /// "on", "off", "absent" ou "unknown".
  final String bluetooth;
  final bool location;
  final bool wifi;

  bool get bluetoothOn => bluetooth == 'on' || bluetooth == 'unknown';

  String get phoneName {
    final brand = manufacturer.isEmpty
        ? ''
        : manufacturer[0].toUpperCase() + manufacturer.substring(1);
    return model.toLowerCase().startsWith(manufacturer.toLowerCase()) ? model : '$brand $model';
  }
}

abstract final class DeviceService {
  static const _channel = MethodChannel('ludo_dogon/device');

  static Future<DeviceInfo?> info() async {
    try {
      final m = await _channel.invokeMethod<Map<Object?, Object?>>('info');
      return m == null ? null : DeviceInfo.fromMap(m);
    } on Object {
      return null;
    }
  }

  /// Affiche la fenêtre Android « Activer le Bluetooth ? ».
  static Future<bool> requestBluetooth() async {
    try {
      return await _channel.invokeMethod<bool>('requestBluetooth') ?? false;
    } on Object {
      return false;
    }
  }

  static Future<void> openBluetoothSettings() => _call('openBluetoothSettings');
  static Future<void> openLocationSettings() => _call('openLocationSettings');
  static Future<void> openAppSettings() => _call('openAppSettings');

  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on Object {
      // Réglage indisponible.
    }
  }
}

/// Une autorisation utile au Bluetooth, avec son nom en français.
class NeededPermission {
  const NeededPermission(this.permission, this.label, {required this.required});

  final Permission permission;
  final String label;

  /// Sans elle, Nearby Connections refuse de démarrer.
  final bool required;
}

class PermissionReport {
  const PermissionReport(this.items);

  final List<(NeededPermission, PermissionStatus)> items;

  bool _ok(PermissionStatus s) => s.isGranted || s.isLimited;

  /// Autorisations indispensables qui manquent.
  List<NeededPermission> get missingRequired =>
      [for (final (p, s) in items) if (p.required && !_ok(s)) p];

  /// Autorisations conseillées qui manquent.
  List<NeededPermission> get missingOptional =>
      [for (final (p, s) in items) if (!p.required && !_ok(s)) p];

  bool get ready => missingRequired.isEmpty;

  bool get permanentlyDenied => [
        for (final (p, s) in items)
          if (p.required && s.isPermanentlyDenied) p
      ].isNotEmpty;
}

abstract final class NearbyPermissions {
  static List<NeededPermission> forSdk(int sdk) {
    final unknown = sdk == 0;
    return [
      NeededPermission(Permission.location, 'Localisation', required: unknown || sdk <= 32),
      if (unknown || sdk >= 31) ...[
        const NeededPermission(Permission.bluetoothScan, 'Bluetooth : recherche', required: true),
        const NeededPermission(Permission.bluetoothAdvertise, 'Bluetooth : visibilité', required: true),
        const NeededPermission(Permission.bluetoothConnect, 'Bluetooth : connexion', required: true),
      ],
      if (unknown || sdk >= 33)
        const NeededPermission(Permission.nearbyWifiDevices, 'Appareils Wi-Fi à proximité', required: true),
    ];
  }

  /// État des autorisations, sans rien demander.
  static Future<PermissionReport> check(int sdk) async {
    final items = <(NeededPermission, PermissionStatus)>[];
    for (final p in forSdk(sdk)) {
      PermissionStatus s;
      try {
        s = await p.permission.status;
      } on Object {
        s = PermissionStatus.granted;
      }
      items.add((p, s));
    }
    return PermissionReport(items);
  }

  /// Demande les autorisations (fenêtres Android) et renvoie le résultat.
  static Future<PermissionReport> request(int sdk) async {
    final needed = forSdk(sdk);
    Map<Permission, PermissionStatus> statuses;
    try {
      statuses = await [for (final p in needed) p.permission].request();
    } on Object catch (e) {
      netLog('Demande d\'autorisations impossible : $e');
      statuses = {};
    }
    final report = PermissionReport([
      for (final p in needed) (p, statuses[p.permission] ?? PermissionStatus.granted),
    ]);
    netLog('Autorisations : ${[
      for (final (p, s) in report.items) '${p.label} = ${_fr(s)}'
    ].join(', ')}.');
    return report;
  }

  static String _fr(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return 'oui';
    if (s.isPermanentlyDenied) return 'refusée définitivement';
    return 'non';
  }
}
