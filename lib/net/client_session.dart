/// Session d'un invité : recherche des parties, connexion, salon puis partie.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/rules.dart';
import '../models/match.dart';
import 'links.dart';
import 'nearby_service.dart';

enum ClientStatus {
  idle,
  searching,
  connecting,
  inLobby,
  started,
  failed,
}

/// Une partie visible à proximité.
class FoundGame {
  const FoundGame({required this.id, required this.hostName});
  final String id;
  final String hostName;
}

class ClientSession extends ChangeNotifier implements ClientLink {
  ClientSession({required this.net, required this.myName, required this.preferredSeat});

  final NetService net;
  final String myName;
  final int preferredSeat;

  final Map<String, FoundGame> _found = {};
  StreamSubscription<NetEvent>? _sub;

  ClientStatus status = ClientStatus.idle;
  String? error;

  /// Code de vérification affiché pendant la connexion.
  String? token;

  String? _hostId;
  String? hostName;
  int? mySeat;
  List<PlayerSlot> lobby = const [];

  /// Message « start » reçu : de quoi créer la partie.
  MatchConfig? startConfig;
  GameState? startState;

  // Les messages de jeu sont mis en attente jusqu'à ce que la partie écoute.
  final StreamController<Map<String, Object?>> _game = StreamController();
  final StreamController<String> _lost = StreamController();
  bool _closed = false;

  List<FoundGame> get games => List.unmodifiable(_found.values);

  Future<void> startSearch() async {
    _sub ??= net.events.listen(_onNet);
    error = null;
    status = ClientStatus.searching;
    _notify();
    try {
      await net.startSearching(myName);
    } on NetException catch (e) {
      error = e.message;
      status = ClientStatus.failed;
      _notify();
    }
  }

  Future<void> join(FoundGame game) async {
    if (status == ClientStatus.connecting || status == ClientStatus.inLobby) return;
    status = ClientStatus.connecting;
    hostName = game.hostName;
    _hostId = game.id;
    error = null;
    token = null;
    _notify();
    try {
      await net.requestConnection(myName, game.id);
    } on NetException catch (e) {
      _fail(e.message);
    }
  }

  /// Revient à la liste des parties après un échec ou un refus.
  Future<void> backToSearch() async {
    final id = _hostId;
    _hostId = null;
    mySeat = null;
    lobby = const [];
    if (id != null) await net.disconnect(id);
    await startSearch();
  }

  void _fail(String message) {
    error = message;
    status = ClientStatus.failed;
    _notify();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    await net.shutdown();
    await _game.close();
    await _lost.close();
  }

  // --- ClientLink ------------------------------------------------------------

  @override
  void send(Map<String, Object?> message) {
    final id = _hostId;
    if (id != null) net.send(id, message);
  }

  @override
  Stream<Map<String, Object?>> get messages => _game.stream;

  @override
  Stream<String> get lost => _lost.stream;

  // --- Événements Bluetooth ---------------------------------------------

  void _onNet(NetEvent e) {
    if (_closed) return;
    switch (e) {
      case PeerFound(:final id, :final name):
        _found[id] = FoundGame(id: id, hostName: name);
        _notify();
      case PeerLost(:final id):
        if (_found.remove(id) != null) _notify();
      case ConnectionRequested(:final id, token: final code):
        if (id != _hostId) {
          unawaited(net.reject(id));
          return;
        }
        token = code;
        _notify();
        // L'invité accepte de son côté ; l'hôte doit aussi accepter.
        unawaited(net.accept(id).catchError((Object err) {
          _fail('$err');
        }));
      case PeerConnected(:final id):
        if (id != _hostId) return;
        unawaited(net.stopSearching());
        net.send(id, {
          't': 'hello',
          'name': myName,
          'seat': preferredSeat,
          'v': protocolVersion,
        });
      case ConnectionFailed(:final id, :final rejected):
        if (id != _hostId) return;
        _hostId = null;
        _fail(rejected
            ? 'L\'hôte a refusé ta demande.'
            : 'La connexion a échoué. Rapproche les téléphones et réessaie.');
      case PeerDisconnected(:final id):
        if (id != _hostId) return;
        if (status == ClientStatus.started) {
          if (!_lost.isClosed) _lost.add('La connexion avec l\'hôte est perdue.');
        } else if (status != ClientStatus.failed) {
          _fail('La connexion avec l\'hôte est perdue.');
        }
        _hostId = null;
      case PeerMessage(:final id, :final data):
        if (id == _hostId) _onMessage(data);
    }
  }

  void _onMessage(Map<String, Object?> data) {
    switch (data['t']) {
      case 'welcome':
        mySeat = (data['seat'] as num?)?.toInt();
        lobby = _players(data['players']);
        status = ClientStatus.inLobby;
        _notify();
      case 'lobby':
        lobby = _players(data['players']);
        _notify();
      case 'deny':
        _fail(data['reason'] as String? ?? 'L\'hôte a refusé ta demande.');
      case 'start':
        if (status == ClientStatus.started) {
          // Nouvelle partie pendant le jeu : transmise au contrôleur.
          if (!_game.isClosed) _game.add(data);
          return;
        }
        try {
          final seat = mySeat;
          if (seat == null) return;
          startState = GameState.fromJson((data['state'] as Map).cast<String, Object?>());
          final players = _players(data['players']);
          startConfig = MatchConfig(
            players: [
              for (final p in players)
                p.seat == seat
                    ? p.copyWith(kind: PlayerKind.human)
                    : (p.kind == PlayerKind.bot ? p : p.copyWith(kind: PlayerKind.remote)),
            ],
            mode: MatchMode.client,
            localSeat: seat,
          );
          status = ClientStatus.started;
          _notify();
        } on Object catch (e) {
          debugPrint('Début de partie illisible : $e');
          send({'t': 'sync'});
        }
      default:
        // Événements de jeu (ev, sync, seat, bye) : pour le contrôleur.
        if (status == ClientStatus.started && !_game.isClosed) _game.add(data);
        if (data['t'] == 'bye' && status != ClientStatus.started) {
          _fail('L\'hôte a fermé la partie.');
        }
    }
  }

  List<PlayerSlot> _players(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final p in raw) PlayerSlot.fromJson((p as Map).cast<String, Object?>()),
    ]..sort((a, b) => a.seat - b.seat);
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }
}
