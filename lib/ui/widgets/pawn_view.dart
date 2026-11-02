/// Un pion : petit lutin portant le masque dogon de son joueur.
library;

import 'package:flutter/material.dart';

import '../sketch/canvas_pen.dart';
import '../sketch/lutin_art.dart';

/// Rapport hauteur / largeur de la boîte d'un lutin.
const double lutinBoxRatio = 1.6;

/// Distance entre les pieds et le bas de la boîte, en fraction de la largeur.
const double lutinFeetMargin = 0.1;

/// Dessine un lutin dans une boîte de [width] x [width] × 1,6, les pieds
/// en bas au centre.
class LutinView extends StatelessWidget {
  const LutinView({
    super.key,
    required this.seat,
    required this.width,
    this.pose = LutinPose.idle,
    this.facingLeft = false,
    this.glow = 0,
    this.lift = 0,
    this.shadow = true,
  });

  final int seat;
  final double width;
  final LutinPose pose;
  final bool facingLeft;

  /// Anneau lumineux au sol (0 = aucun) : le pion peut être joué.
  final double glow;

  /// Hauteur du saut, en fraction de la largeur.
  final double lift;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * lutinBoxRatio),
      painter: LutinPainter(
        seat: seat,
        pose: pose,
        facingLeft: facingLeft,
        glow: glow,
        lift: lift,
        shadow: shadow,
      ),
    );
  }
}

class LutinPainter extends CustomPainter {
  LutinPainter({
    required this.seat,
    required this.pose,
    required this.facingLeft,
    required this.glow,
    required this.lift,
    required this.shadow,
  });

  final int seat;
  final LutinPose pose;
  final bool facingLeft;
  final double glow;
  final double lift;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = CanvasPen(canvas);
    final unit = size.width / 100;
    canvas.save();
    canvas.translate(size.width / 2, size.height - size.width * lutinFeetMargin);
    canvas.scale(unit, unit);
    if (glow > 0) drawLutinGlow(pen, glow);
    if (shadow) drawLutinShadow(pen, opacity: 0.35 - (lift * 0.6).clamp(0.0, 0.2));
    canvas.translate(0, -lift * 100);
    drawLutin(pen, seat: seat, pose: pose, facingLeft: facingLeft);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LutinPainter old) =>
      old.seat != seat ||
      !identical(old.pose, pose) ||
      old.facingLeft != facingLeft ||
      old.glow != glow ||
      old.lift != lift ||
      old.shadow != shadow;
}

/// Le lutin vainqueur qui sautille en levant les bras.
class CheeringLutin extends StatefulWidget {
  const CheeringLutin({super.key, required this.seat, required this.width});

  final int seat;
  final double width;

  @override
  State<CheeringLutin> createState() => _CheeringLutinState();
}

class _CheeringLutinState extends State<CheeringLutin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return LutinView(
          seat: widget.seat,
          width: widget.width,
          pose: LutinPose.lerp(const LutinPose(squash: 0.88), LutinPose.cheer, t),
          lift: 0.12 * t,
        );
      },
    );
  }
}
