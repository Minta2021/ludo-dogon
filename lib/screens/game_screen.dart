/// Écran de jeu : joueurs, plateau, dé, messages, pause et classement.
library;

import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../game/board.dart';
import '../models/match.dart';
import '../ui/board_geometry.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/board_view.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/dice_view.dart';
import 'rules_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.subtitle,
    this.onClose,
  });

  /// La partie (l'écran s'occupe de la libérer en sortant).
  final GameController controller;
  final String subtitle;

  /// Appelé en quittant (fermeture de la session Bluetooth).
  final Future<void> Function()? onClose;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;
  bool _leaving = false;

  late final int _rotation = _computeRotation();

  int _computeRotation() {
    final config = c.config;
    final local = config.localSeat;
    if (local != null) return BoardGeometry.rotationFor(local);
    for (final p in config.players) {
      if (p.kind == PlayerKind.human) return BoardGeometry.rotationFor(p.seat);
    }
    return 0;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _leave({bool ask = true}) async {
    if (_leaving) return;
    if (ask && !c.state.isOver && c.connectionLost == null) {
      c.setPaused(true);
      final ok = await confirmDialog(
        context,
        title: 'Quitter la partie ?',
        message: c.config.mode == MatchMode.host
            ? 'La partie s\'arrêtera pour tous les joueurs connectés.'
            : 'La partie en cours sera perdue.',
        confirm: 'Quitter',
      );
      if (!ok) {
        c.setPaused(false);
        return;
      }
    }
    _leaving = true;
    await widget.onClose?.call();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openMenu() async {
    c.setPaused(true);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: DogonColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DogonColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pause', style: AppText.title, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Reprendre',
                icon: DogonIcon.check,
                onPressed: () => Navigator.of(context).pop('resume'),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Règles du jeu',
                icon: DogonIcon.book,
                onPressed: () => Navigator.of(context).pop('rules'),
              ),
              if (c.isAuthority) ...[
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Nouvelle partie',
                  icon: DogonIcon.refresh,
                  onPressed: () => Navigator.of(context).pop('restart'),
                ),
              ],
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Quitter la partie',
                icon: DogonIcon.close,
                onPressed: () => Navigator.of(context).pop('quit'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'rules':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RulesScreen()),
        );
        c.setPaused(false);
      case 'restart':
        final ok = c.state.isOver ||
            await confirmDialog(
              context,
              title: 'Nouvelle partie ?',
              message: 'La partie en cours sera abandonnée.',
              confirm: 'Recommencer',
            );
        c.setPaused(false);
        if (ok) c.restart();
      case 'quit':
        c.setPaused(false);
        await _leave();
      default:
        c.setPaused(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) => Stack(
              children: [
                Column(
                  children: [
                    ScreenHeader(
                      title: 'LUDO DOGON',
                      subtitle: widget.subtitle,
                      onBack: () => _leave(),
                      trailing: SquareIconButton(
                        icon: DogonIcon.menu,
                        label: 'Menu de la partie',
                        onPressed: _openMenu,
                      ),
                    ),
                    Expanded(child: _buildTable()),
                    const CliffFrieze(),
                  ],
                ),
                if (c.state.isOver) _ResultsOverlay(controller: c, onHome: () => _leave(ask: false)),
                if (c.connectionLost != null && !c.state.isOver)
                  _LostOverlay(message: c.connectionLost!, onHome: () => _leave(ask: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardH = 58.0;
        const gap = 10.0;
        const diceH = 112.0;
        final byWidth = constraints.maxWidth - 24;
        final byHeight = constraints.maxHeight - (cardH * 2 + diceH + gap * 4 + 12);
        final board = byWidth < byHeight ? byWidth : byHeight;
        final size = board < 220 ? 220.0 : board;

        Widget card(int corner) {
          final seat = BoardGeometry.seatAtCorner(corner, _rotation);
          return Expanded(child: _PlayerCard(controller: c, seat: seat));
        }

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: SizedBox(
                width: size,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    SizedBox(
                      height: cardH,
                      child: Row(children: [card(0), const SizedBox(width: gap), card(1)]),
                    ),
                    const SizedBox(height: gap),
                    SizedBox(
                      width: size,
                      height: size,
                      child: BoardView(controller: c, rotation: _rotation),
                    ),
                    const SizedBox(height: gap + 2),
                    SizedBox(
                      height: cardH,
                      child: Row(children: [card(3), const SizedBox(width: gap), card(2)]),
                    ),
                    const SizedBox(height: gap),
                    SizedBox(height: diceH, child: _DicePanel(controller: c)),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.controller, required this.seat});

  final GameController controller;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final player = controller.config.player(seat);
    if (player == null || !state.seats.contains(seat)) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DogonColors.outline),
        ),
        alignment: Alignment.center,
        child: Text('Place libre',
            style: AppText.small.copyWith(color: DogonColors.muted.withValues(alpha: 0.6))),
      );
    }

    final style = seatStyles[seat];
    final active = !state.isOver && state.current == seat;
    final rank = state.ranking.indexOf(seat);
    final local = controller.config.isLocalHuman(seat);
    final String status;
    if (rank >= 0) {
      status = rank == 0 ? '1er · gagnant' : '${rank + 1}e place';
    } else if (active) {
      status = local
          ? (controller.config.hasSeveralLocalHumans ? 'À son tour' : 'À toi de jouer')
          : (player.kind == PlayerKind.bot ? 'Réfléchit…' : 'Joue…');
    } else {
      switch (player.kind) {
        case PlayerKind.bot:
          status = 'Ordinateur';
        case PlayerKind.remote:
          status = 'Connecté';
        case PlayerKind.human:
          status = local && controller.config.mode != MatchMode.local ? 'Toi' : style.mask;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? DogonColors.surfaceHigh : DogonColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? style.color : DogonColors.outline,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          MaskBadge(seat: seat, size: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800, height: 1.2),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    color: active ? style.textColor : DogonColors.muted,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${state.arrivedCount(seat)}/${Board.pawnsPerPlayer}',
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: DogonColors.kaolin,
                ),
              ),
              const Text('arrivés', style: TextStyle(fontSize: 11, color: DogonColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DicePanel extends StatelessWidget {
  const _DicePanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final state = c.state;
    final accent = seatStyles[state.current].color;
    final readableAccent = seatStyles[state.current].textColor;
    final Color eventColor;
    switch (c.eventTone) {
      case MessageTone.good:
        eventColor = DogonColors.ochre;
      case MessageTone.bad:
        eventColor = DogonColors.danger;
      case MessageTone.neutral:
        eventColor = DogonColors.muted;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DogonColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DogonColors.outline),
      ),
      child: Row(
        children: [
          DiceView(
            value: c.diceFace,
            rolling: c.diceRolling,
            enabled: c.canRoll,
            accent: accent,
            onTap: c.roll,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.turnText,
                  maxLines: c.canRoll ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: readableAccent,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                if (c.canRoll)
                  SizedBox(
                    height: 34,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: DogonColors.ochre,
                        foregroundColor: DogonColors.night,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: c.roll,
                      child: const Text(
                        'Lancer le dé',
                        style: TextStyle(fontFamily: AppFonts.display, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Text(
                    c.eventText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.copyWith(color: eventColor, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsOverlay extends StatelessWidget {
  const _ResultsOverlay({required this.controller, required this.onHome});

  final GameController controller;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final ranking = controller.state.ranking;
    final winner = ranking.isNotEmpty ? ranking.first : null;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: InfoCard(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (winner != null) MaskBadge(seat: winner, size: 72, ring: true),
                  const SizedBox(height: 18),
                  Text(
                    winner == null ? 'Partie terminée' : '${controller.nameOf(winner)} gagne !',
                    textAlign: TextAlign.center,
                    style: AppText.display.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  const Text('Les 4 pions sont rentrés à la toguna.',
                      textAlign: TextAlign.center, style: AppText.small),
                  const SizedBox(height: 18),
                  for (var i = 0; i < ranking.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              i == 0 ? '1er' : '${i + 1}e',
                              style: TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 14,
                                color: i == 0 ? DogonColors.ochre : DogonColors.muted,
                              ),
                            ),
                          ),
                          MaskBadge(seat: ranking[i], size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.nameOf(ranking[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (controller.isAuthority) ...[
                    PrimaryButton(
                      label: 'Rejouer',
                      icon: DogonIcon.refresh,
                      onPressed: controller.restart,
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Text(
                        controller.connectionLost != null
                            ? 'L\'hôte a quitté la partie.'
                            : 'L\'hôte peut lancer une nouvelle partie.',
                        textAlign: TextAlign.center,
                        style: AppText.small),
                    const SizedBox(height: 12),
                  ],
                  SecondaryButton(label: 'Accueil', onPressed: onHome),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LostOverlay extends StatelessWidget {
  const _LostOverlay({required this.message, required this.onHome});

  final String message;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: InfoCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DogonIconView(DogonIcon.bluetooth,
                      size: 40, color: DogonColors.danger, strokeWidth: 2),
                  const SizedBox(height: 12),
                  const Text('Connexion perdue', style: AppText.title),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center, style: AppText.body),
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'Retour à l\'accueil', onPressed: onHome),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
