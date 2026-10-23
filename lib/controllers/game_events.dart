/// Événements de partie : produits par l'arbitre (ce téléphone en local,
/// ou l'hôte en Bluetooth), puis rejoués à l'écran sur chaque téléphone.
library;

import '../game/rules.dart';

sealed class GameEvent {
  const GameEvent({required this.seat, required this.state});

  /// Joueur qui a agi.
  final int seat;

  /// État de la partie après l'événement.
  final GameState state;

  Map<String, Object?> toJson();

  static GameEvent fromJson(Map<String, Object?> json) {
    final state = GameState.fromJson((json['state'] as Map).cast<String, Object?>());
    final seat = (json['seat'] as num).toInt();
    switch (json['k']) {
      case 'roll':
        return RollEvent(
          seat: seat,
          value: (json['value'] as num).toInt(),
          end: RollEnd.values.byName(json['end'] as String),
          state: state,
        );
      case 'move':
        return MoveEvent(
          seat: seat,
          pawn: (json['pawn'] as num).toInt(),
          from: (json['from'] as num).toInt(),
          to: (json['to'] as num).toInt(),
          captures: [
            for (final c in (json['captures'] as List? ?? const []))
              Capture(
                seat: ((c as Map)['seat'] as num).toInt(),
                pawn: (c['pawn'] as num).toInt(),
                from: (c['from'] as num).toInt(),
              ),
          ],
          reachedHome: json['home'] == true,
          extraTurn: json['extra'] == true,
          seatFinished: json['finished'] == true,
          state: state,
        );
      case 'end':
        return EndEvent(seat: seat, state: state);
      default:
        throw FormatException('Événement inconnu : ${json['k']}');
    }
  }
}

class RollEvent extends GameEvent {
  const RollEvent({
    required super.seat,
    required this.value,
    required this.end,
    required super.state,
  });

  final int value;
  final RollEnd end;

  @override
  Map<String, Object?> toJson() => {
        'k': 'roll',
        'seat': seat,
        'value': value,
        'end': end.name,
        'state': state.toJson(),
      };
}

class MoveEvent extends GameEvent {
  const MoveEvent({
    required super.seat,
    required this.pawn,
    required this.from,
    required this.to,
    required this.captures,
    required this.reachedHome,
    required this.extraTurn,
    required this.seatFinished,
    required super.state,
  });

  factory MoveEvent.fromResult(MoveResult r) => MoveEvent(
        seat: r.seat,
        pawn: r.pawn,
        from: r.from,
        to: r.to,
        captures: r.captures,
        reachedHome: r.reachedHome,
        extraTurn: r.extraTurn,
        seatFinished: r.seatFinished,
        state: r.state,
      );

  final int pawn;
  final int from;
  final int to;
  final List<Capture> captures;
  final bool reachedHome;
  final bool extraTurn;
  final bool seatFinished;

  /// Étapes à afficher une à une.
  List<int> get path =>
      from < 0 ? const [0] : [for (var s = from + 1; s <= to; s++) s];

  @override
  Map<String, Object?> toJson() => {
        'k': 'move',
        'seat': seat,
        'pawn': pawn,
        'from': from,
        'to': to,
        'captures': [
          for (final c in captures) {'seat': c.seat, 'pawn': c.pawn, 'from': c.from},
        ],
        'home': reachedHome,
        'extra': extraTurn,
        'finished': seatFinished,
        'state': state.toJson(),
      };
}

/// Fin anticipée : il ne reste que l'ordinateur en jeu.
class EndEvent extends GameEvent {
  const EndEvent({required super.seat, required super.state});

  @override
  Map<String, Object?> toJson() => {'k': 'end', 'seat': seat, 'state': state.toJson()};
}
