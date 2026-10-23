/// Le dé : faces en kaolin, points sculptés, animation de lancer.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class DiceView extends StatefulWidget {
  const DiceView({
    super.key,
    required this.value,
    required this.rolling,
    required this.enabled,
    required this.accent,
    this.onTap,
    this.size = 68,
  });

  /// Face affichée (null : pas encore lancé).
  final int? value;
  final bool rolling;

  /// Le dé attend un lancer de ce téléphone : il pulse et réagit au toucher.
  final bool enabled;

  /// Couleur du joueur dont c'est le tour.
  final Color accent;
  final VoidCallback? onTap;
  final double size;

  @override
  State<DiceView> createState() => _DiceViewState();
}

class _DiceViewState extends State<DiceView> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _rng = math.Random();
  Timer? _shuffle;
  int _face = 6;

  @override
  void initState() {
    super.initState();
    _face = widget.value ?? 6;
    _sync();
  }

  @override
  void didUpdateWidget(DiceView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.rolling) {
      if (!_spin.isAnimating) _spin.repeat();
      _shuffle ??= Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (mounted) setState(() => _face = 1 + _rng.nextInt(6));
      });
    } else {
      _shuffle?.cancel();
      _shuffle = null;
      if (_spin.isAnimating) {
        _spin.stop();
        _spin.value = 0;
      }
      if (widget.value != null) _face = widget.value!;
    }
    if (widget.enabled && !widget.rolling) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _shuffle?.cancel();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: widget.enabled,
      label: widget.rolling
          ? 'Le dé roule'
          : (widget.value == null ? 'Dé' : 'Dé : ${widget.value}'),
      hint: widget.enabled ? 'Touchez pour lancer le dé' : null,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _pulse]),
          builder: (context, _) {
            final wobble = widget.rolling ? math.sin(_spin.value * math.pi * 2) * 0.35 : 0.0;
            final glow = widget.enabled ? _pulse.value : 0.0;
            return Transform.rotate(
              angle: wobble,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: DogonColors.kaolin,
                  borderRadius: BorderRadius.circular(size * 0.22),
                  border: Border.all(color: DogonColors.nightDeep, width: 3),
                  boxShadow: [
                    const BoxShadow(color: DogonColors.nightDeep, offset: Offset(0, 4)),
                    if (glow > 0)
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.35 + 0.4 * glow),
                        blurRadius: 10 + 10 * glow,
                        spreadRadius: 1 + 3 * glow,
                      ),
                  ],
                ),
                child: CustomPaint(painter: _PipsPainter(_face)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PipsPainter extends CustomPainter {
  _PipsPainter(this.face);

  final int face;

  static const _layouts = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.2;
    final step = (size.width - pad * 2) / 2;
    final r = size.width * 0.085;
    final paint = Paint()..color = const Color(0xFF2A1A10);
    for (final i in _layouts[face] ?? const <int>[]) {
      final x = pad + (i % 3) * step;
      final y = pad + (i ~/ 3) * step;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PipsPainter old) => old.face != face;
}
