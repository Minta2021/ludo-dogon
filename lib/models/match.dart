/// Configuration d'une partie : qui joue, à quel siège, et comment.
library;

import '../game/ai.dart';

/// Prénoms donnés à l'ordinateur selon le masque (siège).
const List<String> botNames = ['Amadou', 'Awa', 'Seydou', 'Fatoumata'];

/// Qui contrôle un siège.
enum PlayerKind {
  /// Un joueur sur ce téléphone.
  human,

  /// L'ordinateur (calculé sur ce téléphone, ou sur celui de l'hôte).
  bot,

  /// Un joueur sur un autre téléphone, connecté en Bluetooth.
  remote,
}

/// Comment ce téléphone participe à la partie.
enum MatchMode {
  /// Tout se joue sur ce téléphone (seul contre l'ordinateur ou à plusieurs).
  local,

  /// Ce téléphone héberge la partie Bluetooth et arbitre les coups.
  host,

  /// Ce téléphone a rejoint la partie d'un autre.
  client,
}

class PlayerSlot {
  const PlayerSlot({
    required this.seat,
    required this.name,
    required this.kind,
    this.botLevel = BotLevel.normal,
    this.endpointId,
  });

  final int seat;
  final String name;
  final PlayerKind kind;
  final BotLevel botLevel;

  /// Identifiant Bluetooth du téléphone du joueur (côté hôte seulement).
  final String? endpointId;

  PlayerSlot copyWith({String? name, PlayerKind? kind, BotLevel? botLevel}) =>
      PlayerSlot(
        seat: seat,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        botLevel: botLevel ?? this.botLevel,
        endpointId: endpointId,
      );

  /// Version envoyée aux autres téléphones. Le genre est donné du point de
  /// vue de l'hôte ; chaque invité recalcule le sien à la réception.
  Map<String, Object?> toJson() => {
        'seat': seat,
        'name': name,
        'kind': kind.name,
        'level': botLevel.name,
      };

  factory PlayerSlot.fromJson(Map<String, Object?> json) => PlayerSlot(
        seat: (json['seat'] as num).toInt(),
        name: json['name'] as String? ?? 'Joueur',
        kind: PlayerKind.values.byName(json['kind'] as String? ?? 'remote'),
        botLevel: BotLevel.values.byName(json['level'] as String? ?? 'normal'),
      );
}

class MatchConfig {
  MatchConfig({
    required List<PlayerSlot> players,
    required this.mode,
    this.localSeat,
  }) : players = List.unmodifiable([...players]..sort((a, b) => a.seat - b.seat));

  final List<PlayerSlot> players;
  final MatchMode mode;

  /// En Bluetooth : le siège de ce téléphone. En local : null.
  final int? localSeat;

  List<int> get seats => [for (final p in players) p.seat];

  PlayerSlot? player(int seat) {
    for (final p in players) {
      if (p.seat == seat) return p;
    }
    return null;
  }

  String nameOf(int seat) => player(seat)?.name ?? 'Joueur';

  bool isBot(int seat) => player(seat)?.kind == PlayerKind.bot;

  /// Vrai si ce téléphone doit jouer pour ce siège quand c'est son tour.
  bool isLocalHuman(int seat) {
    switch (mode) {
      case MatchMode.local:
        return player(seat)?.kind == PlayerKind.human;
      case MatchMode.host:
      case MatchMode.client:
        return seat == localSeat;
    }
  }

  bool get hasSeveralLocalHumans =>
      mode == MatchMode.local &&
      players.where((p) => p.kind == PlayerKind.human).length > 1;

  MatchConfig replacePlayer(PlayerSlot slot) => MatchConfig(
        players: [for (final p in players) p.seat == slot.seat ? slot : p],
        mode: mode,
        localSeat: localSeat,
      );
}
