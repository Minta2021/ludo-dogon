import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_dogon/ui/sketch/fight_choreo.dart';
import 'package:ludo_dogon/ui/sketch/lutin_art.dart';
import 'package:ludo_dogon/ui/sketch/pen.dart';

/// Stylo qui ne dessine rien mais vérifie que save/restore sont équilibrés.
class _CountingPen implements Pen {
  int depth = 0, shapes = 0;
  @override
  void save() => depth++;
  @override
  void restore() => depth--;
  @override
  void translate(double dx, double dy) {}
  @override
  void rotate(double radians) {}
  @override
  void scale(double sx, double sy) {}
  @override
  void fill(PathSpec path, int argb) => shapes++;
  @override
  void stroke(PathSpec path, int argb, double width) => shapes++;
}

void main() {
  const start = Pt(2, 6);
  const target = Pt(5, 6);
  const homes = [VictimPath(Pt(5, 6), Pt(10, 2))];

  group('Prise de karaté', () {
    test('l\'attaquant part de sa case et finit sur la case du pion avalé', () {
      final a = fightFrame(0, start, target, homes);
      expect(a.attacker.feet.x, 2);
      expect(a.attacker.lift, 0);
      final b = fightFrame(1, start, target, homes);
      expect(b.attacker.feet.x, 5);
      expect(b.attacker.lift, 0);
    });

    test('le pion avalé finit dans sa base, au repos', () {
      final f = fightFrame(1, start, target, homes);
      expect(f.victims.single.feet.x, 10);
      expect(f.victims.single.feet.y, 2);
      expect(f.victims.single.rotation, 0);
      expect(f.victims.single.pose.dizzy, lessThan(0.01));
    });

    test('l\'étoile « PAF » n\'apparaît qu\'au moment du coup', () {
      expect(fightFrame(0.2, start, target, homes).impact, isNull);
      expect(fightFrame(FightTiming.impact + 0.05, start, target, homes).impact, isNotNull);
      expect(fightFrame(0.9, start, target, homes).impact, isNull);
    });

    test('personne ne passe sous le plateau ni ne sort par le haut', () {
      for (var i = 0; i <= 200; i++) {
        final f = fightFrame(i / 200, start, target, homes);
        expect(f.attacker.lift, greaterThanOrEqualTo(0));
        for (final v in f.victims) {
          expect(v.lift, greaterThanOrEqualTo(0));
          expect(v.feet.y - v.lift, greaterThanOrEqualTo(0.3));
        }
      }
    });

    test('un pion avalé ailleurs (devant une maison) part de sa propre case', () {
      const two = [VictimPath(Pt(5, 6), Pt(10, 2)), VictimPath(Pt(7, 6), Pt(1, 1))];
      final f = fightFrame(0.1, start, target, two);
      expect(f.victims[1].feet.x, 7);
      final end = fightFrame(1, start, target, two);
      expect(end.victims[1].feet.x, 1);
    });

    test('l\'attaquant regarde sa cible', () {
      expect(fightFrame(0.2, start, target, homes).attacker.facingLeft, isFalse);
      expect(fightFrame(0.2, target, start, homes).attacker.facingLeft, isTrue);
    });

    test('attaque depuis la case voisine ou depuis la base', () {
      final f = fightFrame(0.5, const Pt(5, 6), const Pt(5, 6.0001), homes);
      expect((f.attacker.feet.x - 5).abs() < 0.01, isTrue);
    });
  });

  group('Dessin des lutins', () {
    test('chaque lutin se dessine dans chaque posture', () {
      const poses = [
        LutinPose.idle,
        LutinPose.hop,
        LutinPose.windup,
        LutinPose.kick,
        LutinPose.hit,
        LutinPose.cheer,
        LutinPose.bow,
        LutinPose.scared,
      ];
      for (var seat = 0; seat < 4; seat++) {
        for (final pose in poses) {
          for (final left in [false, true]) {
            final pen = _CountingPen();
            drawLutin(pen, seat: seat, pose: pose, facingLeft: left);
            expect(pen.depth, 0);
            expect(pen.shapes, greaterThan(20));
          }
        }
      }
    });
  });
}
