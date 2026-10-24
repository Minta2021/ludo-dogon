/// Jeu en Bluetooth : créer une partie ou en rejoindre une.
library;

import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../net/readiness.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/readiness_card.dart';
import 'diagnostic_screen.dart';
import 'host_lobby_screen.dart';
import 'join_screen.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> with WidgetsBindingObserver {
  final _readiness = BluetoothReadiness();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readiness.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readiness.dispose();
    super.dispose();
  }

  /// Au retour des réglages Android, on relit l'état du téléphone.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readiness.refresh();
  }

  Future<bool> _prepare() async {
    setState(() => _checking = true);
    try {
      return await ensureBluetoothReady(context, _readiness);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Les autres joueurs verront ce nom : on le demande s'il n'est pas choisi.
  Future<bool> _ensureName() async {
    final profile = PlayerProfile.instance;
    if (profile.name != 'Joueur') return true;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null) return false;
    profile.name = name.trim().isEmpty ? seatStyles[profile.seat].mask : name;
    return true;
  }

  Future<void> _go(Widget screen) async {
    if (_checking) return;
    if (!await _ensureName() || !mounted) return;
    final ok = await _prepare();
    if (!ok || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    _readiness.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Jouer en Bluetooth',
              subtitle: 'Sans internet, de 2 à 4 téléphones',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  const InfoCard(
                    child: Row(
                      children: [
                        _Beacon(),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Comment ça marche', style: AppText.title),
                              SizedBox(height: 6),
                              Text(
                                'Un joueur crée la partie. Les autres choisissent '
                                '« Rejoindre » et la trouvent dans la liste.',
                                style: AppText.small,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ReadinessCard(readiness: _readiness),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Créer une partie',
                    icon: DogonIcon.toguna,
                    height: 60,
                    onPressed: _checking ? null : () => _go(const HostLobbyScreen()),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'Rejoindre une partie',
                    icon: DogonIcon.bluetooth,
                    height: 56,
                    onPressed: _checking ? null : () => _go(const JoinScreen()),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const DiagnosticScreen()),
                    ),
                    icon: const DogonIconView(DogonIcon.refresh,
                        size: 18, color: DogonColors.ochre, strokeWidth: 2),
                    label: const Text('Diagnostic Bluetooth : tester deux téléphones',
                        style: TextStyle(color: DogonColors.ochre, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  if (_checking)
                    const Center(child: CircularProgressIndicator())
                  else
                    const _Tips(),
                ],
              ),
            ),
            const CliffFrieze(),
          ],
        ),
      ),
    );
  }
}

class _Beacon extends StatelessWidget {
  const _Beacon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DogonColors.wood, width: 2),
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8A6A3A), width: 2),
          ),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: DogonColors.ochre, shape: BoxShape.circle),
              child: const Center(
                child: DogonIconView(DogonIcon.bluetooth,
                    size: 22, color: DogonColors.night, strokeWidth: 2.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    const tips = [
      'Sur chaque téléphone : Bluetooth et localisation (GPS) activés.',
      'Restez à quelques mètres les uns des autres, sans mode avion.',
      'Les nouveaux joueurs entrent automatiquement dans la partie de l\'hôte.',
      'Tous les joueurs doivent avoir la même version de Ludo Dogon.',
    ];
    return Column(
      children: [
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: DogonIconView(DogonIcon.check,
                      size: 18, color: DogonColors.ochre, strokeWidth: 2.4),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: AppText.small.copyWith(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Boîte de dialogue qui possède son propre champ de texte (libéré quand
/// elle disparaît, après l'animation de fermeture).
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ton nom'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 16,
        textCapitalization: TextCapitalization.words,
        style: AppText.body,
        decoration: const InputDecoration(hintText: 'Les autres joueurs le verront'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: DogonColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Valider',
              style: TextStyle(color: DogonColors.ochre, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
