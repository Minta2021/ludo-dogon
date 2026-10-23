/// Un pion vu du dessus : disque coloré, contour sombre et signe en kaolin
/// propre à chaque masque (pour distinguer les joueurs sans les couleurs).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class PawnView extends StatelessWidget {
  const PawnView({
    super.key,
    required this.seat,
    required this.size,
    this.highlight = 0,
  });

  final int seat;
  final double size;

  /// Intensité de la mise en valeur (0 = aucune, 1 = maximale) pour les
  /// pions jouables.
  final double highlight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PawnPainter(seat, highlight),
    );
  }
}

class _PawnPainter extends CustomPainter {
  _PawnPainter(this.seat, this.highlight);

  final int seat;
  final double highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final style = seatStyles[seat];
    final c = size.center(Offset.zero);
    final r = size.width * 0.36;

    if (highlight > 0) {
      final ring = r * (1.18 + 0.16 * highlight);
      canvas.drawCircle(
          c,
          ring,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.22
            ..color = DogonColors.kaolin.withValues(alpha: 0.55 + 0.45 * highlight));
      canvas.drawCircle(
          c,
          ring + r * 0.16,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..color = DogonColors.nightDeep.withValues(alpha: 0.8));
    }

    // Ombre portée.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, r * 0.28), width: r * 2.1, height: r * 1.8),
      Paint()..color = DogonColors.nightDeep.withValues(alpha: 0.38),
    );
    // Corps du pion.
    canvas.drawCircle(c, r, Paint()..color = style.color);
    // Reflet en haut à gauche pour un effet de bois poli.
    canvas.drawCircle(
      c - Offset(r * 0.32, r * 0.32),
      r * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, r * 0.18)
        ..color = DogonColors.nightDeep,
    );

    // Signe du masque.
    final mark = Paint()
      ..color = DogonColors.kaolin
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, r * 0.2)
      ..strokeCap = StrokeCap.round;
    final k = r * 0.42;
    switch (seat) {
      case 0: // Kanaga : un point
        canvas.drawCircle(c, r * 0.24, Paint()..color = DogonColors.kaolin);
      case 1: // Sirige : une barre verticale
        canvas.drawLine(c - Offset(0, k), c + Offset(0, k), mark);
      case 2: // Walu : deux cornes
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - k, c.dy - k * 0.8)
            ..lineTo(c.dx, c.dy + k * 0.8)
            ..lineTo(c.dx + k, c.dy - k * 0.8),
          mark..strokeJoin = StrokeJoin.round,
        );
      default: // Satimbe : une croix
        canvas.drawLine(c - Offset(k, 0), c + Offset(k, 0), mark);
        canvas.drawLine(c - Offset(0, k), c + Offset(0, k), mark);
    }
  }

  @override
  bool shouldRepaint(_PawnPainter old) =>
      old.seat != seat || old.highlight != highlight;
}
