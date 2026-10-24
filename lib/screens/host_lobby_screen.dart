/// Salon de l'hôte : la partie est visible, l'hôte accepte les joueurs,
/// ajoute l'ordinateur et lance la partie.
library;

import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../models/match.dart';
import '../models/profile.dart';
import '../net/host_session.dart';
import '../net/nearby_service.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'diagnostic_screen.dart';
import 'game_screen.dart';

class HostLobbyScreen extends StatefulWidget {
  const HostLobbyScreen({super.key});

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen> {
  late final HostSession _session = HostSession(
    net: NetService(),
    hostName: PlayerProfile.instance.name,
    hostSeat: PlayerProfile.instance.seat,
  );
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _session.open();
  }

  @override
  void dispose() {
    if (!_handedOff) _session.close();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_session.remoteCount > 0) {
      final ok = await confirmDialog(
        context,
        title: 'Fermer la partie ?',
        message: 'Les joueurs connectés seront déconnectés.',
        confirm: 'Fermer',
      );
      if (!ok || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  /// Le diagnostic utilise le Bluetooth : on ferme d'abord la partie.
  Future<void> _openDiagnostic() async {
    if (_session.remoteCount > 0) {
      final ok = await confirmDialog(
        context,
        title: 'Fermer la partie ?',
        message: 'Le diagnostic ferme la partie et déconnecte les joueurs.',
        confirm: 'Continuer',
      );
      if (!ok || !mounted) return;
    }
    _handedOff = true;
    await _session.close();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DiagnosticScreen()),
    );
  }

  void _start() {
    if (!_session.canStart) return;
    final named = _session.start();
    final controller = GameController(config: named, hostLink: _session);
    _session.broadcast({
      't': 'start',
      'players': [for (final p in named.players) p.toJson()],
      'state': controller.state.toJson(),
    });
    _handedOff = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => GameScreen(
        controller: controller,
        subtitle: 'Partie Bluetooth · ${named.players.length} joueurs',
        onClose: _session.close,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _session,
            builder: (context, _) => Column(
              children: [
                ScreenHeader(
                  title: 'Salon Bluetooth',
                  subtitle: 'Tu es l\'hôte de la partie',
                  onBack: _leave,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      _statusCard(),
                      if (!_session.autoAccept)
                      for (final r in _session.requests) ...[
                        const SizedBox(height: 12),
                        _RequestCard(
                          request: r,
                          onAccept: () => _session.acceptRequest(r.id),
                          onReject: () => _session.rejectRequest(r.id),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('JOUEURS · ${_session.playerCount}/4', style: AppText.label),
                      const SizedBox(height: 10),
                      for (var seat = 0; seat < 4; seat++) ...[
                        _seatRow(seat),
                        const SizedBox(height: 8),
                      ],
                      if (_session.joiningCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _session.joiningCount == 1
                                ? 'Un joueur se connecte…'
                                : '${_session.joiningCount} joueurs se connectent…',
                            style: AppText.small,
                          ),
                        ),
                      const SizedBox(height: 10),
                      const _LocationTip(),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _openDiagnostic,
                        child: const Text('Personne ne trouve ta partie ? Voir le diagnostic',
                            style: TextStyle(color: DogonColors.ochre, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: PrimaryButton(
                    label: _session.canStart
                        ? 'Lancer la partie · ${_session.playerCount} joueurs'
                        : 'Il faut au moins 2 joueurs',
                    icon: DogonIcon.check,
                    onPressed: _session.canStart ? _start : null,
                  ),
                ),
                const CliffFrieze(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final error = _session.error;
    if (error != null) {
      return InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Partie non visible', style: AppText.title),
            const SizedBox(height: 6),
            Text(error, style: AppText.body.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Réessayer',
              icon: DogonIcon.refresh,
              onPressed: _session.open,
            ),
          ],
        ),
      );
    }
    final open = _session.isOpen;
    return InfoCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: DogonColors.ochre, shape: BoxShape.circle),
            child: Center(
              child: open
                  ? const DogonIconView(DogonIcon.bluetooth,
                      size: 26, color: DogonColors.night, strokeWidth: 2.2)
                  : const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: DogonColors.night),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(open ? 'Ta partie est visible' : 'Ouverture de la partie…',
                    style: AppText.title),
                const SizedBox(height: 4),
                Text(
                  'Les autres joueurs ouvrent Ludo Dogon › Jouer en Bluetooth › '
                  'Rejoindre, puis choisissent « ${_session.hostName} ».',
                  style: AppText.small.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatRow(int seat) {
    final p = _session.playerAt(seat);
    final style = seatStyles[seat];
    if (p == null) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DogonColors.outline, width: 1.5),
        ),
        child: Row(
          children: [
            Opacity(opacity: 0.35, child: MaskBadge(seat: seat, size: 42)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${style.mask} · place libre',
                  style: AppText.body.copyWith(color: DogonColors.muted, fontSize: 14)),
            ),
            TextButton(
              onPressed: () => _session.addBot(seat),
              child: const Text('+ Ordinateur',
                  style: TextStyle(color: DogonColors.ochre, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
    }
    final isHost = seat == _session.hostSeat;
    final String status;
    switch (p.kind) {
      case PlayerKind.human:
        status = 'Hôte · ce téléphone';
      case PlayerKind.bot:
        status = 'Ordinateur';
      case PlayerKind.remote:
        status = 'Connecté';
    }
    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: DogonColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DogonColors.outline),
      ),
      child: Row(
        children: [
          MaskBadge(seat: seat, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                Text(status, style: AppText.small),
              ],
            ),
          ),
          if (isHost)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DogonColors.ochre,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text('Hôte',
                  style: TextStyle(
                      color: DogonColors.night, fontWeight: FontWeight.w800, fontSize: 12)),
            )
          else
            IconButton(
              tooltip: p.kind == PlayerKind.bot ? 'Retirer l\'ordinateur' : 'Retirer ce joueur',
              onPressed: () => _session.freeSeat(seat),
              icon: const DogonIconView(DogonIcon.close,
                  size: 18, color: DogonColors.muted, strokeWidth: 2.4),
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onAccept, required this.onReject});

  final JoinRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: DogonColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DogonColors.ochre, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${request.name} veut rejoindre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Code : ${request.token}',
                    style: AppText.small.copyWith(color: DogonColors.ochre)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refuser',
            onPressed: onReject,
            icon: const DogonIconView(DogonIcon.close,
                size: 18, color: DogonColors.kaolin, strokeWidth: 2.4),
          ),
          const SizedBox(width: 4),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: DogonColors.ochre,
              foregroundColor: DogonColors.night,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onAccept,
            child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _LocationTip extends StatelessWidget {
  const _LocationTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1D14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DogonColors.outline),
      ),
      child: const Text(
        'Les joueurs qui rejoignent entrent automatiquement dans la partie. '
        'Touche ✕ pour retirer quelqu\'un. Garde cet écran ouvert.',
        style: TextStyle(fontSize: 13, color: DogonColors.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}
