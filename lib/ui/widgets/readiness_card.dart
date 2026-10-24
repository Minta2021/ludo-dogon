/// Carte « Avant de jouer » : Bluetooth, localisation, autorisations, avec
/// un bouton pour régler chaque point. Et la vérification complète avant de
/// créer ou rejoindre une partie.
library;

import 'package:flutter/material.dart';

import '../../net/net_log.dart';
import '../../net/permissions.dart';
import '../../net/readiness.dart';
import '../dogon_icons.dart';
import '../theme.dart';
import 'common.dart';

class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key, required this.readiness});

  final BluetoothReadiness readiness;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: readiness,
      builder: (context, _) {
        final r = readiness;
        if (r.unknown && !r.loading) {
          return const InfoCard(
            child: Text('Vérification du téléphone indisponible.', style: AppText.small),
          );
        }
        final missing = r.permissions?.missingRequired ?? const [];
        return InfoCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('AVANT DE JOUER', style: AppText.label)),
                  if (r.loading)
                    const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 6),
              if (!r.playServicesOk)
                const _Row(
                  ok: false,
                  title: 'Services Google Play',
                  detail: 'Absents : le jeu en Bluetooth ne peut pas fonctionner.',
                ),
              _Row(
                ok: r.bluetoothOk,
                title: 'Bluetooth',
                detail: r.bluetoothAbsent
                    ? 'Ce téléphone n\'a pas de Bluetooth.'
                    : (r.bluetoothOk ? 'Activé' : 'Désactivé'),
                action: r.bluetoothOk || r.bluetoothAbsent ? null : 'Activer',
                onAction: r.requestBluetooth,
              ),
              _Row(
                ok: r.locationOk,
                warn: !r.locationOk && !r.locationRequired,
                title: 'Localisation (GPS)',
                detail: r.locationOk
                    ? 'Activée'
                    : (r.locationRequired ? 'Désactivée : obligatoire sur ce téléphone' : 'Désactivée : conseillée'),
                action: r.locationOk ? null : 'Activer',
                onAction: DeviceService.openLocationSettings,
              ),
              _Row(
                ok: missing.isEmpty,
                title: 'Autorisations',
                detail: missing.isEmpty
                    ? 'Accordées'
                    : 'Manquantes : ${missing.map((p) => p.label).join(', ')}',
                action: missing.isEmpty ? null : 'Autoriser',
                onAction: () async {
                  final rep = await r.requestPermissions();
                  if (rep.permanentlyDenied) await DeviceService.openAppSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.ok,
    required this.title,
    required this.detail,
    this.warn = false,
    this.action,
    this.onAction,
  });

  final bool ok;
  final bool warn;
  final String title;
  final String detail;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = ok ? DogonColors.millet : (warn ? DogonColors.ochre : DogonColors.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: DogonIconView(ok ? DogonIcon.check : DogonIcon.close,
                  size: 14, color: DogonColors.night, strokeWidth: 3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(detail, style: AppText.small),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: DogonColors.night,
                backgroundColor: DogonColors.ochre,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

/// Vérifie tout avant de créer ou rejoindre une partie, en proposant de
/// régler chaque problème. Renvoie vrai si l'on peut continuer.
Future<bool> ensureBluetoothReady(BuildContext context, BluetoothReadiness r) async {
  await r.refresh();
  r.logSummary();
  if (!context.mounted) return false;
  if (r.unknown) return true;

  Future<void> info(String title, String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: DogonColors.ochre)),
            ),
          ],
        ),
      );

  if (!r.playServicesOk) {
    await info('Services Google Play absents',
        'Le jeu en Bluetooth utilise les services Google Play, qui manquent sur ce téléphone. '
        'Tu peux jouer contre l\'ordinateur ou sur le même téléphone.');
    return false;
  }
  if (r.bluetoothAbsent) {
    await info('Pas de Bluetooth', 'Ce téléphone n\'a pas de Bluetooth.');
    return false;
  }

  // 1. Autorisations.
  var report = r.permissions!;
  if (!report.ready) {
    report = await r.requestPermissions();
    if (!context.mounted) return false;
  }
  if (!report.ready) {
    final missing = report.missingRequired.map((p) => '• ${p.label}').join('\n');
    final open = await confirmDialog(
      context,
      title: 'Autorisations nécessaires',
      message: 'Pour trouver les téléphones proches, Android doit autoriser Ludo Dogon :\n'
          '$missing\n\nLe jeu n\'enregistre pas ta position.',
      confirm: report.permanentlyDenied ? 'Ouvrir les réglages' : 'Réessayer',
    );
    if (open && context.mounted) {
      if (report.permanentlyDenied) {
        await DeviceService.openAppSettings();
      } else {
        return ensureBluetoothReady(context, r);
      }
    }
    return false;
  }

  // 2. Bluetooth activé.
  if (!r.bluetoothOk) {
    await r.requestBluetooth();
    if (!context.mounted) return false;
    if (!r.bluetoothOk) {
      final open = await confirmDialog(
        context,
        title: 'Active le Bluetooth',
        message: 'Le Bluetooth doit être activé sur chaque téléphone.',
        confirm: 'Ouvrir les réglages',
      );
      if (open) await DeviceService.openBluetoothSettings();
      return false;
    }
  }

  // 3. Localisation activée.
  if (!r.locationOk && context.mounted) {
    final required = r.locationRequired;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active la localisation'),
        content: Text(required
            ? 'Sur ce téléphone, Android exige la localisation (GPS) pour trouver les '
                'appareils proches. Active-la, puis reviens.'
            : 'Active la localisation (GPS) : sur beaucoup de téléphones, les autres '
                'appareils ne sont trouvés qu\'avec elle.'),
        actions: [
          if (!required)
            TextButton(
              onPressed: () => Navigator.of(context).pop('skip'),
              child: const Text('Continuer sans', style: TextStyle(color: DogonColors.muted)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('open'),
            child: const Text('Ouvrir les réglages',
                style: TextStyle(color: DogonColors.ochre, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (choice == 'open') {
      await DeviceService.openLocationSettings();
      return false;
    }
    if (choice != 'skip') return false;
    netLog('Localisation désactivée : on continue quand même.');
  }
  return true;
}
