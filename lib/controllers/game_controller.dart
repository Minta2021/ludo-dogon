/// Pilote une partie : arbitrage (en local ou sur l'hôte), tours de
/// l'ordinateur, animations et synchronisation Bluetooth.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/ai.dart';
import '../game/board.dart';
import '../game/rules.dart';
import '../models/match.dart';
import '../net/links.dart';
import 'game_events.dart';

/// Ton du message affiché sous le plateau.
enum MessageTone { neutral, good, bad }

/// Durées des animations et des pauses.
abstract final class GameTiming {
  static const roll = Duration(milliseconds: 650);
  static const hop = Duration(milliseconds: 150);
  static const exitBase = Duration(milliseconds: 300);
  static const afterMove = Duration(milliseconds: 220);
  static const afterCapture = Duration(milliseconds: 520);
  static const noMovePause = Duration(milliseconds: 1000);
  static const botRoll = Duration(milliseconds: 700);
  static const botMove = Duration(milliseconds: 500);
  static const autoMove = Duration(milliseconds: 380);
  static const remoteTimeout = Duration(seconds: 30);
  static const hostAnswer = Duration(seconds: 6);
}

class GameController extends ChangeNotifier {
  GameController({
    required MatchConfig config,
    this.hostLink,
    this.clientLink,
    GameState? initialState,
    math.Random? random,
  })  : _config = config,
        _rng = random ?? math.Random(),
        _state = initialState ?? _freshState(config, random ?? math.Random()) {
    _auth = _state;
    final host = hostLink;
    if (host != null) {
      _subs.add(host.intents.listen(_onRemoteIntent));
      _subs.add(host.seatLost.listen(_onSeatLost));
    }
    final client = clientLink;
    if (client != null) {
      _subs.add(client.messages.listen(_onHostMessage));
      _subs.add(client.lost.listen(_onHostLost));
    }
    scheduleMicrotask(_pump);
  }

  static GameState _freshState(MatchConfig config, math.Random rng) {
    final s = GameState.initial(config.seats);
    // Le premier joueur est tiré au sort.
    return s.copyWith(current: s.seats[rng.nextInt(s.seats.length)]);
  }

  final HostLink? hostLink;
  final ClientLink? clientLink;
  final math.Random _rng;
  final List<StreamSubscription<Object?>> _subs = [];

  MatchConfig _config;
  MatchConfig get config => _config;

  /// État affiché (mis à jour à la fin de chaque animation).
  GameState _state;
  GameState get state => _state;

  /// État de l'arbitre (en avance sur l'affichage pendant les animations).
  late GameState _auth;

  final Queue<GameEvent> _queue = Queue();
  bool _playing = false;
  bool _disposed = false;
  bool _paused = false;
  bool _awaitingHost = false;

  /// Change à chaque nouvelle partie : les animations en cours s'arrêtent.
  int _epoch = 0;
  Timer? _actionTimer;
  Timer? _hostAnswerTimer;

  // --- Affichage -----------------------------------------------------------

  bool diceRolling = false;
  int? get diceFace => _diceFace ?? _state.dice;
  int? _diceFace;

  final Map<int, int> _stepOverride = {};

  /// Pion en train de sauter de case en case (siège * 4 + pion).
  int? hoppingKey;

  /// Dernier événement marquant (capture, six, arrivée...).
  String eventText = '';
  MessageTone eventTone = MessageTone.neutral;

  /// Renseigné si la connexion avec l'hôte est perdue.
  String? connectionLost;

  /// Incrémenté à chaque nouvelle partie (permet de fermer le classement).
  int gameNumber = 0;

  bool get isAuthority => clientLink == null;

  int displayStep(int seat, int pawn) =>
      _stepOverride[seat * 4 + pawn] ?? _state.steps[seat][pawn];

  String nameOf(int seat) => _config.nameOf(seat);

  /// Vrai quand ce téléphone doit jouer pour le joueur courant.
  bool get isLocalTurn => !_state.isOver && _config.isLocalHuman(_state.current);

  bool get busy => _playing || _queue.isNotEmpty || _awaitingHost;

  bool get canRoll =>
      isLocalTurn && _state.phase == Phase.rolling && !busy && connectionLost == null;

  List<int> get movablePawns {
    if (!isLocalTurn || _state.phase != Phase.moving || busy) return const [];
    return Rules.currentLegalPawns(_state);
  }

  /// Phrase principale : à qui de jouer.
  String get turnText {
    final s = _state;
    if (s.isOver) return 'Partie terminée';
    final name = nameOf(s.current);
    final player = _config.player(s.current);
    if (isLocalTurn) {
      final who = _config.hasSeveralLocalHumans ? '$name, à toi' : 'À toi';
      if (s.phase == Phase.rolling) return '$who : lance le dé';
      return busy ? '$who de jouer' : '$who : choisis un pion';
    }
    if (player?.kind == PlayerKind.bot) return '$name réfléchit…';
    return 'Au tour de $name';
  }

  // --- Actions de ce téléphone -------------------------------------------

  void roll() {
    if (!canRoll) return;
    HapticFeedback.selectionClick();
    if (isAuthority) {
      _authorityRoll(_auth.turn);
    } else {
      _askHost({'t': 'roll'});
    }
  }

  void movePawn(int pawn) {
    if (!movablePawns.contains(pawn)) return;
    HapticFeedback.selectionClick();
    if (isAuthority) {
      _authorityMove(pawn, _auth.turn);
    } else {
      _askHost({'t': 'move', 'pawn': pawn});
    }
  }

  /// Met en pause l'ordinateur (partie locale uniquement).
  void setPaused(bool paused) {
    if (_config.mode != MatchMode.local) return;
    _paused = paused;
    if (paused) {
      _cancelTimers();
    } else {
      _pump();
    }
  }

  /// Nouvelle partie avec les mêmes joueurs (local ou hôte).
  void restart() {
    if (!isAuthority) return;
    final fresh = _freshState(_config, _rng);
    hostLink?.broadcast({
      't': 'start',
      'players': [for (final p in _config.players) p.toJson()],
      'state': fresh.toJson(),
    });
    _reset(fresh);
  }

  void _reset(GameState fresh) {
    _epoch++;
    _cancelTimers();
    _queue.clear();
    _stepOverride.clear();
    hoppingKey = null;
    diceRolling = false;
    _diceFace = null;
    _awaitingHost = false;
    _state = fresh;
    _auth = fresh;
    eventText = '';
    eventTone = MessageTone.neutral;
    gameNumber++;
    _notify();
    _pump();
  }

  // --- Arbitrage -----------------------------------------------------------

  void _authorityRoll(int expectedTurn) {
    if (_auth.turn != expectedTurn || _auth.phase != Phase.rolling) return;
    final value = 1 + _rng.nextInt(6);
    final seat = _auth.current;
    final result = Rules.roll(_auth, value);
    _auth = result.state;
    _emit(RollEvent(seat: seat, value: value, end: result.end, state: result.state));
  }

  void _authorityMove(int pawn, int expectedTurn) {
    if (_auth.turn != expectedTurn || _auth.phase != Phase.moving) return;
    if (!Rules.currentLegalPawns(_auth).contains(pawn)) return;
    final result = Rules.move(_auth, pawn);
    _auth = result.state;
    _emit(MoveEvent.fromResult(result));
  }

  void _emit(GameEvent event) {
    _cancelTimers();
    hostLink?.broadcast({'t': 'ev', 'e': event.toJson()});
    _enqueue(event);
  }

  /// Programme l'action automatique suivante (ordinateur, coup unique,
  /// joueur distant trop lent).
  void _pump() {
    if (_disposed || !isAuthority || _paused || _playing || _queue.isNotEmpty) {
      return;
    }
    _cancelTimers();
    final s = _auth;
    if (s.isOver) return;
    final turn = s.turn;

    // Tous les humains ont fini : inutile de regarder l'ordinateur jouer seul.
    if (s.ranking.isNotEmpty && s.playingSeats.every(_config.isBot)) {
      _actionTimer = Timer(GameTiming.afterCapture, () {
        if (_auth.turn != turn || _auth.isOver) return;
        final ended = Rules.finishEarly(_auth);
        _auth = ended;
        _emit(EndEvent(seat: ended.current, state: ended));
      });
      return;
    }

    final player = _config.player(s.current);
    final kind = player?.kind ?? PlayerKind.bot;

    if (s.phase == Phase.rolling) {
      if (kind == PlayerKind.bot) {
        _actionTimer = Timer(GameTiming.botRoll, () => _authorityRoll(turn));
      } else if (kind == PlayerKind.remote) {
        _actionTimer = Timer(GameTiming.remoteTimeout, () => _authorityRoll(turn));
      }
      return;
    }

    if (s.phase == Phase.moving) {
      final legal = Rules.currentLegalPawns(s);
      if (legal.isEmpty) return;
      final sameStep = legal.every((p) => s.steps[s.current][p] == s.steps[s.current][legal.first]);
      if (legal.length == 1 || sameStep) {
        _actionTimer = Timer(GameTiming.autoMove, () => _authorityMove(legal.first, turn));
      } else if (kind == PlayerKind.bot) {
        _actionTimer = Timer(GameTiming.botMove, () {
          if (_auth.turn != turn) return;
          _authorityMove(
              Bot.choosePawn(_auth, legal, _rng, level: player?.botLevel ?? BotLevel.normal),
              turn);
        });
      } else if (kind == PlayerKind.remote) {
        _actionTimer = Timer(GameTiming.remoteTimeout, () {
          if (_auth.turn != turn) return;
          _authorityMove(Bot.choosePawn(_auth, legal, _rng), turn);
        });
      }
    }
  }

  // --- Réseau : côté hôte -------------------------------------------------

  void _onRemoteIntent(RemoteIntent intent) {
    if (_disposed) return;
    final player = _config.player(intent.seat);
    if (intent.action == 'sync' || player?.kind != PlayerKind.remote) {
      _sendSync(intent.seat);
      return;
    }
    final s = _auth;
    final valid = !s.isOver &&
        s.current == intent.seat &&
        ((intent.action == 'roll' && s.phase == Phase.rolling) ||
            (intent.action == 'move' &&
                s.phase == Phase.moving &&
                Rules.currentLegalPawns(s).contains(intent.pawn)));
    if (!valid) {
      _sendSync(intent.seat);
      return;
    }
    if (intent.action == 'roll') {
      _authorityRoll(s.turn);
    } else {
      _authorityMove(intent.pawn!, s.turn);
    }
  }

  void _sendSync(int seat) {
    hostLink?.sendToSeat(seat, {
      't': 'sync',
      'players': [for (final p in _config.players) p.toJson()],
      'state': _auth.toJson(),
    });
  }

  void _onSeatLost(int seat) {
    if (_disposed) return;
    final player = _config.player(seat);
    if (player == null || player.kind != PlayerKind.remote) return;
    final replaced = player.copyWith(kind: PlayerKind.bot, botLevel: BotLevel.normal);
    _config = _config.replacePlayer(replaced);
    hostLink?.broadcast({'t': 'seat', 'player': replaced.toJson()});
    eventText = '${player.name} est parti : l\'ordinateur prend sa place';
    eventTone = MessageTone.bad;
    _notify();
    _pump();
  }

  // --- Réseau : côté invité ------------------------------------------------

  void _askHost(Map<String, Object?> message) {
    _awaitingHost = true;
    _notify();
    clientLink?.send(message);
    _hostAnswerTimer?.cancel();
    _hostAnswerTimer = Timer(GameTiming.hostAnswer, () {
      if (!_awaitingHost) return;
      _awaitingHost = false;
      clientLink?.send({'t': 'sync'});
      _notify();
    });
  }

  void _onHostMessage(Map<String, Object?> message) {
    if (_disposed) return;
    try {
      switch (message['t']) {
        case 'ev':
          _awaitingHost = false;
          _enqueue(GameEvent.fromJson((message['e'] as Map).cast<String, Object?>()));
        case 'sync':
          _awaitingHost = false;
          _applyPlayers(message['players']);
          if (!_playing && _queue.isEmpty) {
            _state = GameState.fromJson((message['state'] as Map).cast<String, Object?>());
            _stepOverride.clear();
          }
          _notify();
        case 'seat':
          final slot = PlayerSlot.fromJson((message['player'] as Map).cast<String, Object?>());
          final previous = _config.player(slot.seat);
          _config = _config.replacePlayer(_clientView(slot));
          if (previous != null && slot.kind == PlayerKind.bot && previous.kind != PlayerKind.bot) {
            eventText = '${previous.name} est parti : l\'ordinateur prend sa place';
            eventTone = MessageTone.bad;
          }
          _notify();
        case 'start':
          _applyPlayers(message['players']);
          _reset(GameState.fromJson((message['state'] as Map).cast<String, Object?>()));
        case 'bye':
          _onHostLost('L\'hôte a quitté la partie.');
      }
    } on Object catch (e) {
      debugPrint('Message de l\'hôte ignoré : $e');
    }
  }

  void _applyPlayers(Object? raw) {
    if (raw is! List) return;
    final players = [
      for (final p in raw) _clientView(PlayerSlot.fromJson((p as Map).cast<String, Object?>())),
    ];
    _config = MatchConfig(players: players, mode: _config.mode, localSeat: _config.localSeat);
  }

  /// Sur un téléphone invité, les autres humains sont « distants ».
  PlayerSlot _clientView(PlayerSlot slot) {
    if (slot.seat == _config.localSeat) return slot.copyWith(kind: PlayerKind.human);
    if (slot.kind == PlayerKind.bot) return slot;
    return slot.copyWith(kind: PlayerKind.remote);
  }

  void _onHostLost(String reason) {
    if (_disposed || connectionLost != null) return;
    connectionLost = reason;
    _awaitingHost = false;
    _notify();
  }

  // --- Animations ------------------------------------------------------------

  void _enqueue(GameEvent event) {
    _queue.add(event);
    if (!_playing) _drain();
  }

  Future<void> _drain() async {
    _playing = true;
    _cancelTimers();
    while (_queue.isNotEmpty && !_disposed) {
      await _play(_queue.removeFirst());
    }
    _playing = false;
    if (_disposed) return;
    _notify();
    _pump();
  }

  /// Attend [d] ; renvoie faux si la partie a été relancée ou fermée
  /// entre-temps (l'animation en cours doit alors s'arrêter).
  Future<bool> _hold(Duration d, int epoch) async {
    await Future<void>.delayed(d);
    return !_disposed && epoch == _epoch;
  }

  Future<void> _play(GameEvent event) async {
    final epoch = _epoch;
    final name = nameOf(event.seat);
    switch (event) {
      case RollEvent():
        eventText = '';
        eventTone = MessageTone.neutral;
        diceRolling = true;
        _notify();
        if (!await _hold(GameTiming.roll, epoch)) return;
        diceRolling = false;
        _diceFace = event.value;
        if (_config.isLocalHuman(event.seat)) HapticFeedback.lightImpact();
        switch (event.end) {
          case RollEnd.mustMove:
            if (event.value == 6) {
              eventText = '$name a fait 6 !';
              eventTone = MessageTone.good;
            }
            _state = event.state;
            _notify();
            return;
          case RollEnd.noMove:
            eventText = '$name a fait ${event.value} : aucun pion ne peut avancer';
          case RollEnd.noMoveRollAgain:
            eventText = 'Six ! Aucun pion ne peut avancer, $name relance';
            eventTone = MessageTone.good;
          case RollEnd.threeSixes:
            eventText = 'Trois 6 de suite : $name passe son tour';
            eventTone = MessageTone.bad;
        }
        _notify();
        if (!await _hold(GameTiming.noMovePause, epoch)) return;
        _state = event.state;
        _notify();
      case MoveEvent():
        final key = event.seat * 4 + event.pawn;
        hoppingKey = key;
        for (final step in event.path) {
          _stepOverride[key] = step;
          _notify();
          final pause = event.from < 0 ? GameTiming.exitBase : GameTiming.hop;
          if (!await _hold(pause, epoch)) {
            _stepOverride.clear();
            hoppingKey = null;
            return;
          }
        }
        _stepOverride.clear();
        hoppingKey = null;
        _state = event.state;
        _describeMove(event, name);
        _notify();
        await _hold(
            event.captures.isNotEmpty ? GameTiming.afterCapture : GameTiming.afterMove, epoch);
      case EndEvent():
        _state = event.state;
        eventText = 'Il ne reste que l\'ordinateur : partie terminée';
        eventTone = MessageTone.neutral;
        _notify();
    }
  }

  void _describeMove(MoveEvent event, String name) {
    eventTone = MessageTone.good;
    if (event.captures.isNotEmpty) {
      final victims = {for (final c in event.captures) nameOf(c.seat)}.join(' et ');
      eventText = event.captures.length > 1
          ? '$name capture ${event.captures.length} pions de $victims !'
          : '$name capture un pion de $victims !';
      HapticFeedback.heavyImpact();
    } else if (event.seatFinished) {
      final place = event.state.ranking.indexOf(event.seat) + 1;
      eventText = place == 1
          ? '$name a ramené ses 4 pions : victoire !'
          : '$name termine ${place}e';
    } else if (event.reachedHome) {
      eventText = '$name rentre un pion à la toguna';
    } else {
      eventTone = MessageTone.neutral;
      final sheltered = event.from >= 0 &&
          event.to <= Board.lastTrackStep &&
          Board.isSafeStep(event.seat, event.to);
      final again = !event.state.isOver &&
          event.state.phase == Phase.rolling &&
          event.state.current == event.seat;
      if (sheltered) {
        eventText = again ? '$name est à l\'abri et rejoue' : '$name est à l\'abri';
      } else {
        eventText = again ? '$name rejoue' : '';
      }
    }
  }

  void _cancelTimers() {
    _actionTimer?.cancel();
    _actionTimer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    _hostAnswerTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
