/// État du téléphone pour le Bluetooth, rafraîchi à la demande (et au retour
/// des réglages Android).
library;

import 'package:flutter/foundation.dart';

import 'net_log.dart';
import 'permissions.dart';

class BluetoothReadiness extends ChangeNotifier {
  DeviceInfo? info;
  PermissionReport? permissions;
  bool loading = false;
  bool _disposed = false;

  int get sdk => info?.sdk ?? 0;

  /// Pas d'informations : on n'est pas sur Android (ou la lecture a échoué).
  bool get unknown => info == null;

  bool get playServicesOk => info == null || info!.playServices != null;
  bool get bluetoothOk => info == null || info!.bluetoothOn;
  bool get bluetoothAbsent => info?.bluetooth == 'absent';
  bool get locationOk => info == null || info!.location;
  bool get permissionsOk => permissions?.ready ?? true;

  /// La localisation est indispensable jusqu'à Android 12L.
  bool get locationRequired => sdk == 0 || sdk <= 32;

  bool get allGood => playServicesOk && bluetoothOk && locationOk && permissionsOk;

  Future<void> refresh() async {
    loading = true;
    _notify();
    info = await DeviceService.info();
    permissions = await NearbyPermissions.check(sdk);
    loading = false;
    _notify();
  }

  Future<PermissionReport> requestPermissions() async {
    final r = await NearbyPermissions.request(sdk);
    permissions = r;
    _notify();
    return r;
  }

  Future<bool> requestBluetooth() async {
    netLog('Demande d\'activation du Bluetooth.');
    final ok = await DeviceService.requestBluetooth();
    await refresh();
    netLog('Bluetooth ${bluetoothOk ? 'activé' : 'toujours désactivé'}.');
    return ok || bluetoothOk;
  }

  /// Résumé d'une ligne pour le journal.
  void logSummary() {
    final i = info;
    if (i == null) {
      netLog('Téléphone : informations indisponibles.');
      return;
    }
    netLog('Téléphone : ${i.phoneName}, Android ${i.release} (API ${i.sdk}), '
        'services Google Play ${i.playServices ?? 'ABSENTS'}, '
        'Bluetooth ${i.bluetooth}, localisation ${i.location ? 'activée' : 'DÉSACTIVÉE'}, '
        'Wi-Fi ${i.wifi ? 'activé' : 'désactivé'}.');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
