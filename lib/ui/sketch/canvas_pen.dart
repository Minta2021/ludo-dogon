/// Le [Pen] qui dessine sur le Canvas de Flutter.
library;

import 'package:flutter/painting.dart';

import 'pen.dart';

class CanvasPen implements Pen {
  CanvasPen(this.canvas);

  final Canvas canvas;
  final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static Path toPath(PathSpec spec) {
    final p = Path();
    for (final o in spec.ops) {
      switch (o[0].toInt()) {
        case 0:
          p.moveTo(o[1], o[2]);
        case 1:
          p.lineTo(o[1], o[2]);
        case 2:
          p.quadraticBezierTo(o[1], o[2], o[3], o[4]);
        case 3:
          p.cubicTo(o[1], o[2], o[3], o[4], o[5], o[6]);
        case 4:
          p.close();
      }
    }
    return p;
  }

  @override
  void save() => canvas.save();

  @override
  void restore() => canvas.restore();

  @override
  void translate(double dx, double dy) => canvas.translate(dx, dy);

  @override
  void rotate(double radians) => canvas.rotate(radians);

  @override
  void scale(double sx, double sy) => canvas.scale(sx, sy);

  @override
  void fill(PathSpec path, int argb) {
    _fill.color = Color(argb);
    canvas.drawPath(toPath(path), _fill);
  }

  @override
  void stroke(PathSpec path, int argb, double width) {
    _stroke
      ..color = Color(argb)
      ..strokeWidth = width;
    canvas.drawPath(toPath(path), _stroke);
  }
}
