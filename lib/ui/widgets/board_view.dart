/// Le plateau animé : dessin du plateau, lutins qui se déplacent et prise
/// de karaté quand un pion en avale un autre.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../game/board.dart';
import '../../game/rules.dart';
import '../board_geometry.dart';
import '../board_painter.dart';
import '../theme.dart';
import '../sketch/fight_choreo.dart';
import '../sketch/lutin_art.dart';
import 'capture_flash.dart';
import 'fight_layer.dart';
import 'pawn_view.dart';

class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.controller, required this.rotation});

  final GameController controller;

  /// Quarts de tour d'affichage (la base du joueur local en bas à gauche).
  final int rotation;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..repeat(reverse: true);

  /// Dernier sens de marche de chaque lutin (siège * 4 + pion).
  final Map<int, bool> _facingLeft = {};
  final Map<int, Offset> _lastFeet = {};

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          final cell = size / 15;
          return DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => _buildBoard(cell, size),
            ),
          );
        },
      ),
    );
  }

  /// Position des pieds d'un lutin, en cases affichées.
  Offset _feet(int seat, int pawn, int step, {Offset stack = Offset.zero}) {
    final logical = BoardGeometry.pawnPoint(seat, pawn, step);
    final d = BoardGeometry.rotatePoint(logical, widget.rotation) + stack;
    // Les pieds un peu sous le centre : le corps occupe la case. Dans la
    // base, un peu plus bas pour que le lutin reste dans la cour.
    final drop = step < 0 ? 0.55 : (step >= Board.homeStep ? 0.15 : 0.3);
    return d + Offset(0, drop);
  }

  Widget _buildBoard(double cell, double size) {
    final c = widget.controller;
    final state = c.state;
    final k = widget.rotation;
    final movable = c.movablePawns.toSet();
    final fight = c.fight;

    // Positions logiques de tous les pions, regroupés par case.
    final entries = <_PawnEntry>[];
    final byCell = <GridPos, List<_PawnEntry>>{};
    for (final seat in state.seats) {
      final exposed = Rules.exposedPawn(state, seat);
      for (var pawn = 0; pawn < Board.pawnsPerPlayer; pawn++) {
        final spot = c.displaySpot(seat, pawn);
        final e = _PawnEntry(
          seat: seat,
          pawn: pawn,
          spot: spot,
          movable: seat == state.current && movable.contains(pawn),
          hopping: c.hoppingKey == seat * 4 + pawn,
          hidden: fight?.involves(seat, pawn) ?? false,
          exposed: exposed == pawn && spot.seat == seat,
        );
        entries.add(e);
        final cellPos = Board.cellFor(spot.seat, spot.step);
        if (cellPos != null && !e.hidden) (byCell[cellPos] ??= []).add(e);
      }
    }

    for (final group in byCell.values) {
      final offsets = BoardGeometry.stackOffsets(group.length);
      for (var i = 0; i < group.length; i++) {
        group[i].stackOffset = offsets[i];
        group[i].stacked = group.length > 1;
      }
    }
    for (final e in entries) {
      e.feet = _feet(e.spot.seat, e.pawn, e.spot.step, stack: e.stackOffset);
      // Le lutin regarde dans le sens où il vient de se déplacer.
      final key = e.seat * 4 + e.pawn;
      final last = _lastFeet[key];
      if (last != null && e.hopping) {
        final dx = e.feet.dx - last.dx;
        if (dx.abs() > 0.05) _facingLeft[key] = dx < 0;
      }
      _lastFeet[key] = e.feet;
    }

    // Du fond vers l'avant : les lutins plus bas passent devant ; les pions
    // jouables et celui qui saute restent au premier plan.
    entries.sort((a, b) {
      final l = a.layer.compareTo(b.layer);
      return l != 0 ? l : a.feet.dy.compareTo(b.feet.dy);
    });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: BoardPainter(rotation: k, activeSeats: state.seats.toSet()),
            ),
          ),
        ),
        for (final e in entries) _positionedPawn(e, cell),
        if (fight != null)
          Positioned.fill(
            child: FightLayer(
              key: ValueKey('fight-${fight.id}'),
              scene: _scene(fight),
              cell: cell,
              lutinWidth: cell * _normalWidth,
              duration: GameTiming.fight,
            ),
          ),
        Positioned.fill(
          child: CaptureFlash(
            trigger: c.captureFlash,
            seat: c.captureSeat,
            duration: GameTiming.captureFlash,
          ),
        ),
      ],
    );
  }

  static const double _normalWidth = 1.05;

  FightScene _scene(FightInfo f) {
    Pt pt(Offset o) => Pt(o.dx, o.dy);
    return FightScene(
      attackerSeat: f.seat,
      victimSeats: [for (final v in f.victims) v.seat],
      start: pt(_feet(f.from.seat, f.pawn, f.from.step)),
      target: pt(_feet(f.to.seat, f.pawn, f.to.step)),
      victims: [
        for (final v in f.victims)
          VictimPath(pt(_feet(v.seat, v.pawn, v.from)), pt(_feet(v.seat, v.pawn, Board.inBase))),
      ],
    );
  }

  Widget _positionedPawn(_PawnEntry e, double cell) {
    final double width;
    if (e.spot.step >= Board.homeStep) {
      width = cell * 0.58;
    } else if (e.stacked) {
      width = cell * 0.8;
    } else {
      width = cell * _normalWidth;
    }
    final height = width * lutinBoxRatio;
    // Zone de toucher plus grande que le lutin pour les doigts.
    final boxW = e.movable ? math.max(width, 44.0) : width;
    final boxH = e.movable ? math.max(height, 52.0) : height;
    final style = seatStyles[e.seat];
    final facing = _facingLeft[e.seat * 4 + e.pawn] ?? false;

    Widget pawn;
    if (e.movable) {
      pawn = AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_pulse.value);
          return LutinView(
            seat: e.seat,
            width: width,
            pose: LutinPose.lerp(LutinPose.idle, LutinPose.hop, t * 0.35),
            glow: 0.3 + 0.7 * t,
            lift: 0.12 * t,
            facingLeft: facing,
          );
        },
      );
    } else if (e.exposed && !e.hopping) {
      // Le dernier lutin d'un joueur, attaquable dans sa maison, tremble.
      pawn = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.translate(
          offset: Offset(math.sin(_pulse.value * math.pi * 6) * width * 0.035, 0),
          child: child,
        ),
        child: LutinView(
          seat: e.seat,
          width: width,
          pose: LutinPose.lerp(LutinPose.idle, LutinPose.scared, 0.55),
          facingLeft: facing,
        ),
      );
    } else {
      pawn = LutinView(
        seat: e.seat,
        width: width,
        pose: e.hopping ? LutinPose.hop : LutinPose.idle,
        lift: e.hopping ? 0.12 : 0,
        facingLeft: facing,
      );
    }
    pawn = RepaintBoundary(child: Align(alignment: Alignment.bottomCenter, child: pawn));

    if (e.movable && !e.hidden) {
      pawn = Semantics(
        button: true,
        label: 'Lutin ${style.mask} ${e.pawn + 1}, jouable',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.controller.movePawn(e.pawn),
          child: pawn,
        ),
      );
    } else {
      pawn = IgnorePointer(child: pawn);
    }
    if (e.hidden) pawn = Opacity(opacity: 0, child: pawn);

    return AnimatedPositioned(
      key: ValueKey('pawn-${e.seat}-${e.pawn}'),
      duration: e.hopping
          ? const Duration(milliseconds: 130)
          : const Duration(milliseconds: 420),
      curve: e.hopping ? Curves.easeOut : Curves.easeInOutCubic,
      left: e.feet.dx * cell - boxW / 2,
      top: e.feet.dy * cell + width * lutinFeetMargin - boxH,
      width: boxW,
      height: boxH,
      child: pawn,
    );
  }
}

class _PawnEntry {
  _PawnEntry({
    required this.seat,
    required this.pawn,
    required this.spot,
    required this.movable,
    required this.hopping,
    required this.hidden,
    required this.exposed,
  });

  final int seat;
  final int pawn;

  /// Où il est affiché (parfois dans la maison d'un autre joueur).
  final Spot spot;

  /// Dernier lutin du joueur, attaquable dans sa maison.
  final bool exposed;
  final bool movable;
  final bool hopping;

  /// Le lutin joue la prise de karaté (dessiné par FightLayer).
  final bool hidden;
  Offset stackOffset = Offset.zero;
  bool stacked = false;
  Offset feet = Offset.zero;

  int get layer => hopping ? 2 : (movable ? 1 : 0);
}

/// Petite légende colorée réutilisable (pastille du joueur).
class SeatDot extends StatelessWidget {
  const SeatDot({super.key, required this.seat, this.size = 12});

  final int seat;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: seatStyles[seat].color,
          shape: BoxShape.circle,
          border: Border.all(color: DogonColors.nightDeep, width: 1.5),
        ),
      );
}
