/// Couche Bluetooth : enveloppe le plugin nearby_connections et transforme
/// ses rappels en un flux d'événements simples. Chaque étape est notée dans
/// le journal (NetLog) pour le diagnostic.
///
/// La stratégie P2P_STAR convient au Ludo : un téléphone hôte au centre,
/// jusqu'à trois invités autour.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'net_log.dart';

/// Identifiant du service : seuls les téléphones avec Ludo Dogon se voient.
const String kServiceId = 'com.bminformatix.ludodogon';

/// Service séparé pour le test du diagnostic (n'apparaît pas dans les parties).
const String kTestServiceId = 'com.bminformatix.ludodogon.test';

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
  const ConnectionFailed(super.id, this.rejected, this.code);

  /// Vrai si l'autre téléphone a refusé (sinon : erreur de connexion).
  final bool rejected;

  /// Code Nearby brut, s'il est connu.
  final int? code;
}

class PeerDisconnected extends NetEvent {
  const PeerDisconnected(super.id);
}

class PeerMessage extends NetEvent {
  const PeerMessage(super.id, this.data);
  final Map<String, Object?> data;
}

class NetException implements Exception {
  const NetException(this.message, {this.code});
  final String message;

  /// Code Nearby (ex. 8012), s'il est connu.
  final int? code;

  /// Erreur passagère : un nouvel essai a des chances de réussir.
  bool get retryable => code == null || const {13, 8007, 8011, 8012, 8013}.contains(code);

  @override
  String toString() => message;
}

class NetService {
  NetService({Nearby? nearby}) : _nearby = nearby ?? Nearby();

  final Nearby _nearby;
  final StreamController<NetEvent> _events = StreamController.broadcast();
  final Set<String> _connected = {};
  final Map<String, String> _names = {};
  bool _closed = false;

  Stream<NetEvent> get events => _events.stream;

  Set<String> get connectedPeers => Set.unmodifiable(_connected);

  void _emit(NetEvent e) {
    if (!_closed) _events.add(e);
  }

  String _who(String id) => _names[id] ?? id;

  /// Rend la partie visible des téléphones proches.
  Future<void> startHosting(String name, {String serviceId = kServiceId}) async {
    netLog('Rendre visible « $name »…');
    await _guard('Visibilité', () async {
      await _quiet(_nearby.stopAdvertising);
      final ok = await _nearby.startAdvertising(
        name,
        Strategy.P2P_STAR,
        serviceId: serviceId,
        onConnectionInitiated: _onInitiated,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
      );
      if (!ok) throw const NetException('Impossible de rendre la partie visible.');
    });
    netLog('Visible : les autres téléphones peuvent trouver « $name ».');
  }

  /// Cherche les parties ouvertes à proximité.
  Future<void> startSearching(String name, {String serviceId = kServiceId}) async {
    netLog('Recherche des téléphones proches…');
    await _guard('Recherche', () async {
      await _quiet(_nearby.stopDiscovery);
      final ok = await _nearby.startDiscovery(
        name,
        Strategy.P2P_STAR,
        serviceId: serviceId,
        onEndpointFound: (id, endpointName, serviceId) {
          _names[id] = endpointName;
          netLog('Trouvé : « $endpointName ».');
          _emit(PeerFound(id, endpointName));
        },
        onEndpointLost: (id) {
          if (id == null) return;
          netLog('Perdu de vue : « ${_who(id)} ».');
          _emit(PeerLost(id));
        },
      );
      if (!ok) throw const NetException('Impossible de chercher les parties proches.');
    });
    netLog('Recherche lancée.');
  }

  /// Demande à rejoindre la partie [id].
  Future<void> requestConnection(String myName, String id) async {
    netLog('Demande de connexion à « ${_who(id)} »…');
    await _guard('Demande de connexion', () async {
      final ok = await _nearby.requestConnection(
        myName,
        id,
        onConnectionInitiated: _onInitiated,
        onConnectionResult: _onResult,
        onDisconnected: _onDisconnected,
      );
      if (!ok) throw const NetException('La demande de connexion a échoué.');
    });
  }

  Future<void> accept(String id) async {
    netLog('Accepte la connexion avec « ${_who(id)} ».');
    await _guard('Acceptation', () => _nearby.acceptConnection(id, onPayLoadRecieved: _onPayload));
  }

  Future<void> reject(String id) {
    netLog('Refuse « ${_who(id)} ».');
    return _quiet(() => _nearby.rejectConnection(id));
  }

  Future<void> stopAdvertising() => _quiet(_nearby.stopAdvertising);

  Future<void> stopSearching() => _quiet(_nearby.stopDiscovery);

  Future<void> disconnect(String id) async {
    _connected.remove(id);
    await _quiet(() => _nearby.disconnectFromEndpoint(id));
  }

  /// Envoie un message JSON (petit : moins de 32 Ko).
  void send(String id, Map<String, Object?> message) {
    if (!_connected.contains(id)) {
      netLog('Message « ${message['t']} » non envoyé : « ${_who(id)} » n\'est pas connecté.');
      return;
    }
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(message)));
    _nearby.sendBytesPayload(id, bytes).catchError((Object e) {
      netLog('Envoi vers « ${_who(id)} » impossible : ${_describe(e)}');
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

  void _onInitiated(String id, ConnectionInfo info) {
    _names[id] = info.endpointName;
    netLog('Connexion en cours avec « ${info.endpointName} » (code ${info.authenticationToken}).');
    _emit(ConnectionRequested(id, info.endpointName, info.authenticationToken, info.isIncomingConnection));
  }

  void _onResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _connected.add(id);
      netLog('Connecté à « ${_who(id)} ».');
      _emit(PeerConnected(id));
    } else {
      final raw = _nearby.lastRawStatus;
      netLog('Connexion avec « ${_who(id)} » : ${status == Status.REJECTED ? 'refusée' : 'échec'}'
          '${raw != null ? ' (code $raw)' : ''}.');
      _emit(ConnectionFailed(id, status == Status.REJECTED, raw));
    }
  }

  void _onDisconnected(String id) {
    _connected.remove(id);
    netLog('Déconnecté de « ${_who(id)} ».');
    _emit(PeerDisconnected(id));
  }

  void _onPayload(String id, Payload payload) {
    // Un message reçu prouve que la connexion est établie, même si l'avis
    // « connecté » n'est pas encore arrivé : on peut répondre tout de suite.
    _connected.add(id);
    final bytes = payload.bytes;
    if (payload.type != PayloadType.BYTES || bytes == null) return;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) {
        final data = decoded.cast<String, Object?>();
        if (data['t'] != 'ev') netLog('Reçu « ${data['t']} » de « ${_who(id)} ».');
        _emit(PeerMessage(id, data));
      }
    } on Object catch (e) {
      netLog('Message illisible de « ${_who(id)} » : $e');
    }
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      debugPrint('Nearby : $e');
    }
  }

  Future<void> _guard(String step, Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      final ex = fromPlatform(e);
      netLog('$step : ÉCHEC — ${ex.message}');
      throw ex;
    } on MissingPluginException {
      const ex = NetException('Le Bluetooth n\'est disponible que sur un téléphone Android.');
      netLog('$step : ÉCHEC — ${ex.message}');
      throw ex;
    } on NetException catch (e) {
      netLog('$step : ÉCHEC — ${e.message}');
      rethrow;
    }
  }

  static String _describe(Object e) =>
      e is PlatformException ? fromPlatform(e).message : e.toString();

  /// Code Nearby contenu dans l'erreur (« 8034 » ou « 8034: MISSING_… »).
  static int? codeOf(PlatformException e) {
    final direct = int.tryParse(e.code);
    if (direct != null) return direct;
    final m = RegExp(r'(\d{1,5})\s*:').firstMatch(e.message ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Traduit les erreurs de Nearby Connections en phrases claires, avec le
  /// code pour le diagnostic.
  static NetException fromPlatform(PlatformException e) {
    final code = codeOf(e);
    final text = '${e.code} ${e.message ?? ''}'.toUpperCase();
    String msg;
    if (code != null && code >= 8030 && code <= 8040) {
      const names = {
        8030: 'Bluetooth',
        8031: 'Bluetooth',
        8032: 'Wi-Fi',
        8033: 'Wi-Fi',
        8034: 'Localisation',
        8035: 'Micro',
        8036: 'Localisation précise',
        8037: 'Bluetooth (recherche)',
        8038: 'Bluetooth (visibilité)',
        8039: 'Bluetooth (connexion)',
        8040: 'Appareils Wi-Fi à proximité',
      };
      msg = 'Autorisation manquante : ${names[code]}. Autorise-la pour Ludo Dogon '
          'dans les réglages du téléphone.';
    } else if (text.contains('PERMISSION')) {
      msg = 'Autorisation manquante : autorise « Appareils à proximité » et la '
          'localisation pour Ludo Dogon dans les réglages.';
    } else {
      switch (code) {
        case 8001:
        case 8002:
          msg = 'Une recherche ou une partie est déjà en cours. Réessaie dans un instant.';
        case 8003:
          msg = 'Ce téléphone est déjà connecté à cette partie.';
        case 8004:
          msg = 'La connexion a été refusée.';
        case 8007:
          msg = 'Le Bluetooth ou le Wi-Fi ne répond pas. Vérifie qu\'ils sont activés, '
              'coupe le mode avion, puis réessaie.';
        case 8009:
          msg = 'Action Bluetooth faite dans le mauvais ordre. Réessaie.';
        case 8011:
          msg = 'Ce téléphone n\'est plus visible. Relance la recherche.';
        case 8012:
          msg = 'La connexion a été coupée en route. Rapproche les téléphones et réessaie.';
        case 8013:
          msg = 'Le téléphone n\'est pas connecté.';
        case 1:
        case 2:
        case 3:
        case 9:
          msg = 'Les services Google Play sont absents, désactivés ou trop anciens. '
              'Mets-les à jour depuis le Play Store.';
        case 17:
          msg = 'Les services Google Play ne répondent pas. Redémarre le téléphone.';
        default:
          msg = 'Erreur Bluetooth : ${e.message ?? e.code}';
      }
    }
    if (code != null) msg = '$msg (code $code)';
    return NetException(msg, code: code);
  }
}
