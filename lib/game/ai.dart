/// Intelligence de l'ordinateur : choisit le pion à jouer.
library;

import 'dart:math';

import 'board.dart';
import 'rules.dart';

enum BotLevel {
  /// Joue souvent au hasard : idéal pour les enfants et les débutants.
  easy,

  /// Joue avec une stratégie : sortir, capturer, se protéger, finir.
  normal,
}

abstract final class Bot {
  /// Choisit un pion parmi [legal] pour le joueur courant de [state]
  /// (qui doit être en phase de déplacement).
  static int choosePawn(
    GameState state,
    List<int> legal,
    Random rng, {
    BotLevel level = BotLevel.normal,
  }) {
    if (legal.isEmpty) {
      throw ArgumentError('Aucun pion jouable');
    }
    if (legal.length == 1) return legal.first;
    if (level == BotLevel.easy && rng.nextDouble() < 0.45) {
      return legal[rng.nextInt(legal.length)];
    }
    var best = legal.first;
    var bestScore = double.negativeInfinity;
    for (final pawn in legal) {
      // Un léger bruit évite que l'ordinateur soit trop prévisible.
      final noise = rng.nextDouble() * (level == BotLevel.easy ? 12 : 2);
      final s = scoreMove(state, pawn) + noise;
      if (s > bestScore) {
        bestScore = s;
        best = pawn;
      }
    }
    return best;
  }

  /// Intérêt d'un coup : plus le score est haut, meilleur est le coup.
  static double scoreMove(GameState state, int pawn) {
    final seat = state.current;
    final from = state.steps[seat][pawn];
    final result = Rules.move(state, pawn);
    final to = result.to;
    var score = 0.0;

    if (result.reachedHome) score += 120;
    for (final c in result.captures) {
      score += 90 + c.from * 1.2;
    }
    if (from == Board.inBase) score += 70;
    if (from >= 0 && from <= Board.lastTrackStep && to > Board.lastTrackStep) {
      score += 45; // entre dans son couloir : plus aucun risque
    }

    final fromIndex = (from >= 0 && from <= Board.lastTrackStep)
        ? Board.absoluteIndex(seat, from)
        : null;
    final toIndex =
        to <= Board.lastTrackStep ? Board.absoluteIndex(seat, to) : null;

    // Sans abri, le danger existe partout sur le parcours.
    if (toIndex != null) {
      score -= 45 * threatsOn(result.state, seat, toIndex);
      score += 6 * targetsAhead(result.state, seat, to);
    }
    if (fromIndex != null) {
      score += 38 * threatsOn(state, seat, fromIndex); // s'échapper
    }
    score += to * 0.5; // à égalité, faire avancer le plus avancé
    return score;
  }

  /// Nombre de pions adverses qui pourraient tomber pile sur la case
  /// [index] du parcours au prochain lancer (y compris un pion qui sort de
  /// sa base sur sa case de départ avec un 6).
  static int threatsOn(GameState state, int seat, int index) {
    var threats = 0;
    for (final other in state.seats) {
      if (other == seat || state.ranking.contains(other)) continue;
      for (final s in state.steps[other]) {
        if (s == Board.inBase) continue;
        if (s > Board.lastTrackStep) continue;
        final distance = (index - Board.absoluteIndex(other, s)) % Board.trackLength;
        if (distance >= 1 && distance <= 6 && s + distance <= Board.lastTrackStep) {
          threats++;
        }
      }
      if (index == Board.startIndex(other) &&
          state.steps[other].contains(Board.inBase)) {
        threats++;
      }
    }
    return threats;
  }

  /// Nombre de pions adverses à portée de dé devant un pion à l'étape [step].
  static int targetsAhead(GameState state, int seat, int step) {
    if (step > Board.lastTrackStep) return 0;
    final index = Board.absoluteIndex(seat, step);
    var targets = 0;
    for (final other in state.seats) {
      if (other == seat) continue;
      for (final s in state.steps[other]) {
        if (s < 0 || s > Board.lastTrackStep) continue;
        final target = Board.absoluteIndex(other, s);
        final distance = (target - index) % Board.trackLength;
        if (distance >= 1 && distance <= 6 && step + distance <= Board.lastTrackStep) {
          targets++;
        }
      }
    }
    return targets;
  }
}
