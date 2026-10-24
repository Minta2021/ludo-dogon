/// Le masque dogon qui apparaît en grand sur le plateau quand un pion est
/// avalé, puis disparaît.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../board_painter.dart';
import '../dogon_icons.dart';
import '../theme.dart';

class CaptureFlash extends StatefulWidget {
  const CaptureFlash({
    super.key,
    required this.trigger,
    required this.seat,
    this.duration = const Duration(milliseconds: 1350),
  });

  /// Change de valeur à chaque pion avalé.
  final int trigger;

  /// Siège du joueur qui a avalé (on affiche son masque).
  final int seat;
  final Duration duration;

  @override
  State<CaptureFlash> createState() => _CaptureFlashState();
}

class _CaptureFlashState extends State<CaptureFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  // Apparition avec rebond, tenue, puis envol en fondu.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.12).chain(CurveTween(curve: Curves.easeOutBack)), weight: 22),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 36),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
  ]).animate(_c);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 14),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 56),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
  ]).animate(_c);

  @override
  void didUpdateWidget(CaptureFlash old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.expand();
          final t = _c.value;
          // Petit tremblement du masque au moment où il apparaît.
          final shake = t < 0.35 ? math.sin(t * 60) * (0.35 - t) * 0.5 : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _opacity.value * 0.55,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xCC000000), Color(0x33000000)],
                      radius: 0.75,
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.rotate(
                    angle: shake,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: _MaskMedallion(seat: widget.seat),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MaskMedallion extends StatelessWidget {
  const _MaskMedallion({required this.seat});

  final int seat;

  @override
  Widget build(BuildContext context) {
    final style = seatStyles[seat];
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.58;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  const BoxShadow(color: DogonColors.nightDeep, spreadRadius: 4),
                  BoxShadow(color: style.color.withValues(alpha: 0.7), blurRadius: 40, spreadRadius: 8),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: style.color,
                        child: CustomPaint(
                          painter: DamierPainter(color: style.shade, square: size / 12),
                        ),
                      ),
                    ),
                    Container(
                      width: size * 0.74,
                      height: size * 0.74,
                      decoration: BoxDecoration(
                        color: DogonColors.kaolin,
                        shape: BoxShape.circle,
                        border: Border.all(color: DogonColors.nightDeep, width: size * 0.025),
                      ),
                      child: Center(
                        child: DogonIconView(
                          maskIcon(seat),
                          size: size * 0.5,
                          color: DogonColors.night,
                          strokeWidth: 1.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: size * 0.08),
            Container(
              padding: EdgeInsets.symmetric(horizontal: size * 0.14, vertical: size * 0.04),
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: BorderRadius.circular(size * 0.06),
                border: Border.all(color: DogonColors.nightDeep, width: 3),
              ),
              child: Text(
                'AVALÉ !',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.15,
                  letterSpacing: 2,
                  color: style.onColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
