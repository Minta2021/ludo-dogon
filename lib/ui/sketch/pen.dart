/// Petit outil de dessin vectoriel en Dart pur (sans Flutter).
///
/// Les personnages du jeu sont décrits avec ce « stylo » : dans l'application
/// il dessine sur le Canvas de Flutter (canvas_pen.dart) ; pour les essais,
/// il peut produire une image SVG. Le même dessin sert donc aux deux.
library;

/// Un tracé : suite de déplacements, lignes et courbes.
class PathSpec {
  final List<List<double>> _ops = [];

  /// Opérations : [0, x, y] déplacement, [1, x, y] ligne,
  /// [2, x1, y1, x, y] courbe quadratique,
  /// [3, x1, y1, x2, y2, x, y] courbe cubique, [4] fermeture.
  List<List<double>> get ops => _ops;

  void moveTo(double x, double y) => _ops.add([0, x, y]);
  void lineTo(double x, double y) => _ops.add([1, x, y]);
  void quadTo(double x1, double y1, double x, double y) => _ops.add([2, x1, y1, x, y]);
  void cubicTo(double x1, double y1, double x2, double y2, double x, double y) =>
      _ops.add([3, x1, y1, x2, y2, x, y]);
  void close() => _ops.add([4]);

  static PathSpec line(List<List<double>> points) {
    final p = PathSpec()..moveTo(points[0][0], points[0][1]);
    for (final pt in points.skip(1)) {
      p.lineTo(pt[0], pt[1]);
    }
    return p;
  }

  static PathSpec polygon(List<List<double>> points) => line(points)..close();

  static PathSpec ellipse(double cx, double cy, double rx, double ry) {
    const k = 0.5522847498;
    return PathSpec()
      ..moveTo(cx + rx, cy)
      ..cubicTo(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry)
      ..cubicTo(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy)
      ..cubicTo(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry)
      ..cubicTo(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy)
      ..close();
  }

  static PathSpec circle(double cx, double cy, double r) => ellipse(cx, cy, r, r);

  /// Rectangle aux coins arrondis.
  static PathSpec rrect(double l, double t, double w, double h, double r) {
    final rr = r.clamp(0, (w < h ? w : h) / 2).toDouble();
    const k = 0.5522847498;
    final rk = rr * k;
    final x2 = l + w, y2 = t + h;
    return PathSpec()
      ..moveTo(l + rr, t)
      ..lineTo(x2 - rr, t)
      ..cubicTo(x2 - rr + rk, t, x2, t + rr - rk, x2, t + rr)
      ..lineTo(x2, y2 - rr)
      ..cubicTo(x2, y2 - rr + rk, x2 - rr + rk, y2, x2 - rr, y2)
      ..lineTo(l + rr, y2)
      ..cubicTo(l + rr - rk, y2, l, y2 - rr + rk, l, y2 - rr)
      ..lineTo(l, t + rr)
      ..cubicTo(l, t + rr - rk, l + rr - rk, t, l + rr, t)
      ..close();
  }
}

/// Surface de dessin : Flutter ou SVG.
abstract class Pen {
  void save();
  void restore();
  void translate(double dx, double dy);
  void rotate(double radians);
  void scale(double sx, double sy);

  /// Remplit [path] avec la couleur [argb] (0xAARRGGBB).
  void fill(PathSpec path, int argb);

  /// Trace le contour de [path], extrémités arrondies.
  void stroke(PathSpec path, int argb, double width);
}

/// Couleur [argb] avec une opacité multipliée par [opacity] (0 à 1).
int withOpacity(int argb, double opacity) {
  final a = ((argb >> 24) & 0xFF) * opacity.clamp(0.0, 1.0);
  return (a.round() << 24) | (argb & 0x00FFFFFF);
}
