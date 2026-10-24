/// Interfaces entre la partie et le réseau Bluetooth.
///
/// L'hôte est l'arbitre : il lance les dés, applique les règles et diffuse
/// chaque événement. Les invités envoient seulement leurs intentions
/// (« je lance », « je joue tel pion »).
library;

/// Version du protocole échangé entre téléphones.
const int protocolVersion = 2;

/// Intention envoyée par un invité.
class RemoteIntent {
  const RemoteIntent({required this.seat, required this.action, this.pawn});

  final int seat;

  /// 'roll', 'move' ou 'sync'.
  final String action;
  final int? pawn;
}

/// Côté hôte, vu depuis la partie.
abstract interface class HostLink {
  /// Envoie un message à tous les invités.
  void broadcast(Map<String, Object?> message);

  /// Envoie un message au téléphone qui joue [seat].
  void sendToSeat(int seat, Map<String, Object?> message);

  /// Intentions des invités.
  Stream<RemoteIntent> get intents;

  /// Sièges dont le téléphone s'est déconnecté.
  Stream<int> get seatLost;
}

/// Côté invité, vu depuis la partie.
abstract interface class ClientLink {
  /// Envoie un message à l'hôte.
  void send(Map<String, Object?> message);

  /// Messages reçus de l'hôte.
  Stream<Map<String, Object?>> get messages;

  /// Émet une fois si la connexion avec l'hôte est perdue.
  Stream<String> get lost;
}
