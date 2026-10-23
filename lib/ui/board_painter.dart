/// Dessin du plateau dogon : bases en damier, parcours en banco, greniers,
/// couloirs colorés et toguna au centre.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/board.dart';
import 'board_geometry.dart';
import 'dogon_icons.dart';
import 'theme.dart';

class BoardPainter extends CustomPainter {
  BoardPainter({required this.rotation, required this.activeSeats});

  /// Quarts de tour appliqués à l'affichage.
  final int rotation;

  /// Sièges qui jouent (les autres bases sont estompées).
  final Set<int> activeSeats;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = DogonColors.bancoLine.withValues(alpha: 0.55)
      ..strokeWidth = math.max(0.6, cell * 0.03);
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..color = DogonColors.nightDeep
      ..strokeWidth = math.max(1.2, cell * 0.08);

    Rect cellRect(GridPos p) {
      final d = BoardGeometry.rotateCell(p, rotation);
      return Rect.fromLTWH(d.col * cell, d.row * cell, cell, cell);
    }

    Offset unit(Offset logical) {
      final d = BoardGeometry.rotatePoint(logical, rotation);
      return Offset(d.dx * cell, d.dy * cell);
    }

    Color seatColor(int seat) {
      final c = seatStyles[seat].color;
      return activeSeats.contains(seat) ? c : Color.lerp(c, DogonColors.banco, 0.6)!;
    }

    Color seatShade(int seat) {
      final c = seatStyles[seat].shade;
      return activeSeats.contains(seat) ? c : Color.lerp(c, DogonColors.banco, 0.6)!;
    }

    // Fond en banco.
    canvas.drawRect(Offset.zero & size, fill..color = DogonColors.banco);

    // Bases : damier dogon dans la couleur du joueur.
    for (var seat = 0; seat < Board.seatCount; seat++) {
      final o = Board.baseOrigins[seat];
      final a = cellRect(o);
      final b = cellRect(GridPos(o.row + 5, o.col + 5));
      final base = a.expandToInclude(b);
      canvas.drawRect(base, fill..color = seatColor(seat));
      final half = cell / 2;
      fill.color = seatShade(seat);
      for (var i = 0; i < 12; i++) {
        for (var j = 0; j < 12; j++) {
          if ((i + j).isOdd) continue;
          canvas.drawRect(
              Rect.fromLTWH(base.left + i * half, base.top + j * half, half, half), fill);
        }
      }
      canvas.drawRect(base, dark..strokeWidth = math.max(1, cell * 0.05));

      // Cour intérieure où attendent les pions.
      final inner = base.deflate(cell);
      final rr = RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.45));
      canvas.drawRRect(rr, fill..color = DogonColors.banco);
      canvas.drawRRect(rr, dark..strokeWidth = math.max(1.5, cell * 0.12));

      // Emplacements des pions (cercles en pointillés).
      final slotPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFA88A62)
        ..strokeWidth = math.max(1, cell * 0.07);
      for (var pawn = 0; pawn < Board.pawnsPerPlayer; pawn++) {
        final c = unit(BoardGeometry.baseSlot(seat, pawn));
        _dashedCircle(canvas, c, cell * 0.6, slotPaint);
      }
    }

    // Parcours commun.
    for (var i = 0; i < Board.trackLength; i++) {
      final r = cellRect(Board.track[i]);
      final startSeat = Board.startSeatOf(i);
      canvas.drawRect(
          r, fill..color = startSeat != null ? seatColor(startSeat) : DogonColors.banco);
      canvas.drawRect(r, line);
      if (Board.isGranaryIndex(i)) {
        paintDogonIcon(canvas, r.deflate(cell * 0.14), DogonIcon.granary,
            DogonColors.earthText,
            strokeWidth: 2.2);
      }
      if (startSeat != null) {
        // Flèche indiquant le sens de départ.
        final from = cellRect(Board.track[i]).center;
        final to = cellRect(Board.track[(i + 1) % Board.trackLength]).center;
        _chevron(canvas, from, to - from, cell * 0.28,
            seatStyles[startSeat].onColor.withValues(alpha: 0.9), cell * 0.09);
      }
    }

    // Couloirs d'arrivée et flèches d'entrée.
    for (var seat = 0; seat < Board.seatCount; seat++) {
      for (final p in Board.lanes[seat]) {
        final r = cellRect(p);
        canvas.drawRect(r, fill..color = seatColor(seat));
        canvas.drawRect(r, line);
      }
      final turnIndex = Board.absoluteIndex(seat, Board.lastTrackStep);
      final turnCell = cellRect(Board.track[turnIndex]).center;
      final laneStart = cellRect(Board.lanes[seat].first).center;
      _chevron(canvas, turnCell, laneStart - turnCell, cell * 0.26,
          seatColor(seat), cell * 0.12);
    }

    // Toguna au centre : quatre triangles aux couleurs des joueurs.
    final center = cellRect(const GridPos(6, 6))
        .expandToInclude(cellRect(const GridPos(8, 8)));
    final m = center.center;
    for (var seat = 0; seat < Board.seatCount; seat++) {
      final last = cellRect(Board.lanes[seat].last).center;
      final List<Offset> side;
      if (last.dx < center.left) {
        side = [center.topLeft, center.bottomLeft];
      } else if (last.dx > center.right) {
        side = [center.topRight, center.bottomRight];
      } else if (last.dy < center.top) {
        side = [center.topLeft, center.topRight];
      } else {
        side = [center.bottomLeft, center.bottomRight];
      }
      final tri = Path()
        ..moveTo(side[0].dx, side[0].dy)
        ..lineTo(side[1].dx, side[1].dy)
        ..lineTo(m.dx, m.dy)
        ..close();
      canvas.drawPath(tri, fill..color = seatColor(seat));
      canvas.drawPath(tri, dark..strokeWidth = math.max(1, cell * 0.05));
    }
    final disc = cell * 0.62;
    canvas.drawCircle(m, disc, fill..color = DogonColors.banco);
    canvas.drawCircle(m, disc, dark..strokeWidth = math.max(1.2, cell * 0.08));
    paintDogonIcon(canvas, Rect.fromCircle(center: m, radius: disc * 0.72),
        DogonIcon.toguna, const Color(0xFF3B2616),
        strokeWidth: 2.2);

    // Cadre.
    canvas.drawRect(Offset.zero & size, dark..strokeWidth = math.max(2, cell * 0.14));
  }

  void _dashedCircle(Canvas canvas, Offset c, double radius, Paint paint) {
    const dashes = 14;
    const sweep = math.pi * 2 / dashes;
    final rect = Rect.fromCircle(center: c, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  void _chevron(Canvas canvas, Offset at, Offset direction, double size,
      Color color, double width) {
    if (direction.distance == 0) return;
    final d = direction / direction.distance;
    final n = Offset(-d.dy, d.dx);
    final tip = at + d * size * 0.6;
    final back = at - d * size * 0.4;
    final path = Path()
      ..moveTo((back + n * size * 0.7).dx, (back + n * size * 0.7).dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo((back - n * size * 0.7).dx, (back - n * size * 0.7).dy);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.rotation != rotation || !_sameSet(old.activeSeats, activeSeats);

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Frise en damier (motif des façades dogon).
class DamierPainter extends CustomPainter {
  const DamierPainter({required this.color, this.square = 6});

  final Color color;
  final double square;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final cols = (size.width / square).ceil();
    final rows = (size.height / square).ceil();
    for (var i = 0; i < cols; i++) {
      for (var j = 0; j < rows; j++) {
        if ((i + j).isEven) {
          canvas.drawRect(Rect.fromLTWH(i * square, j * square, square, square), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(DamierPainter old) =>
      old.color != color || old.square != square;
}

/// Frise de triangles, comme une ligne de falaise.
class SawtoothPainter extends CustomPainter {
  const SawtoothPainter({required this.color, this.tooth = 16});

  final Color color;
  final double tooth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height);
    var x = 0.0;
    while (x < size.width) {
      path
        ..lineTo(x + tooth / 2, 0)
        ..lineTo(x + tooth, size.height);
      x += tooth;
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SawtoothPainter old) =>
      old.color != color || old.tooth != tooth;
}
