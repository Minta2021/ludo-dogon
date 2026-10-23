/// Couche Bluetooth : enveloppe le plugin nearby_connections et transforme
/// ses rappels en un flux d'événements simples.
///
/// La stratégie P2P_STAR convient au Ludo : un téléphone hôte au centre,
/// jusqu'à trois invités autour.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';

/// Identifiant du service : seuls les téléphones avec Ludo Dogon se voient.
const String kServiceId = 'com.bminformatix.ludodogon';

sealed class NetEvent {
  const NetEvent(this.id);

  /// Identifiant Bluetooth du téléphone concerné.
  final String id;
}

/// Une partie (hôte) a été trouvée à proximité.
class PeerFound extends NetEvent {
  const PeerFound(super.id, this.name);
  final String name;
}

/// Une partie n'est plus visible.
class PeerLost extends NetEvent {
  const PeerLost(super.id);
}

/// Une connexion démarre (demande reçue ou envoyée).
class ConnectionRequested extends NetEvent {
  const ConnectionRequested(super.id, this.name, this.token, this.incoming);
  final String name;

  /// Code identique sur les deux téléphones (vérification visuelle).
  final String token;
  final bool incoming;
}

class PeerConnected extends NetEvent {
  const PeerConnected(super.id);
}

class ConnectionFailed extends NetEvent {
  const ConnectionFailed(super.id, this.rejected);

  /// Vrai si l'autre téléphone a refusé (sinon : erreur de connexion).
  final bool rejected;
}

class PeerDisconnected extends NetEvent {
  const PeerDisconnected(super.id);
}

class PeerMessage extends NetEvent {
  const PeerMessage(super.id, this.data);
  final Map<String, Object?> data;
}

class NetException implements Exception {
  const NetException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetService {
  NetService({Nearby? nearby}) : _nearby = nearby ?? Nearby();

  final Nearby _nearby;
  final StreamController<NetEvent> _events = StreamController.broadcast();
  final Set<String> _connected = {};
  bool _closed = false;

  Stream<NetEvent> get events => _events.stream;

  Set<String> get connectedPeers => Set.unmodifiable(_connected);

  void _emit(NetEvent e) {
    if (!_closed) _events.add(e);
  }

  /// Rend la partie visible des téléphones proches.
  Future<void> startHosting(String name) async {
    await _guard(() async {
      await _quiet(_nearby.stopAdvertising);
      final ok = await _nearby.startAdvertising(
        name,
        Strategy.P2P_STAR,
        serviceId: kServiceId,
        onConnectionInitiated: (id, info) => _emit(ConnectionRequested(
            id, info.endpointName, info.authenticationToken, info.isIncomingConnection)),
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
      );
      if (!ok) throw const NetException('Impossible de rendre la partie visible.');
    });
  }

  /// Cherche les parties ouvertes à proximité.
  Future<void> startSearching(String name) async {
    await _guard(() async {
      await _quiet(_nearby.stopDiscovery);
      final ok = await _nearby.startDiscovery(
        name,
        Strategy.P2P_STAR,
        serviceId: kServiceId,
        onEndpointFound: (id, endpointName, serviceId) => _emit(PeerFound(id, endpointName)),
        onEndpointLost: (id) {
          if (id != null) _emit(PeerLost(id));
        },
      );
      if (!ok) throw const NetException('Impossible de chercher les parties proches.');
    });
  }

  /// Demande à rejoindre la partie [id].
  Future<void> requestConnection(String myName, String id) async {
    await _guard(() async {
      final ok = await _nearby.requestConnection(
        myName,
        id,
        onConnectionInitiated: (id, info) => _emit(ConnectionRequested(
            id, info.endpointName, info.authenticationToken, info.isIncomingConnection)),
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
      );
      if (!ok) throw const NetException('La demande de connexion a échoué.');
    });
  }

  Future<void> accept(String id) async {
    await _guard(() => _nearby.acceptConnection(id, onPayLoadRecieved: _onPayload));
  }

  Future<void> reject(String id) => _quiet(() => _nearby.rejectConnection(id));

  Future<void> stopAdvertising() => _quiet(_nearby.stopAdvertising);

  Future<void> stopSearching() => _quiet(_nearby.stopDiscovery);

  Future<void> disconnect(String id) async {
    _connected.remove(id);
    await _quiet(() => _nearby.disconnectFromEndpoint(id));
  }

  /// Envoie un message JSON (petit : moins de 32 Ko).
  void send(String id, Map<String, Object?> message) {
    if (!_connected.contains(id)) return;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(message)));
    _nearby.sendBytesPayload(id, bytes).catchError((Object e) {
      debugPrint('Envoi vers $id impossible : $e');
    });
  }

  /// Arrête tout : visibilité, recherche et connexions.
  Future<void> shutdown() async {
    await _quiet(_nearby.stopAdvertising);
    await _quiet(_nearby.stopDiscovery);
    await _quiet(_nearby.stopAllEndpoints);
    _connected.clear();
  }

  Future<void> dispose() async {
    await shutdown();
    _closed = true;
    await _events.close();
  }

  void _onResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _connected.add(id);
      _emit(PeerConnected(id));
    } else {
      _emit(ConnectionFailed(id, status == Status.REJECTED));
    }
  }

  void _onDisconnected(String id) {
    _connected.remove(id);
    _emit(PeerDisconnected(id));
  }

  void _onPayload(String id, Payload payload) {
    final bytes = payload.bytes;
    if (payload.type != PayloadType.BYTES || bytes == null) return;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) _emit(PeerMessage(id, decoded.cast<String, Object?>()));
    } on Object catch (e) {
      debugPrint('Message illisible de $id : $e');
    }
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      debugPrint('Nearby : $e');
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      throw NetException(describeError(e));
    } on MissingPluginException {
      throw const NetException(
          'Le Bluetooth n\'est disponible que sur un téléphone Android.');
    }
  }

  /// Traduit les erreurs de Nearby Connections en phrases claires.
  static String describeError(PlatformException e) {
    final text = '${e.code} ${e.message ?? ''}'.toUpperCase();
    if (text.contains('MISSING_PERMISSION') || text.contains('PERMISSION')) {
      return 'Autorisation manquante : autorise « Appareils à proximité » '
          'et la localisation pour Ludo Dogon dans les réglages.';
    }
    if (text.contains('BLUETOOTH')) {
      return 'Active le Bluetooth puis réessaie.';
    }
    if (text.contains('ALREADY')) {
      return 'Une recherche est déjà en cours. Réessaie dans un instant.';
    }
    if (text.contains('8007') || text.contains('RADIO')) {
      return 'Le Bluetooth ou le Wi-Fi est indisponible. Vérifie qu\'ils '
          'sont activés et que le mode avion est coupé.';
    }
    if (text.contains('API_UNAVAILABLE') || text.contains('SERVICE')) {
      return 'Les services Google Play sont nécessaires pour jouer en Bluetooth.';
    }
    return 'Erreur Bluetooth : ${e.message ?? e.code}';
  }
}
