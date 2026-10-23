import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_dogon/game/ai.dart';
import 'package:ludo_dogon/game/board.dart';
import 'package:ludo_dogon/game/rules.dart';

/// Construit un état avec des pions placés à la main.
GameState stateWith(
  Map<int, List<int>> placed, {
  List<int> seats = const [0, 1, 2, 3],
  int current = 0,
  int? dice,
  Phase phase = Phase.rolling,
  int sixes = 0,
}) {
  final steps = [
    for (var s = 0; s < 4; s++) placed[s] ?? const [-1, -1, -1, -1],
  ];
  return GameState(
    seats: seats,
    steps: steps,
    current: current,
    dice: dice,
    phase: phase,
    sixes: sixes,
  );
}

void main() {
  group('Plateau', () {
    test('le parcours a 52 cases distinctes', () {
      expect(Board.track.length, 52);
      expect(Board.track.toSet().length, 52);
    });

    test('chaque case du parcours touche la suivante', () {
      for (var i = 0; i < Board.trackLength; i++) {
        final a = Board.track[i];
        final b = Board.track[(i + 1) % Board.trackLength];
        final dr = (a.row - b.row).abs();
        final dc = (a.col - b.col).abs();
        expect(dr <= 1 && dc <= 1 && dr + dc >= 1, isTrue,
            reason: 'cases $i et ${i + 1} : $a -> $b');
      }
    });

    test('les couloirs ne chevauchent ni le parcours ni les bases', () {
      final trackCells = Board.track.toSet();
      for (var seat = 0; seat < 4; seat++) {
        expect(Board.lanes[seat].length, Board.laneLength);
        for (final cell in Board.lanes[seat]) {
          expect(trackCells.contains(cell), isFalse);
          final inArm = (cell.row >= 6 && cell.row <= 8) ||
              (cell.col >= 6 && cell.col <= 8);
          expect(inArm, isTrue, reason: 'couloir $seat : $cell');
        }
      }
    });

    test('la case avant le couloir touche le début du couloir', () {
      for (var seat = 0; seat < 4; seat++) {
        final last = Board.cellFor(seat, Board.lastTrackStep)!;
        final firstLane = Board.cellFor(seat, Board.lastTrackStep + 1)!;
        expect((last.row - firstLane.row).abs() + (last.col - firstLane.col).abs(), 1);
      }
    });

    test('les départs sont dans le bon bras du plateau', () {
      expect(Board.cellFor(0, 0), const GridPos(6, 1));
      expect(Board.cellFor(1, 0), const GridPos(1, 8));
      expect(Board.cellFor(2, 0), const GridPos(8, 13));
      expect(Board.cellFor(3, 0), const GridPos(13, 6));
    });

    test('huit cases protégées', () {
      final safe = [
        for (var i = 0; i < Board.trackLength; i++)
          if (Board.isSafeIndex(i)) i
      ];
      expect(safe, [0, 8, 13, 21, 26, 34, 39, 47]);
    });
  });

  group('Sortie de base', () {
    test('il faut un 6 pour sortir', () {
      final s = GameState.initial([0, 2]);
      final r = Rules.roll(s, 4);
      expect(r.end, RollEnd.noMove);
      expect(r.state.current, 2);

      final r6 = Rules.roll(s, 6);
      expect(r6.end, RollEnd.mustMove);
      expect(r6.legal, [0, 1, 2, 3]);
      final m = Rules.move(r6.state, 0);
      expect(m.to, 0);
      expect(m.extraTurn, isTrue);
      expect(m.state.current, 0);
      expect(m.state.phase, Phase.rolling);
    });
  });

  group('Captures', () {
    test('tomber sur un adversaire le renvoie à sa base', () {
      // Siège 0 à l'étape 3 (case 3), siège 1 à l'étape 44 (case (13+44)%52 = 5).
      final s = stateWith({0: [3, -1, -1, -1], 1: [44, -1, -1, -1]},
          seats: [0, 1], dice: 2, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.captures.length, 1);
      expect(m.captures.first.seat, 1);
      expect(m.state.steps[1][0], Board.inBase);
      expect(m.extraTurn, isTrue);
      expect(m.state.current, 0);
    });

    test('pas de capture sur un grenier', () {
      // Case 8 = grenier. Siège 1 à l'étape 47 -> case (13+47)%52 = 8.
      final s = stateWith({0: [5, -1, -1, -1], 1: [47, -1, -1, -1]},
          seats: [0, 1], dice: 3, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.captures, isEmpty);
      expect(m.state.steps[1][0], 47);
      expect(m.extraTurn, isFalse);
      expect(m.state.current, 1);
    });

    test('pas de capture sur une case de départ', () {
      // Case 13 = départ du siège 1.
      final s = stateWith({0: [10, -1, -1, -1], 1: [0, -1, -1, -1]},
          seats: [0, 1], dice: 3, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.captures, isEmpty);
    });

    test('tous les pions adverses de la case sont capturés', () {
      final s = stateWith({0: [3, -1, -1, -1], 1: [44, 44, -1, -1]},
          seats: [0, 1], dice: 2, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.captures.length, 2);
    });

    test('un pion dans son couloir ne peut pas être capturé', () {
      // Siège 1 dans son couloir (étape 52) ; le siège 0 passe à côté.
      final s = stateWith({0: [10, -1, -1, -1], 1: [52, -1, -1, -1]},
          seats: [0, 1], dice: 1, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.captures, isEmpty);
      expect(m.state.steps[1][0], 52);
    });
  });

  group('Arrivée', () {
    test('il faut le nombre exact pour entrer dans la toguna', () {
      final s = stateWith({0: [53, -1, -1, -1]}, seats: [0, 1]);
      expect(Rules.legalPawns(s, 0, 4), isEmpty);
      expect(Rules.legalPawns(s, 0, 3), [0]);
    });

    test('arriver donne un nouveau lancer', () {
      final s = stateWith({0: [53, 56, -1, -1]},
          seats: [0, 1], dice: 3, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.reachedHome, isTrue);
      expect(m.extraTurn, isTrue);
      expect(m.state.current, 0);
    });

    test('ramener le 4e pion termine la partie à deux', () {
      final s = stateWith({0: [53, 56, 56, 56], 1: [10, -1, -1, -1]},
          seats: [0, 1], dice: 3, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.seatFinished, isTrue);
      expect(m.gameOver, isTrue);
      expect(m.state.ranking, [0, 1]);
    });

    test('à quatre, la partie continue après le premier gagnant', () {
      final s = stateWith({0: [55, 56, 56, 56]},
          seats: [0, 1, 2, 3], dice: 1, phase: Phase.moving);
      final m = Rules.move(s, 0);
      expect(m.seatFinished, isTrue);
      expect(m.gameOver, isFalse);
      expect(m.extraTurn, isFalse);
      expect(m.state.current, 1);
      expect(m.state.ranking, [0]);
      expect(Rules.nextSeat(m.state, 3), 1);
    });
  });

  group('Fin anticipée', () {
    test('les joueurs restants sont classés selon leur avancée', () {
      const s = GameState(
        seats: [0, 1, 2, 3],
        steps: [
          [56, 56, 56, 56],
          [10, -1, -1, -1],
          [40, 30, 2, -1],
          [-1, -1, -1, -1],
        ],
        current: 1,
        phase: Phase.rolling,
        ranking: [0],
      );
      final end = Rules.finishEarly(s);
      expect(end.isOver, isTrue);
      expect(end.ranking, [0, 2, 1, 3]);
    });
  });

  group('Six', () {
    test('un 6 sans coup possible fait relancer', () {
      final s = stateWith({0: [55, 56, 56, 56]}, seats: [0, 1]);
      final r = Rules.roll(s, 6);
      expect(r.end, RollEnd.noMoveRollAgain);
      expect(r.state.current, 0);
      expect(r.state.sixes, 1);
    });

    test('trois 6 de suite font perdre le tour', () {
      final s = stateWith({0: [10, -1, -1, -1]}, seats: [0, 1], sixes: 2);
      final r = Rules.roll(s, 6);
      expect(r.end, RollEnd.threeSixes);
      expect(r.state.current, 1);
      expect(r.state.sixes, 0);
    });

    test('un coup normal après un 6 garde le compteur', () {
      final s = stateWith({0: [10, -1, -1, -1]}, seats: [0, 1]);
      final r = Rules.roll(s, 6);
      final m = Rules.move(r.state, 0);
      expect(m.state.sixes, 1);
      final r2 = Rules.roll(m.state, 2);
      expect(r2.state.sixes, 0);
    });
  });

  group('Sérialisation', () {
    test('aller-retour JSON', () {
      final s = stateWith({0: [3, 52, -1, 56], 2: [20, -1, -1, -1]},
          seats: [0, 2], dice: 5, phase: Phase.moving, sixes: 1);
      final back = GameState.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back.steps, s.steps);
      expect(back.seats, s.seats);
      expect(back.dice, 5);
      expect(back.phase, Phase.moving);
      expect(back.sixes, 1);
    });
  });

  group('Ordinateur', () {
    test('préfère capturer', () {
      final s = stateWith({0: [3, 20, -1, -1], 1: [44, -1, -1, -1]},
          seats: [0, 1], dice: 2, phase: Phase.moving);
      final pawn = Bot.choosePawn(s, Rules.currentLegalPawns(s), Random(1));
      expect(pawn, 0);
    });

    test('préfère rentrer à la toguna', () {
      final s = stateWith({0: [52, 10, -1, -1]},
          seats: [0, 1], dice: 4, phase: Phase.moving);
      final pawn = Bot.choosePawn(s, Rules.currentLegalPawns(s), Random(1));
      expect(pawn, 0);
    });
  });

  group('Simulation', () {
    test('des parties complètes entre ordinateurs se terminent', () {
      final rng = Random(42);
      for (var game = 0; game < 300; game++) {
        final seats = [
          [0, 2],
          [0, 1, 2],
          [0, 1, 2, 3],
          [1, 3],
        ][game % 4];
        var state = GameState.initial(seats);
        var actions = 0;
        while (!state.isOver) {
          expect(actions < 20000, isTrue, reason: 'partie $game bloquée');
          final roll = Rules.roll(state, 1 + rng.nextInt(6));
          state = roll.state;
          if (roll.end == RollEnd.mustMove) {
            final pawn = Bot.choosePawn(state, roll.legal, rng,
                level: game.isEven ? BotLevel.normal : BotLevel.easy);
            state = Rules.move(state, pawn).state;
          }
          actions++;
          _checkInvariants(state);
        }
        expect(state.ranking.length, seats.length);
        expect(state.ranking.toSet().length, seats.length);
      }
    });
  });
}

void _checkInvariants(GameState s) {
  // Deux couleurs différentes ne partagent jamais une case non protégée.
  final owners = <int, int>{};
  for (final seat in s.seats) {
    for (final step in s.steps[seat]) {
      expect(step >= -1 && step <= Board.homeStep, isTrue);
      if (step < 0 || step > Board.lastTrackStep) continue;
      final index = Board.absoluteIndex(seat, step);
      if (Board.isSafeIndex(index)) continue;
      final owner = owners[index];
      expect(owner == null || owner == seat, isTrue,
          reason: 'case $index partagée par $owner et $seat');
      owners[index] = seat;
    }
  }
  if (!s.isOver) {
    expect(s.ranking.contains(s.current), isFalse);
  }
}
