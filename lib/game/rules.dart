/// État d'une partie et règles du jeu (code Dart pur, sans Flutter).
///
/// Règles appliquées (Ludo classique) :
/// * chaque joueur a 4 pions qui partent de sa base ;
/// * il faut un 6 pour sortir un pion sur sa case de départ ;
/// * un 6 donne un nouveau lancer ; trois 6 de suite font perdre le tour ;
/// * tomber sur un pion adverse hors case protégée le renvoie à sa base
///   et donne un nouveau lancer ;
/// * les cases de départ et les greniers sont protégés ;
/// * après un tour complet, le pion entre dans son couloir d'arrivée ;
/// * il faut le nombre exact pour atteindre la toguna, ce qui donne un
///   nouveau lancer ;
/// * le premier joueur qui ramène ses 4 pions gagne ; la partie continue
///   pour les places suivantes jusqu'à ce qu'il ne reste qu'un joueur.
library;

import 'board.dart';

/// Étape du tour en cours.
enum Phase {
  /// Le joueur courant doit lancer le dé.
  rolling,

  /// Le joueur courant doit choisir un pion à déplacer.
  moving,

  /// La partie est terminée.
  over,
}

/// Comment s'est terminé un lancer de dé.
enum RollEnd {
  /// Au moins un pion peut bouger : le joueur doit choisir.
  mustMove,

  /// Aucun pion ne peut bouger : le tour passe au joueur suivant.
  noMove,

  /// Aucun pion ne peut bouger, mais c'est un 6 : le joueur relance.
  noMoveRollAgain,

  /// Troisième 6 d'affilée : le tour passe au joueur suivant.
  threeSixes,
}

/// Photo complète d'une partie à un instant donné.
class GameState {
  const GameState({
    required this.seats,
    required this.steps,
    required this.current,
    required this.phase,
    this.dice,
    this.sixes = 0,
    this.ranking = const [],
    this.turn = 0,
  });

  /// Nouvelle partie pour les sièges donnés (2 à 4 sièges parmi 0, 1, 2, 3).
  factory GameState.initial(List<int> seats) {
    final ordered = [...seats]..sort();
    if (ordered.length < 2 || ordered.length > Board.seatCount) {
      throw ArgumentError('Il faut entre 2 et 4 joueurs.');
    }
    if (ordered.toSet().length != ordered.length ||
        ordered.any((s) => s < 0 || s >= Board.seatCount)) {
      throw ArgumentError('Sièges invalides : $seats');
    }
    return GameState(
      seats: List.unmodifiable(ordered),
      steps: List.unmodifiable([
        for (var s = 0; s < Board.seatCount; s++)
          List<int>.unmodifiable(
              List.filled(Board.pawnsPerPlayer, Board.inBase)),
      ]),
      current: ordered.first,
      phase: Phase.rolling,
    );
  }

  /// Sièges qui jouent, dans l'ordre du tour.
  final List<int> seats;

  /// Étape de chaque pion : `steps[siège][pion]`.
  /// -1 = base, 0 à 55 = en route, 56 = arrivé à la toguna.
  final List<List<int>> steps;

  /// Siège dont c'est le tour.
  final int current;

  /// Dernière valeur du dé (null avant le premier lancer).
  final int? dice;

  final Phase phase;

  /// Nombre de 6 consécutifs dans le tour en cours.
  final int sixes;

  /// Sièges ayant terminé, dans l'ordre d'arrivée.
  final List<int> ranking;

  /// Compteur d'actions, utile pour synchroniser les téléphones.
  final int turn;

  bool get isOver => phase == Phase.over;

  int stepOf(int seat, int pawn) => steps[seat][pawn];

  bool hasFinished(int seat) => ranking.contains(seat);

  int arrivedCount(int seat) =>
      steps[seat].where((s) => s == Board.homeStep).length;

  /// Sièges encore en jeu (pas encore classés).
  List<int> get playingSeats =>
      [for (final s in seats) if (!ranking.contains(s)) s];

  GameState copyWith({
    List<List<int>>? steps,
    int? current,
    int? dice,
    bool clearDice = false,
    Phase? phase,
    int? sixes,
    List<int>? ranking,
    int? turn,
  }) {
    return GameState(
      seats: seats,
      steps: steps ?? this.steps,
      current: current ?? this.current,
      dice: clearDice ? null : (dice ?? this.dice),
      phase: phase ?? this.phase,
      sixes: sixes ?? this.sixes,
      ranking: ranking ?? this.ranking,
      turn: turn ?? this.turn,
    );
  }

  Map<String, Object?> toJson() => {
        'seats': seats,
        'steps': steps,
        'current': current,
        'dice': dice,
        'phase': phase.name,
        'sixes': sixes,
        'ranking': ranking,
        'turn': turn,
      };

  factory GameState.fromJson(Map<String, Object?> json) {
    List<int> ints(Object? v) =>
        List<int>.unmodifiable((v as List).map((e) => (e as num).toInt()));
    final steps = (json['steps'] as List).map(ints).toList();
    if (steps.length != Board.seatCount ||
        steps.any((p) => p.length != Board.pawnsPerPlayer)) {
      throw const FormatException('État de partie invalide');
    }
    return GameState(
      seats: ints(json['seats']),
      steps: List.unmodifiable(steps),
      current: (json['current'] as num).toInt(),
      dice: (json['dice'] as num?)?.toInt(),
      phase: Phase.values.byName(json['phase'] as String),
      sixes: (json['sixes'] as num?)?.toInt() ?? 0,
      ranking: ints(json['ranking'] ?? const []),
      turn: (json['turn'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'GameState(turn $turn, siège $current, dé $dice, '
      '${phase.name}, pions $steps, classement $ranking)';
}

/// Un pion adverse renvoyé à sa base.
class Capture {
  const Capture({required this.seat, required this.pawn, required this.from});

  final int seat;
  final int pawn;

  /// Étape du pion capturé avant d'être renvoyé à sa base.
  final int from;
}

/// Résultat d'un lancer de dé.
class RollResult {
  const RollResult({
    required this.state,
    required this.value,
    required this.legal,
    required this.end,
  });

  final GameState state;
  final int value;

  /// Pions jouables (vide si aucun coup possible).
  final List<int> legal;
  final RollEnd end;
}

/// Résultat du déplacement d'un pion.
class MoveResult {
  const MoveResult({
    required this.state,
    required this.seat,
    required this.pawn,
    required this.from,
    required this.to,
    required this.captures,
    required this.reachedHome,
    required this.extraTurn,
    required this.seatFinished,
  });

  final GameState state;
  final int seat;
  final int pawn;
  final int from;
  final int to;
  final List<Capture> captures;
  final bool reachedHome;
  final bool extraTurn;
  final bool seatFinished;

  bool get gameOver => state.isOver;

  /// Étapes traversées une à une, pour l'animation du pion.
  List<int> get path => from == Board.inBase
      ? const [0]
      : [for (var s = from + 1; s <= to; s++) s];
}

/// Les règles du jeu. Toutes les fonctions sont pures : elles ne modifient
/// jamais l'état reçu et renvoient un nouvel état.
abstract final class Rules {
  /// Pions que [seat] peut déplacer avec [value].
  static List<int> legalPawns(GameState state, int seat, int value) {
    final result = <int>[];
    for (var p = 0; p < Board.pawnsPerPlayer; p++) {
      final s = state.steps[seat][p];
      if (s == Board.inBase) {
        if (value == 6) result.add(p);
      } else if (s < Board.homeStep && s + value <= Board.homeStep) {
        result.add(p);
      }
    }
    return result;
  }

  /// Pions jouables pour le joueur courant avec le dé déjà lancé.
  static List<int> currentLegalPawns(GameState state) {
    final d = state.dice;
    if (state.phase != Phase.moving || d == null) return const [];
    return legalPawns(state, state.current, d);
  }

  /// Le joueur courant lance le dé et obtient [value] (1 à 6).
  static RollResult roll(GameState state, int value) {
    if (state.phase != Phase.rolling) {
      throw StateError('Ce n\'est pas le moment de lancer le dé.');
    }
    if (value < 1 || value > 6) {
      throw ArgumentError.value(value, 'value', 'Le dé va de 1 à 6');
    }
    final sixes = value == 6 ? state.sixes + 1 : 0;
    final rolled = state.copyWith(dice: value, sixes: sixes, turn: state.turn + 1);

    if (sixes >= 3) {
      return RollResult(
        state: rolled.copyWith(
            current: nextSeat(rolled, state.current), phase: Phase.rolling, sixes: 0),
        value: value,
        legal: const [],
        end: RollEnd.threeSixes,
      );
    }

    final legal = legalPawns(state, state.current, value);
    if (legal.isEmpty) {
      if (value == 6) {
        return RollResult(
          state: rolled.copyWith(phase: Phase.rolling),
          value: value,
          legal: const [],
          end: RollEnd.noMoveRollAgain,
        );
      }
      return RollResult(
        state: rolled.copyWith(
            current: nextSeat(rolled, state.current), phase: Phase.rolling, sixes: 0),
        value: value,
        legal: const [],
        end: RollEnd.noMove,
      );
    }

    return RollResult(
      state: rolled.copyWith(phase: Phase.moving),
      value: value,
      legal: legal,
      end: RollEnd.mustMove,
    );
  }

  /// Le joueur courant déplace son pion [pawn] avec la valeur du dé.
  static MoveResult move(GameState state, int pawn) {
    final dice = state.dice;
    if (state.phase != Phase.moving || dice == null) {
      throw StateError('Aucun dé à jouer.');
    }
    final seat = state.current;
    if (!legalPawns(state, seat, dice).contains(pawn)) {
      throw StateError('Le pion $pawn ne peut pas avancer de $dice.');
    }

    final from = state.steps[seat][pawn];
    final to = from == Board.inBase ? 0 : from + dice;
    final steps = [for (final row in state.steps) [...row]];
    steps[seat][pawn] = to;

    // Captures sur le parcours commun, hors cases protégées.
    final captures = <Capture>[];
    if (to <= Board.lastTrackStep) {
      final target = Board.absoluteIndex(seat, to);
      if (!Board.isSafeIndex(target)) {
        for (final other in state.seats) {
          if (other == seat) continue;
          for (var q = 0; q < Board.pawnsPerPlayer; q++) {
            final s = steps[other][q];
            if (s >= 0 &&
                s <= Board.lastTrackStep &&
                Board.absoluteIndex(other, s) == target) {
              captures.add(Capture(seat: other, pawn: q, from: s));
              steps[other][q] = Board.inBase;
            }
          }
        }
      }
    }

    final reachedHome = to == Board.homeStep;
    final ranking = [...state.ranking];
    var seatFinished = false;
    if (reachedHome && steps[seat].every((s) => s == Board.homeStep)) {
      seatFinished = true;
      ranking.add(seat);
    }

    final frozen = List<List<int>>.unmodifiable(
        [for (final row in steps) List<int>.unmodifiable(row)]);
    final remaining = [for (final s in state.seats) if (!ranking.contains(s)) s];

    if (remaining.length <= 1) {
      ranking.addAll(remaining);
      return MoveResult(
        state: state.copyWith(
          steps: frozen,
          ranking: List.unmodifiable(ranking),
          phase: Phase.over,
          sixes: 0,
          turn: state.turn + 1,
        ),
        seat: seat,
        pawn: pawn,
        from: from,
        to: to,
        captures: captures,
        reachedHome: reachedHome,
        extraTurn: false,
        seatFinished: seatFinished,
      );
    }

    final extraTurn = !seatFinished &&
        (dice == 6 || captures.isNotEmpty || reachedHome);
    final afterMove = state.copyWith(
      steps: frozen,
      ranking: List.unmodifiable(ranking),
      turn: state.turn + 1,
    );

    final next = extraTurn
        ? afterMove.copyWith(phase: Phase.rolling)
        : afterMove.copyWith(
            current: nextSeat(afterMove, seat), phase: Phase.rolling, sixes: 0);

    return MoveResult(
      state: next,
      seat: seat,
      pawn: pawn,
      from: from,
      to: to,
      captures: captures,
      reachedHome: reachedHome,
      extraTurn: extraTurn,
      seatFinished: seatFinished,
    );
  }

  /// Le siège suivant [seat] qui joue encore.
  static int nextSeat(GameState state, int seat) {
    final order = state.seats;
    final start = order.indexOf(seat);
    for (var i = 1; i <= order.length; i++) {
      final candidate = order[(start + i) % order.length];
      if (!state.ranking.contains(candidate)) return candidate;
    }
    return seat;
  }

  /// Termine la partie tout de suite : les joueurs encore en jeu sont classés
  /// selon l'avancée de leurs pions (utile quand il ne reste que
  /// l'ordinateur).
  static GameState finishEarly(GameState state) {
    if (state.isOver) return state;
    int progress(int seat) => state.steps[seat]
        .fold<int>(0, (sum, s) => sum + (s < 0 ? 0 : s + 1));
    final remaining = state.playingSeats
      ..sort((a, b) {
        final byProgress = progress(b).compareTo(progress(a));
        if (byProgress != 0) return byProgress;
        return state.seats.indexOf(a).compareTo(state.seats.indexOf(b));
      });
    return state.copyWith(
      ranking: List.unmodifiable([...state.ranking, ...remaining]),
      phase: Phase.over,
      sixes: 0,
      turn: state.turn + 1,
    );
  }
}
