/// Chorégraphie de la prise de karaté (Dart pur) : où sont les deux lutins
/// et dans quelle posture, à chaque instant de l'animation.
///
/// Coordonnées en « cases » du plateau affiché (x vers la droite, y vers le
/// bas) ; un lutin est placé par ses pieds.
library;

import 'dart:math' as math;

import 'lutin_art.dart';

class Pt {
  const Pt(this.x, this.y);
  final double x, y;
  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double k) => Pt(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
  static Pt lerp(Pt a, Pt b, double t) => Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

/// Un lutin à un instant de l'animation.
class FighterFrame {
  const FighterFrame({
    required this.feet,
    required this.lift,
    required this.pose,
    required this.facingLeft,
    this.rotation = 0,
    this.scale = 1,
    this.stars = false,
  });

  /// Position au sol (l'ombre y reste).
  final Pt feet;

  /// Hauteur au-dessus du sol, en cases.
  final double lift;
  final LutinPose pose;
  final bool facingLeft;

  /// Rotation du lutin entier (vrille du pion avalé), en radians.
  final double rotation;
  final double scale;

  /// Étoiles de lutin sonné.
  final bool stars;
}

class FightFrame {
  const FightFrame({
    required this.attacker,
    required this.victims,
    required this.impactAt,
    this.impact,
  });

  final FighterFrame attacker;
  final List<FighterFrame> victims;

  /// Avancement de l'étoile « PAF » (0 à 1), ou null si elle n'est pas visible.
  final double? impact;
  final Pt impactAt;
}

/// Moments clés (fraction de la durée totale).
abstract final class FightTiming {
  static const double windupEnd = 0.12;
  static const double impact = 0.34;
  static const double attackerLanded = 0.46;
  static const double victimLanded = 0.80;
  static const double bowStart = 0.82;
  static const double bowEnd = 0.94;
  static const double impactLength = 0.18;
}

double _ease(double t) => t * t * (3 - 2 * t);
double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Image de la prise de karaté à l'instant [t] (0 à 1).
///
/// [start] : où se trouve l'attaquant avant de sauter ; [target] : la case
/// du pion avalé ; [homes] : les places de base où retournent les pions avalés.
FightFrame fightFrame(double t, Pt start, Pt target, List<Pt> homes) {
  final delta = target - start;
  final dist = delta.length;
  final dir = dist < 1e-6 ? const Pt(1, 0) : delta * (1 / dist);
  final attackerLeft = dir.x < -0.05 || (dir.x.abs() <= 0.05 && dir.y > 0);
  final contact = dist < 0.6 ? target : target - dir * 0.48;

  // --- Attaquant ---------------------------------------------------------
  FighterFrame attacker;
  if (t < FightTiming.windupEnd) {
    attacker = FighterFrame(
      feet: start,
      lift: 0,
      pose: LutinPose.lerp(LutinPose.idle, LutinPose.windup, _ease(_seg(t, 0, FightTiming.windupEnd))),
      facingLeft: attackerLeft,
    );
  } else if (t < FightTiming.impact) {
    final u = _seg(t, FightTiming.windupEnd, FightTiming.impact);
    final arc = (0.55 + 0.22 * dist).clamp(0.6, 1.7);
    attacker = FighterFrame(
      feet: Pt.lerp(start, contact, _ease(u)),
      lift: arc * 4 * u * (1 - u) + 0.35 * u,
      pose: LutinPose.lerp(LutinPose.windup, LutinPose.kick, (u * 2.2).clamp(0.0, 1.0)),
      facingLeft: attackerLeft,
    );
  } else if (t < FightTiming.attackerLanded) {
    final u = _seg(t, FightTiming.impact, FightTiming.attackerLanded);
    final pose = u < 0.5
        ? LutinPose.kick
        : LutinPose.lerp(LutinPose.kick, const LutinPose(squash: 0.8), _ease((u - 0.5) * 2));
    attacker = FighterFrame(
      feet: Pt.lerp(contact, target, _ease(u)),
      lift: 0.35 * (1 - u) + 0.2 * math.sin(math.pi * u),
      pose: pose,
      facingLeft: attackerLeft,
    );
  } else if (t < FightTiming.bowStart) {
    final u = _seg(t, FightTiming.attackerLanded, FightTiming.bowStart);
    final bounce = (math.sin(u * math.pi * 3)).abs() * 0.16;
    attacker = FighterFrame(
      feet: target,
      lift: bounce,
      pose: LutinPose.lerp(const LutinPose(squash: 0.8), LutinPose.cheer, _ease((u * 4).clamp(0.0, 1.0))),
      facingLeft: attackerLeft,
    );
  } else {
    // Salut de karaté, puis retour au repos.
    final pose = t < FightTiming.bowEnd
        ? LutinPose.lerp(LutinPose.cheer, LutinPose.bow, _ease(_seg(t, FightTiming.bowStart, FightTiming.bowStart + 0.05)))
        : LutinPose.lerp(LutinPose.bow, LutinPose.idle, _ease(_seg(t, FightTiming.bowEnd, 1)));
    attacker = FighterFrame(feet: target, lift: 0, pose: pose, facingLeft: attackerLeft);
  }

  // --- Pions avalés --------------------------------------------------------
  final victims = <FighterFrame>[];
  for (var i = 0; i < homes.length; i++) {
    final home = homes[i];
    final spot = homes.length > 1 ? target + Pt(i == 0 ? -0.2 : 0.2, 0) : target;
    if (t < FightTiming.impact) {
      final scare = _ease(_seg(t, FightTiming.windupEnd + 0.06, FightTiming.impact));
      victims.add(FighterFrame(
        feet: spot,
        lift: 0,
        pose: LutinPose.lerp(LutinPose.idle, LutinPose.scared, scare),
        facingLeft: !attackerLeft,
      ));
    } else if (t < FightTiming.victimLanded) {
      final u = _seg(t, FightTiming.impact, FightTiming.victimLanded);
      final span = (home - spot).length;
      final arc = (1.3 + 0.18 * span).clamp(1.4, 3.2);
      final spin = (attackerLeft ? -1 : 1) * math.pi * 4 * _ease(u);
      final feet = Pt.lerp(spot, home, u);
      // Ne pas sortir du plateau par le haut (le lutin mesure ~1,5 case).
      final maxLift = math.max(0.3, feet.y - 1.5);
      victims.add(FighterFrame(
        feet: feet,
        lift: math.min(arc * 4 * u * (1 - u), maxLift),
        pose: LutinPose.hit,
        facingLeft: !attackerLeft,
        rotation: spin,
        scale: 1 - 0.15 * math.sin(math.pi * u),
      ));
    } else {
      final u = _seg(t, FightTiming.victimLanded, 1);
      victims.add(FighterFrame(
        feet: home,
        lift: 0,
        pose: LutinPose.lerp(
            LutinPose.lerp(LutinPose.hit, const LutinPose(squash: 0.75, dizzy: 1), 0.85),
            LutinPose.idle,
            _ease(_seg(u, 0.3, 1))),
        facingLeft: !attackerLeft,
        stars: u < 0.85,
      ));
    }
  }

  final impactU = (t - FightTiming.impact) / FightTiming.impactLength;
  return FightFrame(
    attacker: attacker,
    victims: victims,
    impact: impactU >= 0 && impactU <= 1 ? impactU : null,
    impactAt: Pt.lerp(contact, target, 0.55),
  );
}
