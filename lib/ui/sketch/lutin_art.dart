/// Les lutins masqués de Ludo Dogon (Dart pur, dessinés avec un [Pen]).
///
/// Chaque joueur a son lutin : tunique à sa couleur, collerette de fibres et
/// masque dogon en bois peint, surmonté de la superstructure de son masque
/// (Kanaga, Sirige, Walu ou Satimbe).
///
/// Repère : origine entre les pieds, y vers le bas, le lutin regarde vers la
/// droite (x positif). Il mesure environ 100 unités de large pour 140 de haut.
library;

import 'dart:math' as math;

import 'pen.dart';

/// Couleurs des sièges (identiques à theme.dart, en entiers ARGB).
const List<int> lutinBody = [0xFFE0A43A, 0xFF2D4878, 0xFFA3402A, 0xFF6E9440];
const List<int> lutinShade = [0xFFB57F24, 0xFF1E3358, 0xFF7E2E1D, 0xFF52722E];

const int _ink = 0xFF1E140D;
const int _kaolin = 0xFFF4ECDD;
const int _wood = 0xFF7A4A28;
const int _woodDark = 0xFF5A3519;
const int _skin = 0xFF5E3B22;
const int _legs = 0xFF3B2616;
const int _straw = 0xFFD9B36A;
const int _redOchre = 0xFFB8452C;

/// Hauteur totale approximative d'un lutin (pieds → sommet du masque).
const double lutinHeight = 142;

/// Une posture : angles des membres (en radians) et attitude du corps.
///
/// Angles des membres : 0 = vers le bas, positif = vers l'avant (là où le
/// lutin regarde), négatif = vers l'arrière.
class LutinPose {
  const LutinPose({
    this.lean = 0,
    this.armBack = -0.22,
    this.armFront = 0.22,
    this.elbowBack = 0,
    this.elbowFront = 0,
    this.legBack = 0,
    this.legFront = 0,
    this.kneeBack = 0,
    this.kneeFront = 0,
    this.squash = 1,
    this.dizzy = 0,
  });

  /// Inclinaison du corps (positif = penché en avant).
  final double lean;
  final double armBack, armFront, elbowBack, elbowFront;
  final double legBack, legFront, kneeBack, kneeFront;

  /// Écrasement vertical (1 = normal, 0,8 = accroupi).
  final double squash;

  /// 0 à 1 : yeux en croix, le lutin est sonné.
  final double dizzy;

  /// Debout, bras le long du corps.
  static const idle = LutinPose();

  /// En plein saut, jambes repliées.
  static const hop = LutinPose(
    lean: 0.12,
    armBack: -1.1,
    armFront: 1.1,
    elbowBack: -0.4,
    elbowFront: 0.4,
    legBack: -0.25,
    legFront: 0.55,
    kneeBack: 1.1,
    kneeFront: 1.0,
  );

  /// Élan avant le coup : accroupi, garde haute.
  static const windup = LutinPose(
    lean: -0.12,
    armBack: -0.9,
    armFront: 1.25,
    elbowBack: -1.5,
    elbowFront: 1.6,
    legBack: -0.35,
    legFront: 0.45,
    kneeBack: 0.9,
    kneeFront: 0.9,
    squash: 0.82,
  );

  /// Coup de pied sauté : jambe avant tendue, poing en garde, bras arrière
  /// tendu en balancier.
  static const kick = LutinPose(
    lean: -0.28,
    armBack: -1.65,
    armFront: 0.95,
    elbowBack: 0.1,
    elbowFront: 1.9,
    legBack: 0.15,
    legFront: 1.72,
    kneeBack: 2.25,
    kneeFront: 0,
  );

  /// Frappé : projeté en arrière, bras et jambes en l'air, sonné.
  static const hit = LutinPose(
    lean: -0.75,
    armBack: -2.85,
    armFront: 2.2,
    elbowBack: 0.5,
    elbowFront: 0.6,
    legBack: -0.25,
    legFront: 0.95,
    kneeBack: 0.6,
    kneeFront: 0.35,
    dizzy: 1,
  );

  /// Surpris, juste avant le coup.
  static const scared = LutinPose(
    lean: -0.15,
    armBack: -2.3,
    armFront: 2.3,
    elbowBack: -0.6,
    elbowFront: 0.6,
    legBack: -0.12,
    legFront: 0.12,
  );

  /// Victoire : bras levés en V.
  static const cheer = LutinPose(
    armBack: -2.7,
    armFront: 2.7,
    elbowBack: 0.25,
    elbowFront: -0.25,
  );

  /// Salut de karaté (révérence).
  static const bow = LutinPose(
    lean: 0.55,
    armBack: -0.05,
    armFront: 0.05,
  );

  static LutinPose lerp(LutinPose a, LutinPose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return LutinPose(
      lean: l(a.lean, b.lean),
      armBack: l(a.armBack, b.armBack),
      armFront: l(a.armFront, b.armFront),
      elbowBack: l(a.elbowBack, b.elbowBack),
      elbowFront: l(a.elbowFront, b.elbowFront),
      legBack: l(a.legBack, b.legBack),
      legFront: l(a.legFront, b.legFront),
      kneeBack: l(a.kneeBack, b.kneeBack),
      kneeFront: l(a.kneeFront, b.kneeFront),
      squash: l(a.squash, b.squash),
      dizzy: l(a.dizzy, b.dizzy),
    );
  }
}

/// Ombre au sol, sous les pieds (à dessiner avant le lutin, sans rotation).
void drawLutinShadow(Pen pen, {double opacity = 0.35, double width = 1}) {
  pen.fill(PathSpec.ellipse(0, 0, 30 * width, 7 * width), withOpacity(0xFF000000, opacity));
}

/// Anneau lumineux sous un lutin jouable.
void drawLutinGlow(Pen pen, double strength) {
  pen.stroke(PathSpec.ellipse(0, 0, 38, 11), withOpacity(_kaolin, 0.5 + 0.5 * strength), 5);
  pen.stroke(PathSpec.ellipse(0, 0, 44, 14), withOpacity(_ink, 0.55), 2.5);
}

/// Dessine le lutin du siège [seat] dans la posture [pose].
void drawLutin(Pen pen, {required int seat, LutinPose pose = LutinPose.idle, bool facingLeft = false}) {
  final body = lutinBody[seat];
  final shade = lutinShade[seat];
  pen.save();
  if (facingLeft) pen.scale(-1, 1);
  // Écrasement depuis les pieds, puis inclinaison autour du ventre.
  final sq = pose.squash;
  pen.scale(1 + (1 - sq) * 0.7, sq);
  pen.translate(0, -60);
  pen.rotate(pose.lean);
  pen.translate(0, 60);

  _arm(pen, -17, pose.armBack, pose.elbowBack, shade);
  _leg(pen, -10, pose.legBack, pose.kneeBack);
  _leg(pen, 10, pose.legFront, pose.kneeFront);
  _tunic(pen, body, shade);
  _ruff(pen);
  _mask(pen, seat, pose.dizzy);
  _arm(pen, 17, pose.armFront, pose.elbowFront, shade);
  pen.restore();
}

List<double> _from(double x, double y, double angle, double length) =>
    [x + length * math.sin(angle), y + length * math.cos(angle)];

void _leg(Pen pen, double hipX, double angle, double knee) {
  const hipY = -30.0;
  final k = _from(hipX, hipY, angle, 15);
  final shin = angle - knee;
  final f = _from(k[0], k[1], shin, 15);
  final path = PathSpec.line([
    [hipX, hipY],
    k,
    f,
  ]);
  pen.stroke(path, _ink, 13);
  pen.stroke(path, _legs, 8.5);
  // Pied : ovale orienté vers l'avant, perpendiculaire au tibia.
  pen.save();
  pen.translate(f[0], f[1]);
  pen.rotate(-shin);
  pen.fill(PathSpec.ellipse(3, 1, 8, 5), _ink);
  pen.restore();
}

void _arm(Pen pen, double shoulderX, double angle, double elbow, int sleeve) {
  const shoulderY = -56.0;
  final e = _from(shoulderX, shoulderY, angle, 12);
  final h = _from(e[0], e[1], angle + elbow, 12);
  final path = PathSpec.line([
    [shoulderX, shoulderY],
    e,
    h,
  ]);
  pen.stroke(path, _ink, 12);
  pen.stroke(path, sleeve, 7.5);
  pen.fill(PathSpec.circle(h[0], h[1], 6.2), _ink);
  pen.fill(PathSpec.circle(h[0], h[1], 4.4), _skin);
}

void _tunic(Pen pen, int body, int shade) {
  final robe = PathSpec()
    ..moveTo(-17, -62)
    ..lineTo(17, -62)
    ..quadTo(22, -44, 27, -25)
    ..quadTo(0, -20, -27, -25)
    ..quadTo(-22, -44, -17, -62)
    ..close();
  pen.fill(robe, body);
  // Ceinture et bande en damier au bas de la tunique.
  pen.fill(PathSpec.rrect(-20, -46, 40, 4, 1), shade);
  for (var i = 0; i < 8; i++) {
    final x = -24 + i * 6.0;
    pen.fill(PathSpec.rrect(x, i.isEven ? -33 : -29.5, 6, 3.5, 0.5), _kaolin);
  }
  pen.stroke(robe, _ink, 3);
}

void _ruff(Pen pen) {
  final band = PathSpec.rrect(-21, -66, 42, 9, 4);
  pen.fill(band, _straw);
  for (var i = 0; i < 9; i++) {
    final x = -17 + i * 4.25;
    pen.stroke(
        PathSpec.line([
          [x, -64],
          [x - 1, -58.5],
        ]),
        withOpacity(_woodDark, 0.8),
        1.3);
  }
  pen.stroke(band, _ink, 2.5);
}

void _mask(Pen pen, int seat, double dizzy) {
  // Superstructure (derrière le visage).
  switch (seat) {
    case 0:
      _kanaga(pen);
    case 1:
      _sirige(pen);
    case 2:
      _walu(pen);
    default:
      _satimbe(pen);
  }
  // Visage en bois.
  final face = PathSpec.rrect(-15.5, -101, 31, 41, 5);
  pen.fill(face, _wood);
  // Frise de triangles en kaolin en haut du masque.
  for (var i = 0; i < 5; i++) {
    final x = -13.5 + i * 5.4;
    pen.fill(
        PathSpec.polygon([
          [x, -98],
          [x + 5.4, -98],
          [x + 2.7, -93.5],
        ]),
        _kaolin);
  }
  // Arête du nez et bouche.
  pen.fill(PathSpec.rrect(-2.2, -95, 4.4, 26, 1.5), _kaolin);
  // Joues peintes en ocre rouge.
  pen.fill(PathSpec.circle(-9.5, -72, 2.2), _redOchre);
  pen.fill(PathSpec.circle(9.5, -72, 2.2), _redOchre);
  if (dizzy < 0.5) {
    // Yeux : cavités rectangulaires.
    pen.fill(PathSpec.rrect(-12, -90, 7.5, 13, 1.5), _ink);
    pen.fill(PathSpec.rrect(4.5, -90, 7.5, 13, 1.5), _ink);
    pen.fill(PathSpec.rrect(-4.5, -68, 9, 5.5, 1.5), _ink);
  } else {
    // Sonné : yeux en croix et bouche ouverte.
    for (final cx in [-8.25, 8.25]) {
      pen.stroke(
          PathSpec.line([
            [cx - 3.5, -87],
            [cx + 3.5, -80],
          ]),
          _kaolin,
          2.6);
      pen.stroke(
          PathSpec.line([
            [cx + 3.5, -87],
            [cx - 3.5, -80],
          ]),
          _kaolin,
          2.6);
    }
    pen.fill(PathSpec.ellipse(0, -66, 4.5, 3.5), _ink);
  }
  pen.stroke(face, _ink, 3);
}

/// Trait de bois cerné de noir.
void _beam(Pen pen, List<List<double>> pts, {double width = 5}) {
  final p = PathSpec.line(pts);
  pen.stroke(p, _ink, width + 3.5);
  pen.stroke(p, _wood, width);
}

void _kanaga(Pen pen) {
  _beam(pen, [
    [0, -101],
    [0, -137],
  ]);
  _beam(pen, [
    [-21, -137],
    [-21, -129],
    [21, -129],
    [21, -137],
  ]);
  _beam(pen, [
    [-21, -105],
    [-21, -113],
    [21, -113],
    [21, -105],
  ]);
  for (final p in [
    [-11.0, -129.0],
    [11.0, -129.0],
    [-11.0, -113.0],
    [11.0, -113.0],
  ]) {
    pen.fill(PathSpec.circle(p[0], p[1], 1.5), _kaolin);
  }
}

void _sirige(Pen pen) {
  final plank = PathSpec()
    ..moveTo(-6.5, -100)
    ..lineTo(-5, -144)
    ..lineTo(0, -150)
    ..lineTo(5, -144)
    ..lineTo(6.5, -100)
    ..close();
  pen.fill(plank, _wood);
  for (final y in [-140.0, -130.0, -120.0, -110.0]) {
    pen.fill(PathSpec.rrect(-5.5, y, 11, 3.2, 0.8), _kaolin);
  }
  pen.stroke(plank, _ink, 3);
}

void _walu(Pen pen) {
  for (final s in [-1.0, 1.0]) {
    final horn = PathSpec()
      ..moveTo(7 * s, -99)
      ..cubicTo(9 * s, -118, 16 * s, -128, 24 * s, -138);
    pen.stroke(horn, _ink, 9);
    pen.stroke(horn, _wood, 5.5);
    for (final t in [0.35, 0.62]) {
      final p = _cubicPoint([7 * s, -99], [9 * s, -118], [16 * s, -128], [24 * s, -138], t);
      pen.fill(PathSpec.circle(p[0], p[1], 1.6), _kaolin);
    }
    // Oreilles.
    final ear = PathSpec.polygon([
      [15 * s, -93],
      [24 * s, -98],
      [16 * s, -86],
    ]);
    pen.fill(ear, _wood);
    pen.stroke(ear, _ink, 2.2);
  }
}

void _satimbe(Pen pen) {
  _beam(pen, [
    [0, -101],
    [0, -113],
  ], width: 4.5);
  // Bras levés de la petite statue.
  _beam(pen, [
    [-6, -122],
    [-12, -132],
  ], width: 3.5);
  _beam(pen, [
    [6, -122],
    [12, -132],
  ], width: 3.5);
  final torso = PathSpec.rrect(-6.5, -128, 13, 17, 3);
  pen.fill(torso, _wood);
  pen.fill(PathSpec.rrect(-6.5, -123, 13, 2.6, 0.5), _kaolin);
  pen.stroke(torso, _ink, 2.5);
  final head = PathSpec.circle(0, -134, 5.5);
  pen.fill(head, _wood);
  pen.stroke(head, _ink, 2.5);
}

List<double> _cubicPoint(List<double> a, List<double> b, List<double> c, List<double> d, double t) {
  final u = 1 - t;
  double v(int i) => u * u * u * a[i] + 3 * u * u * t * b[i] + 3 * u * t * t * c[i] + t * t * t * d[i];
  return [v(0), v(1)];
}

/// Étoile d'impact « PAF » (le texte est ajouté à part). [t] de 0 à 1.
void drawImpact(Pen pen, double t) {
  final grow = t < 0.3 ? t / 0.3 : 1.0;
  final fade = t < 0.55 ? 1.0 : (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
  final r = 34 + 14 * grow;
  final star = PathSpec();
  const spikes = 11;
  for (var i = 0; i < spikes * 2; i++) {
    final a = i * math.pi / spikes + 0.2;
    final rad = i.isEven ? r : r * 0.55;
    final x = rad * math.cos(a), y = rad * math.sin(a);
    if (i == 0) {
      star.moveTo(x, y);
    } else {
      star.lineTo(x, y);
    }
  }
  star.close();
  pen.save();
  pen.scale(0.4 + 0.6 * grow, 0.4 + 0.6 * grow);
  pen.fill(star, withOpacity(0xFFF6D25C, fade));
  pen.stroke(star, withOpacity(_ink, fade), 4);
  pen.fill(PathSpec.circle(0, 0, r * 0.32), withOpacity(_kaolin, fade));
  pen.restore();
}

/// Petites étoiles qui tournent autour de la tête d'un lutin sonné.
void drawDizzyStars(Pen pen, double t) {
  for (var i = 0; i < 3; i++) {
    final a = t * math.pi * 4 + i * 2 * math.pi / 3;
    final x = 22 * math.cos(a), y = -150 + 6 * math.sin(a);
    final s = PathSpec();
    for (var k = 0; k < 10; k++) {
      final ang = k * math.pi / 5 - math.pi / 2;
      final rad = k.isEven ? 6.0 : 2.6;
      final px = x + rad * math.cos(ang), py = y + rad * math.sin(ang);
      if (k == 0) {
        s.moveTo(px, py);
      } else {
        s.lineTo(px, py);
      }
    }
    s.close();
    pen.fill(s, 0xFFF6D25C);
    pen.stroke(s, _ink, 1.5);
  }
}
