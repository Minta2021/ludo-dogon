/// La prise de karaté jouée sur le plateau quand un pion en avale un autre.
library;

import 'package:flutter/material.dart';

import '../sketch/canvas_pen.dart';
import '../sketch/fight_choreo.dart';
import '../sketch/lutin_art.dart';
import '../theme.dart';

/// Ce qu'il faut savoir pour jouer la scène (positions en cases affichées).
class FightScene {
  const FightScene({
    required this.attackerSeat,
    required this.victimSeats,
    required this.start,
    required this.target,
    required this.homes,
  });

  final int attackerSeat;
  final List<int> victimSeats;
  final Pt start;
  final Pt target;
  final List<Pt> homes;
}

class FightLayer extends StatefulWidget {
  const FightLayer({
    super.key,
    required this.scene,
    required this.cell,
    required this.lutinWidth,
    required this.duration,
  });

  final FightScene scene;
  final double cell;

  /// Largeur d'un lutin en pixels.
  final double lutinWidth;
  final Duration duration;

  @override
  State<FightLayer> createState() => _FightLayerState();
}

class _FightLayerState extends State<FightLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _FightPainter(widget.scene, widget.cell, widget.lutinWidth, _c.value),
          ),
        ),
      ),
    );
  }
}

class _FightPainter extends CustomPainter {
  _FightPainter(this.scene, this.cell, this.lutinWidth, this.t);

  final FightScene scene;
  final double cell;
  final double lutinWidth;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = CanvasPen(canvas);
    final frame = fightFrame(t, scene.start, scene.target, scene.homes);
    final unit = lutinWidth / 100;

    void fighter(FighterFrame f, int seat) {
      canvas.save();
      canvas.translate(f.feet.x * cell, f.feet.y * cell);
      canvas.scale(unit, unit);
      drawLutinShadow(pen, opacity: (0.35 - f.lift * 0.12).clamp(0.08, 0.35), width: 1 - (f.lift * 0.15).clamp(0.0, 0.4));
      canvas.translate(0, -f.lift * cell / unit);
      canvas.translate(0, -60);
      canvas.rotate(f.rotation);
      canvas.scale(f.scale, f.scale);
      canvas.translate(0, 60);
      drawLutin(pen, seat: seat, pose: f.pose, facingLeft: f.facingLeft);
      if (f.stars) drawDizzyStars(pen, t * 3);
      canvas.restore();
    }

    for (var i = 0; i < frame.victims.length; i++) {
      fighter(frame.victims[i], scene.victimSeats[i]);
    }

    final impact = frame.impact;
    final center = Offset(frame.impactAt.x * cell, frame.impactAt.y * cell - lutinWidth * 0.75);
    if (impact != null) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(unit * 0.62, unit * 0.62);
      drawImpact(pen, impact);
      canvas.restore();
    }

    fighter(frame.attacker, scene.attackerSeat);

    if (impact != null) {
      final grow = impact < 0.3 ? impact / 0.3 : 1.0;
      final fade = impact < 0.55 ? 1.0 : (1 - (impact - 0.55) / 0.45).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'PAF !',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: lutinWidth * 0.5,
            color: DogonColors.nightDeep.withValues(alpha: fade),
            shadows: [
              Shadow(color: DogonColors.kaolin.withValues(alpha: fade), blurRadius: 0, offset: const Offset(1.5, 1.5)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(center.dx, center.dy - lutinWidth * 0.55);
      canvas.rotate(-0.18);
      final s = 0.5 + 0.5 * grow;
      canvas.scale(s, s);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FightPainter old) => old.t != t || old.cell != cell || old.scene != scene;
}
