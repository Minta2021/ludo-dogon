/// Icônes dogon dessinées au trait : les quatre masques, le grenier,
/// la toguna et quelques pictogrammes d'interface.
///
/// Toutes les icônes sont dessinées dans un carré de 24 x 24 unités.
library;

import 'package:flutter/material.dart';

enum DogonIcon {
  kanaga,
  sirige,
  walu,
  satimbe,
  granary,
  toguna,
  bluetooth,
  people,
  robot,
  back,
  menu,
  close,
  check,
  refresh,
  book,
  chevron,
}

/// Icône du masque d'un siège (0 = Kanaga, 1 = Sirige, 2 = Walu, 3 = Satimbe).
DogonIcon maskIcon(int seat) => const [
      DogonIcon.kanaga,
      DogonIcon.sirige,
      DogonIcon.walu,
      DogonIcon.satimbe,
    ][seat];

class DogonIconView extends StatelessWidget {
  const DogonIconView(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.8,
    this.semanticLabel,
  });

  final DogonIcon icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    final painted = CustomPaint(
      size: Size.square(size),
      painter: DogonIconPainter(icon, c, strokeWidth: strokeWidth),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: painted);
    return Semantics(label: semanticLabel, image: true, child: painted);
  }
}

class DogonIconPainter extends CustomPainter {
  DogonIconPainter(this.icon, this.color, {this.strokeWidth = 1.8});

  final DogonIcon icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    paintDogonIcon(canvas, Rect.fromLTWH(0, 0, size.width, size.height), icon,
        color,
        strokeWidth: strokeWidth);
  }

  @override
  bool shouldRepaint(DogonIconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}

/// Dessine [icon] dans [rect] (utilisable depuis n'importe quel peintre).
void paintDogonIcon(Canvas canvas, Rect rect, DogonIcon icon, Color color,
    {double strokeWidth = 1.8}) {
  final s = rect.width / 24;
  Offset p(double x, double y) => Offset(rect.left + x * s, rect.top + y * s);
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth * s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void line(List<List<double>> pts, {bool close = false}) {
    final path = Path()..moveTo(p(pts[0][0], pts[0][1]).dx, p(pts[0][0], pts[0][1]).dy);
    for (final pt in pts.skip(1)) {
      final o = p(pt[0], pt[1]);
      path.lineTo(o.dx, o.dy);
    }
    if (close) path.close();
    canvas.drawPath(path, stroke);
  }

  void rrect(double x, double y, double w, double h, double r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(p(x, y).dx, p(x, y).dy, w * s, h * s), Radius.circular(r * s)),
      stroke,
    );
  }

  void curve(double x0, double y0, double x1, double y1, double x2, double y2,
      double x3, double y3) {
    final a = p(x0, y0), b = p(x1, y1), c = p(x2, y2), d = p(x3, y3);
    canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(b.dx, b.dy, c.dx, c.dy, d.dx, d.dy),
        stroke);
  }

  switch (icon) {
    case DogonIcon.kanaga:
      line([[5, 2], [5, 5], [19, 5], [19, 2]]);
      line([[5, 14], [5, 11], [19, 11], [19, 14]]);
      line([[12, 5], [12, 15]]);
      rrect(8.5, 15, 7, 7, 1.5);
    case DogonIcon.sirige:
      rrect(9, 2, 6, 20, 1);
      line([[9, 6.5], [15, 6.5]]);
      line([[9, 11], [15, 11]]);
      line([[10.5, 15.5], [10.5, 18]]);
      line([[13.5, 15.5], [13.5, 18]]);
    case DogonIcon.walu:
      curve(10, 10, 9.5, 6.5, 8, 4, 5.5, 2);
      curve(14, 10, 14.5, 6.5, 16, 4, 18.5, 2);
      rrect(8, 10, 8, 12, 2);
      line([[10.5, 14.5], [10.5, 16.5]]);
      line([[13.5, 14.5], [13.5, 16.5]]);
    case DogonIcon.satimbe:
      canvas.drawCircle(p(12, 3.5), 1.8 * s, stroke);
      line([[12, 5.5], [12, 11.5]]);
      line([[8.5, 6.5], [12, 8], [15.5, 6.5]]);
      rrect(8, 11.5, 8, 10.5, 1.5);
      line([[10.5, 15], [10.5, 17]]);
      line([[13.5, 15], [13.5, 17]]);
    case DogonIcon.granary:
      line([[4, 11], [12, 4], [20, 11]]);
      line([[6.5, 11], [6.5, 20], [17.5, 20], [17.5, 11]]);
      line([[10.5, 20], [10.5, 16], [13.5, 16], [13.5, 20]]);
    case DogonIcon.toguna:
      line([[2, 10], [5, 6.5], [19, 6.5], [22, 10], [22, 12], [2, 12]], close: true);
      line([[5, 12], [5, 19]]);
      line([[9.5, 12], [9.5, 19]]);
      line([[14.5, 12], [14.5, 19]]);
      line([[19, 12], [19, 19]]);
      line([[3, 19], [21, 19]]);
    case DogonIcon.bluetooth:
      line([[7, 7], [17, 17], [12, 22], [12, 2], [17, 7], [7, 17]]);
    case DogonIcon.people:
      canvas.drawCircle(p(9, 8), 3 * s, stroke);
      curve(3, 20, 3, 16.7, 5.7, 14, 9, 14);
      curve(9, 14, 12.3, 14, 15, 16.7, 15, 20);
      canvas.drawCircle(p(17, 9), 2.5 * s, stroke);
      curve(16, 14.2, 18.8, 14.5, 21, 16.8, 21, 20);
    case DogonIcon.robot:
      rrect(5, 7, 14, 12, 3);
      line([[12, 3], [12, 7]]);
      canvas.drawCircle(p(9.5, 12.5), 1 * s, stroke);
      canvas.drawCircle(p(14.5, 12.5), 1 * s, stroke);
      line([[9.5, 16], [14.5, 16]]);
    case DogonIcon.back:
      line([[15, 5], [8, 12], [15, 19]]);
    case DogonIcon.chevron:
      line([[9, 5], [16, 12], [9, 19]]);
    case DogonIcon.menu:
      line([[4, 7], [20, 7]]);
      line([[4, 12], [20, 12]]);
      line([[4, 17], [20, 17]]);
    case DogonIcon.close:
      line([[6, 6], [18, 18]]);
      line([[18, 6], [6, 18]]);
    case DogonIcon.check:
      line([[5, 12.5], [10, 17.5], [19, 7]]);
    case DogonIcon.refresh:
      curve(19, 12, 19, 8.1, 15.9, 5, 12, 5);
      curve(12, 5, 9.6, 5, 7.5, 6.2, 6.2, 8);
      line([[6, 4], [6, 8.2], [10.2, 8.2]]);
      curve(5, 12, 5, 15.9, 8.1, 19, 12, 19);
      curve(12, 19, 14.4, 19, 16.5, 17.8, 17.8, 16);
      line([[18, 20], [18, 15.8], [13.8, 15.8]]);
    case DogonIcon.book:
      line([[4, 5], [10, 5], [12, 7], [14, 5], [20, 5], [20, 18], [14, 18], [12, 20], [10, 18], [4, 18]], close: true);
      line([[12, 7], [12, 20]]);
  }
}
