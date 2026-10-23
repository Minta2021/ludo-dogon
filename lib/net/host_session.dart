/// Session de l'hôte : salon d'attente puis arbitrage de la partie.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/ai.dart';
import '../game/board.dart';
import '../models/match.dart';
import 'links.dart';
import 'nearby_service.dart';

/// Un téléphone qui demande à entrer dans la partie.
class JoinRequest {
  const JoinRequest({required this.id, required this.name, required this.token});

  final String id;
  final String name;

  /// Code affiché sur les deux téléphones pour vérifier qu'il s'agit bien
  /// du bon joueur.
  final String token;
}

class HostSession extends ChangeNotifier implements HostLink {
  HostSession({required this.net, required this.hostName, required this.hostSeat});

  final NetService net;
  final String hostName;
  final int hostSeat;

  /// Joueurs installés, indexés par siège (null = place libre).
  final List<PlayerSlot?> _seats = List.filled(Board.seatCount, null);

  /// Demandes en attente d'acceptation par l'hôte.
  final Map<String, JoinRequest> _requests = {};

  /// Téléphones acceptés qui n'ont pas encore dit bonjour.
  final Map<String, String> _accepted = {};
  final Map<String, int> _seatOf = {};

  final StreamController<RemoteIntent> _intents = StreamController.broadcast();
  final StreamController<int> _seatLost = StreamController.broadcast();
  StreamSubscription<NetEvent>? _sub;

  bool _open = false;
  bool _started = false;
  bool _closed = false;
  String? error;

  bool get isOpen => _open;
  bool get started => _started;

  List<JoinRequest> get requests => List.unmodifiable(_requests.values);

  PlayerSlot? playerAt(int seat) => _seats[seat];

  List<PlayerSlot> get players => [for (final p in _seats) if (p != null) p];

  int get playerCount => players.length;

  bool get isFull => playerCount >= Board.seatCount;

  bool get canStart => playerCount >= 2;

  /// Téléphones acceptés qui se présentent encore.
  int get joiningCount => _accepted.length;

  /// Nombre de téléphones connectés (sans compter l'hôte).
  int get remoteCount => _seatOf.length;

  /// Ouvre la partie aux téléphones proches.
  Future<void> open() async {
    _seats[hostSeat] = PlayerSlot(seat: hostSeat, name: hostName, kind: PlayerKind.human);
    _sub ??= net.events.listen(_onNet);
    error = null;
    notifyListeners();
    try {
      await net.startHosting(hostName);
      _open = true;
    } on NetException catch (e) {
      error = e.message;
    }
    _notify();
  }

  Future<void> acceptRequest(String id) async {
    final req = _requests.remove(id);
    if (req == null) return;
    if (isFull) {
      await net.reject(id);
      _notify();
      return;
    }
    _accepted[id] = req.name;
    _notify();
    try {
      await net.accept(id);
    } on NetException catch (e) {
      _accepted.remove(id);
      error = e.message;
      _notify();
    }
  }

  Future<void> rejectRequest(String id) async {
    _requests.remove(id);
    _notify();
    await net.reject(id);
  }

  /// Ajoute l'ordinateur à une place libre.
  void addBot(int seat, {BotLevel level = BotLevel.normal}) {
    if (_seats[seat] != null || _started) return;
    _seats[seat] = PlayerSlot(
      seat: seat,
      name: botNames[seat],
      kind: PlayerKind.bot,
      botLevel: level,
    );
    _broadcastLobby();
    _notify();
  }

  /// Libère une place (ordinateur retiré ou joueur renvoyé).
  Future<void> freeSeat(int seat) async {
    final p = _seats[seat];
    if (p == null || seat == hostSeat || _started) return;
    _seats[seat] = null;
    final id = p.endpointId;
    if (id != null) {
      _seatOf.remove(id);
      net.send(id, {'t': 'deny', 'reason': 'L\'hôte t\'a retiré de la partie.'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await net.disconnect(id);
    }
    _broadcastLobby();
    _notify();
  }

  /// Ferme le salon et renvoie la configuration de la partie.
  MatchConfig start() {
    _started = true;
    unawaited(net.stopAdvertising());
    for (final id in _requests.keys) {
      unawaited(net.reject(id));
    }
    _requests.clear();
    _notify();
    return MatchConfig(players: players, mode: MatchMode.host, localSeat: hostSeat);
  }

  /// Termine la session : prévient les invités puis coupe le Bluetooth.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    broadcast({'t': 'bye'});
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _sub?.cancel();
    await net.shutdown();
    await _intents.close();
    await _seatLost.close();
  }

  // --- HostLink -------------------------------------------------------------

  @override
  void broadcast(Map<String, Object?> message) {
    for (final id in _seatOf.keys) {
      net.send(id, message);
    }
  }

  @override
  void sendToSeat(int seat, Map<String, Object?> message) {
    final id = _seats[seat]?.endpointId;
    if (id != null) net.send(id, message);
  }

  @override
  Stream<RemoteIntent> get intents => _intents.stream;

  @override
  Stream<int> get seatLost => _seatLost.stream;

  // --- Événements Bluetooth ---------------------------------------------

  void _onNet(NetEvent e) {
    if (_closed) return;
    switch (e) {
      case ConnectionRequested(:final id, :final name, :final token):
        if (_started || isFull) {
          unawaited(net.reject(id));
          return;
        }
        _requests[id] = JoinRequest(id: id, name: name, token: token);
        _notify();
      case PeerConnected():
        // On attend son message « hello » pour l'installer.
        break;
      case ConnectionFailed(:final id):
        _requests.remove(id);
        _accepted.remove(id);
        _notify();
      case PeerDisconnected(:final id):
        _requests.remove(id);
        _accepted.remove(id);
        final seat = _seatOf.remove(id);
        if (seat != null) {
          if (_started) {
            final p = _seats[seat];
            if (p != null) {
              _seats[seat] = PlayerSlot(
                seat: seat,
                name: p.name,
                kind: PlayerKind.bot,
              );
            }
            if (!_seatLost.isClosed) _seatLost.add(seat);
          } else {
            _seats[seat] = null;
            _broadcastLobby();
          }
        }
        _notify();
      case PeerMessage(:final id, :final data):
        _onMessage(id, data);
      case PeerFound():
      case PeerLost():
        break;
    }
  }

  void _onMessage(String id, Map<String, Object?> data) {
    final type = data['t'];
    if (type == 'hello') {
      _onHello(id, data);
      return;
    }
    final seat = _seatOf[id];
    if (seat == null || !_started || _intents.isClosed) return;
    switch (type) {
      case 'roll':
        _intents.add(RemoteIntent(seat: seat, action: 'roll'));
      case 'move':
        final pawn = (data['pawn'] as num?)?.toInt();
        if (pawn != null && pawn >= 0 && pawn < Board.pawnsPerPlayer) {
          _intents.add(RemoteIntent(seat: seat, action: 'move', pawn: pawn));
        }
      case 'sync':
        _intents.add(RemoteIntent(seat: seat, action: 'sync'));
    }
  }

  void _onHello(String id, Map<String, Object?> data) {
    final name = _cleanName(data['name'] as String? ?? _accepted[id] ?? 'Joueur');
    _accepted.remove(id);
    final version = (data['v'] as num?)?.toInt() ?? 0;
    if (version != protocolVersion) {
      _deny(id, 'Vos versions de Ludo Dogon sont différentes. Mettez le jeu à jour.');
      return;
    }
    if (_started) {
      _deny(id, 'La partie a déjà commencé.');
      return;
    }
    if (_seatOf.containsKey(id)) return;
    final wanted = (data['seat'] as num?)?.toInt();
    int? seat;
    if (wanted != null && wanted >= 0 && wanted < Board.seatCount && _seats[wanted] == null) {
      seat = wanted;
    } else {
      for (var s = 0; s < Board.seatCount; s++) {
        if (_seats[s] == null) {
          seat = s;
          break;
        }
      }
    }
    if (seat == null) {
      _deny(id, 'La partie est complète.');
      return;
    }
    _seats[seat] = PlayerSlot(seat: seat, name: name, kind: PlayerKind.remote, endpointId: id);
    _seatOf[id] = seat;
    net.send(id, {'t': 'welcome', 'seat': seat, 'players': _lobbyJson()});
    _broadcastLobby();
    _notify();
  }

  void _deny(String id, String reason) {
    net.send(id, {'t': 'deny', 'reason': reason});
    Future<void>.delayed(const Duration(milliseconds: 400), () => net.disconnect(id));
    _notify();
  }

  List<Map<String, Object?>> _lobbyJson() => [for (final p in players) p.toJson()];

  void _broadcastLobby() => broadcast({'t': 'lobby', 'players': _lobbyJson()});

  static String _cleanName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Joueur';
    return t.length > 16 ? t.substring(0, 16) : t;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }
}
