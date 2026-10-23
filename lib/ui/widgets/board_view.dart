/// Le plateau animé : dessin du plateau + pions qui se déplacent.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../game/board.dart';
import '../board_geometry.dart';
import '../board_painter.dart';
import '../theme.dart';
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
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

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

  Widget _buildBoard(double cell, double size) {
    final c = widget.controller;
    final state = c.state;
    final k = widget.rotation;
    final movable = c.movablePawns.toSet();

    // Positions logiques de tous les pions, regroupés par case.
    final entries = <_PawnEntry>[];
    final byCell = <GridPos, List<_PawnEntry>>{};
    for (final seat in state.seats) {
      for (var pawn = 0; pawn < Board.pawnsPerPlayer; pawn++) {
        final step = c.displayStep(seat, pawn);
        final e = _PawnEntry(
          seat: seat,
          pawn: pawn,
          step: step,
          movable: seat == state.current && movable.contains(pawn),
          hopping: c.hoppingKey == seat * 4 + pawn,
        );
        entries.add(e);
        final cellPos = Board.cellFor(seat, step);
        if (cellPos != null) (byCell[cellPos] ??= []).add(e);
      }
    }

    for (final group in byCell.values) {
      final offsets = BoardGeometry.stackOffsets(group.length);
      for (var i = 0; i < group.length; i++) {
        group[i].stackOffset = offsets[i];
        group[i].stacked = group.length > 1;
      }
    }

    // Les pions jouables et celui qui saute passent au premier plan.
    entries.sort((a, b) => a.layer.compareTo(b.layer));

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
      ],
    );
  }

  Widget _positionedPawn(_PawnEntry e, double cell) {
    final logical = BoardGeometry.pawnPoint(e.seat, e.pawn, e.step);
    final display = BoardGeometry.rotatePoint(logical, widget.rotation) + e.stackOffset;
    final double pawnSize;
    if (e.step >= Board.homeStep) {
      pawnSize = cell * 0.62;
    } else if (e.stacked) {
      pawnSize = cell * 0.78;
    } else {
      pawnSize = cell * 1.05;
    }
    // Zone de toucher plus grande que le pion pour les doigts.
    final hit = e.movable ? math.max(pawnSize, 44.0) : pawnSize;
    final style = seatStyles[e.seat];

    Widget pawn = AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => PawnView(
        seat: e.seat,
        size: pawnSize,
        highlight: e.movable ? 0.35 + 0.65 * _pulse.value : 0,
      ),
    );

    if (e.movable) {
      pawn = Semantics(
        button: true,
        label: 'Pion ${style.colorName} ${e.pawn + 1}, jouable',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.controller.movePawn(e.pawn),
          child: Center(child: pawn),
        ),
      );
    } else {
      pawn = IgnorePointer(child: Center(child: pawn));
    }

    return AnimatedPositioned(
      key: ValueKey('pawn-${e.seat}-${e.pawn}'),
      duration: e.hopping
          ? const Duration(milliseconds: 130)
          : const Duration(milliseconds: 420),
      curve: e.hopping ? Curves.easeOut : Curves.easeInOutCubic,
      left: display.dx * cell - hit / 2,
      top: display.dy * cell - hit / 2,
      width: hit,
      height: hit,
      child: pawn,
    );
  }
}

class _PawnEntry {
  _PawnEntry({
    required this.seat,
    required this.pawn,
    required this.step,
    required this.movable,
    required this.hopping,
  });

  final int seat;
  final int pawn;
  final int step;
  final bool movable;
  final bool hopping;
  Offset stackOffset = Offset.zero;
  bool stacked = false;

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
