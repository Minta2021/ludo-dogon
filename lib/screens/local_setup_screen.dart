/// Préparation d'une partie sur ce téléphone (contre l'ordinateur ou à
/// plusieurs en se passant le téléphone).
library;

import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../game/ai.dart';
import '../models/match.dart';
import '../models/profile.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'game_screen.dart';

class LocalSetupScreen extends StatefulWidget {
  const LocalSetupScreen({super.key, required this.versusComputer});

  final bool versusComputer;

  @override
  State<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends State<LocalSetupScreen> {
  final profile = PlayerProfile.instance;
  int _count = 2;
  BotLevel _level = BotLevel.normal;
  late final List<PlayerKind> _kinds;
  late final List<TextEditingController> _names;

  @override
  void initState() {
    super.initState();
    final me = profile.seat;
    _kinds = [
      for (var s = 0; s < 4; s++)
        s == me || !widget.versusComputer ? PlayerKind.human : PlayerKind.bot,
    ];
    var n = 2;
    _names = [
      for (var s = 0; s < 4; s++)
        TextEditingController(text: s == me ? profile.name : 'Joueur ${n++}'),
    ];
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  /// Sièges utilisés selon le nombre de joueurs (toujours le sien inclus).
  List<int> get _seats {
    final me = profile.seat;
    switch (_count) {
      case 2:
        return [me, (me + 2) % 4];
      case 3:
        return [me, (me + 1) % 4, (me + 2) % 4];
      default:
        return [0, 1, 2, 3];
    }
  }

  bool get _hasHuman => _seats.any((s) => _kinds[s] == PlayerKind.human);

  bool get _hasBot => _seats.any((s) => _kinds[s] == PlayerKind.bot);

  void _start() {
    final players = <PlayerSlot>[];
    for (final s in _seats) {
      final human = _kinds[s] == PlayerKind.human;
      final typed = _names[s].text.trim();
      players.add(PlayerSlot(
        seat: s,
        name: human ? (typed.isEmpty ? seatStyles[s].mask : typed) : botNames[s],
        kind: human ? PlayerKind.human : PlayerKind.bot,
        botLevel: _level,
      ));
    }
    final me = _names[profile.seat].text.trim();
    if (_kinds[profile.seat] == PlayerKind.human && me.isNotEmpty) profile.name = me;
    final config = MatchConfig(players: players, mode: MatchMode.local);
    final controller = GameController(config: config);
    final subtitle = _hasBot
        ? (_hasHumanCount > 1 ? 'Avec l\'ordinateur' : 'Contre l\'ordinateur')
        : 'Sur le même téléphone';
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GameScreen(controller: controller, subtitle: '$subtitle · $_count joueurs'),
    ));
  }

  int get _hasHumanCount => _seats.where((s) => _kinds[s] == PlayerKind.human).length;

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: widget.versusComputer ? 'Contre l\'ordinateur' : 'Sur le même téléphone',
              subtitle: 'Prépare la partie',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  const Text('NOMBRE DE JOUEURS', style: AppText.label),
                  const SizedBox(height: 10),
                  _Segmented<int>(
                    values: const [2, 3, 4],
                    labels: const ['2', '3', '4'],
                    selected: _count,
                    onChanged: (v) => setState(() => _count = v),
                  ),
                  const SizedBox(height: 22),
                  const Text('JOUEURS', style: AppText.label),
                  const SizedBox(height: 10),
                  for (final s in seats) ...[
                    _SeatRow(
                      seat: s,
                      isMe: s == profile.seat,
                      kind: _kinds[s],
                      nameController: _names[s],
                      botName: botNames[s],
                      onKind: (k) => setState(() => _kinds[s] = k),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_hasBot) ...[
                    const SizedBox(height: 12),
                    const Text('NIVEAU DE L\'ORDINATEUR', style: AppText.label),
                    const SizedBox(height: 10),
                    _Segmented<BotLevel>(
                      values: const [BotLevel.easy, BotLevel.normal],
                      labels: const ['Facile', 'Normal'],
                      selected: _level,
                      onChanged: (v) => setState(() => _level = v),
                    ),
                  ],
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Commencer la partie',
                    icon: DogonIcon.check,
                    onPressed: _hasHuman ? _start : null,
                  ),
                  if (!_hasHuman) ...[
                    const SizedBox(height: 10),
                    const Text('Il faut au moins un joueur humain.',
                        textAlign: TextAlign.center, style: AppText.small),
                  ],
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

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.seat,
    required this.isMe,
    required this.kind,
    required this.nameController,
    required this.botName,
    required this.onKind,
  });

  final int seat;
  final bool isMe;
  final PlayerKind kind;
  final TextEditingController nameController;
  final String botName;
  final ValueChanged<PlayerKind> onKind;

  @override
  Widget build(BuildContext context) {
    final human = kind == PlayerKind.human;
    return InfoCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          MaskBadge(seat: seat, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: human
                ? TextField(
                    controller: nameController,
                    maxLength: 16,
                    textCapitalization: TextCapitalization.words,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: seatStyles[seat].mask,
                      fillColor: DogonColors.surfaceHigh,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(botName,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                      const Text('Ordinateur', style: AppText.small),
                    ],
                  ),
          ),
          const SizedBox(width: 10),
          _KindToggle(kind: kind, onChanged: onKind, lockedHuman: isMe),
        ],
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged, required this.lockedHuman});

  final PlayerKind kind;
  final ValueChanged<PlayerKind> onChanged;

  /// Le joueur du téléphone reste humain.
  final bool lockedHuman;

  @override
  Widget build(BuildContext context) {
    Widget option(PlayerKind k, DogonIcon icon, String label) {
      final on = kind == k;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: lockedHuman ? null : () => onChanged(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 40,
            decoration: BoxDecoration(
              color: on ? DogonColors.ochre : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: DogonIconView(icon,
                  size: 20,
                  color: on ? DogonColors.night : DogonColors.muted,
                  strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: lockedHuman ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: DogonColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(PlayerKind.human, DogonIcon.people, 'Joueur humain'),
            option(PlayerKind.bot, DogonIcon.robot, 'Ordinateur'),
          ],
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DogonColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DogonColors.outline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: values[i] == selected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(values[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: values[i] == selected ? DogonColors.ochre : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: values[i] == selected ? DogonColors.night : DogonColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
