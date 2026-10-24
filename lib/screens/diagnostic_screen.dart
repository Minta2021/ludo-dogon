/// Diagnostic Bluetooth : état du téléphone, test entre deux téléphones
/// (visibilité, recherche, connexion, échange de messages) et journal.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile.dart';
import '../net/nearby_service.dart';
import '../net/net_log.dart';
import '../net/readiness.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/readiness_card.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

enum _Mode { idle, visible, searching }

class _Peer {
  _Peer(this.id, this.name);
  final String id;
  final String name;
  bool connecting = false;
  bool connected = false;
  int sent = 0;
  int received = 0;
}

class _DiagnosticScreenState extends State<DiagnosticScreen> with WidgetsBindingObserver {
  final _readiness = BluetoothReadiness();
  NetService? _net;
  StreamSubscription<NetEvent>? _sub;
  Timer? _pinger;
  _Mode _mode = _Mode.idle;
  String? _error;
  final Map<String, _Peer> _peers = {};

  String get _myName => PlayerProfile.instance.name == 'Joueur'
      ? 'Test ${seatStyles[PlayerProfile.instance.seat].mask}'
      : PlayerProfile.instance.name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readiness.refresh().then((_) => _readiness.logSummary());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _readiness.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readiness.refresh();
  }

  NetService _service() {
    final net = _net ??= NetService();
    _sub ??= net.events.listen(_onEvent);
    return net;
  }

  Future<void> _start(_Mode mode) async {
    if (!await ensureBluetoothReady(context, _readiness) || !mounted) return;
    await _stop();
    setState(() {
      _mode = mode;
      _error = null;
      _peers.clear();
    });
    netLog('— Test : ${mode == _Mode.visible ? 'être visible' : 'chercher'} —');
    final net = _service();
    try {
      if (mode == _Mode.visible) {
        await net.startHosting(_myName, serviceId: kTestServiceId);
      } else {
        await net.startSearching(_myName, serviceId: kTestServiceId);
      }
    } on NetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    _pinger = Timer.periodic(const Duration(seconds: 2), (_) => _ping());
  }

  Future<void> _stop() async {
    _pinger?.cancel();
    _pinger = null;
    await _net?.shutdown();
    if (mounted) setState(() => _mode = _Mode.idle);
  }

  void _ping() {
    for (final p in _peers.values) {
      if (!p.connected) continue;
      p.sent++;
      _net?.send(p.id, {'t': 'ping', 'n': p.sent, 'from': _myName});
    }
    if (mounted) setState(() {});
  }

  Future<void> _connect(_Peer p) async {
    setState(() => p.connecting = true);
    try {
      await _service().requestConnection(_myName, p.id);
    } on NetException catch (e) {
      if (mounted) {
        setState(() {
          p.connecting = false;
          _error = e.message;
        });
      }
    }
  }

  void _onEvent(NetEvent e) {
    if (!mounted) return;
    setState(() {
      switch (e) {
        case PeerFound(:final id, :final name):
          _peers.putIfAbsent(id, () => _Peer(id, name));
        case PeerLost(:final id):
          final p = _peers[id];
          if (p != null && !p.connected) _peers.remove(id);
        case ConnectionRequested(:final id, :final name):
          _peers.putIfAbsent(id, () => _Peer(id, name)).connecting = true;
          unawaited(_net?.accept(id).catchError((Object err) {
            if (mounted) setState(() => _error = '$err');
          }));
        case PeerConnected(:final id):
          final p = _peers[id];
          if (p != null) {
            p.connecting = false;
            p.connected = true;
          }
          HapticFeedback.mediumImpact();
        case ConnectionFailed(:final id):
          _peers[id]?.connecting = false;
        case PeerDisconnected(:final id):
          final p = _peers[id];
          if (p != null) {
            p.connected = false;
            p.connecting = false;
          }
        case PeerMessage(:final id, :final data):
          final p = _peers[id];
          if (p != null) p.received++;
          if (data['t'] == 'ping') {
            _net?.send(id, {'t': 'pong', 'n': data['n']});
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Diagnostic Bluetooth',
              subtitle: 'Vérifier et tester entre deux téléphones',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _phoneCard(),
                  const SizedBox(height: 12),
                  ReadinessCard(readiness: _readiness),
                  const SizedBox(height: 20),
                  const Text('TEST ENTRE DEUX TÉLÉPHONES', style: AppText.label),
                  const SizedBox(height: 8),
                  const Text(
                    'Sur un téléphone, touche « Être visible ». Sur l\'autre, touche '
                    '« Chercher », puis le nom qui apparaît. S\'ils se connectent et que '
                    'les messages augmentent des deux côtés, le Bluetooth du jeu fonctionne.',
                    style: AppText.small,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _modeButton('Être visible', DogonIcon.toguna, _Mode.visible),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _modeButton('Chercher', DogonIcon.bluetooth, _Mode.searching),
                      ),
                    ],
                  ),
                  if (_mode != _Mode.idle) ...[
                    const SizedBox(height: 10),
                    SecondaryButton(label: 'Arrêter le test', icon: DogonIcon.close, onPressed: _stop),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InfoCard(
                      child: Text(_error!,
                          style: AppText.body.copyWith(color: DogonColors.danger, fontSize: 14)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _peersCard(),
                  const SizedBox(height: 20),
                  _logCard(),
                ],
              ),
            ),
            const CliffFrieze(),
          ],
        ),
      ),
    );
  }

  Widget _phoneCard() {
    return ListenableBuilder(
      listenable: _readiness,
      builder: (context, _) {
        final i = _readiness.info;
        return InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CE TÉLÉPHONE', style: AppText.label),
              const SizedBox(height: 6),
              if (i == null)
                const Text('Informations indisponibles.', style: AppText.small)
              else ...[
                Text(i.phoneName, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                Text('Android ${i.release} (API ${i.sdk})', style: AppText.small),
                Text('Services Google Play : ${i.playServices ?? 'absents'}', style: AppText.small),
                Text('Wi-Fi : ${i.wifi ? 'activé' : 'désactivé'} (conseillé, sans besoin d\'internet)',
                    style: AppText.small),
                Text('Nom visible : $_myName', style: AppText.small),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _modeButton(String label, DogonIcon icon, _Mode mode) {
    final active = _mode == mode;
    return Material(
      color: active ? DogonColors.ochre : DogonColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? DogonColors.ochre : DogonColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _start(mode),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DogonIconView(icon,
                  size: 20, color: active ? DogonColors.night : DogonColors.kaolin, strokeWidth: 2),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: active ? DogonColors.night : DogonColors.kaolin,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _peersCard() {
    if (_mode == _Mode.idle && _peers.isEmpty) return const SizedBox.shrink();
    final waiting = _mode == _Mode.visible
        ? 'Visible. En attente qu\'un autre téléphone se connecte…'
        : 'Recherche en cours… (jusqu\'à 30 secondes)';
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TÉLÉPHONES (${_peers.length})', style: AppText.label),
          const SizedBox(height: 6),
          if (_peers.isEmpty) Text(waiting, style: AppText.small),
          for (final p in _peers.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.connected
                          ? DogonColors.millet
                          : (p.connecting ? DogonColors.ochre : DogonColors.outline),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          p.connected
                              ? 'Connecté · messages envoyés ${p.sent}, reçus ${p.received}'
                              : (p.connecting ? 'Connexion…' : 'Trouvé'),
                          style: AppText.small.copyWith(
                              color: p.connected && p.received > 0 ? DogonColors.millet : null),
                        ),
                      ],
                    ),
                  ),
                  if (!p.connected && !p.connecting && _mode == _Mode.searching)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: DogonColors.ochre,
                        foregroundColor: DogonColors.night,
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => _connect(p),
                      child: const Text('Connecter', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _logCard() {
    return ListenableBuilder(
      listenable: NetLog.instance,
      builder: (context, _) {
        final lines = NetLog.instance.lines;
        final shown = lines.length > 80 ? lines.sublist(lines.length - 80) : lines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('JOURNAL', style: AppText.label)),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: NetLog.instance.text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Journal copié : colle-le dans un message.')),
                    );
                  },
                  child: const Text('Copier', style: TextStyle(color: DogonColors.ochre)),
                ),
                TextButton(
                  onPressed: NetLog.instance.clear,
                  child: const Text('Effacer', style: TextStyle(color: DogonColors.muted)),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF17100B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DogonColors.outline),
              ),
              child: Text(
                shown.isEmpty ? 'Rien pour l\'instant.' : shown.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.4,
                  color: DogonColors.muted,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
