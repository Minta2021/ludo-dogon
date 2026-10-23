/// Rejoindre une partie Bluetooth : liste des parties proches, connexion,
/// puis attente du lancement par l'hôte.
library;

import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../models/match.dart';
import '../models/profile.dart';
import '../net/client_session.dart';
import '../net/nearby_service.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'game_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final ClientSession _session = ClientSession(
    net: NetService(),
    myName: PlayerProfile.instance.name,
    preferredSeat: PlayerProfile.instance.seat,
  );
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _session.startSearch();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    if (!_handedOff) _session.close();
    super.dispose();
  }

  void _onSession() {
    if (_handedOff || !mounted) return;
    final config = _session.startConfig;
    final state = _session.startState;
    if (_session.status == ClientStatus.started && config != null && state != null) {
      _handedOff = true;
      final controller = GameController(
        config: config,
        clientLink: _session,
        initialState: state,
      );
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          controller: controller,
          subtitle: 'Partie de ${_session.hostName ?? 'l\'hôte'} · ${config.players.length} joueurs',
          onClose: _session.close,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _session,
          builder: (context, _) => Column(
            children: [
              ScreenHeader(
                title: 'Rejoindre',
                subtitle: 'Parties Bluetooth proches',
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _body()),
              const CliffFrieze(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_session.status) {
      case ClientStatus.idle:
      case ClientStatus.searching:
        return _searching();
      case ClientStatus.connecting:
        return _connecting();
      case ClientStatus.inLobby:
      case ClientStatus.started:
        return _lobby();
      case ClientStatus.failed:
        return _failed();
    }
  }

  Widget _searching() {
    final games = _session.games;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const InfoCard(
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Recherche des parties à proximité…',
                  style: AppText.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('PARTIES TROUVÉES · ${games.length}', style: AppText.label),
        const SizedBox(height: 10),
        if (games.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucune partie pour l\'instant. Demande à l\'hôte de toucher '
              '« Créer une partie » et garde les téléphones proches.',
              style: AppText.small,
            ),
          ),
        for (final g in games) ...[
          _GameTile(game: g, onJoin: () => _session.join(g)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _connecting() {
    final token = _session.token;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        InfoCard(
          child: Column(
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'Connexion à la partie de ${_session.hostName ?? 'l\'hôte'}…',
                textAlign: TextAlign.center,
                style: AppText.title,
              ),
              const SizedBox(height: 8),
              Text(
                token == null
                    ? 'Patiente quelques secondes.'
                    : 'L\'hôte doit accepter. Vérifie qu\'il voit le code :',
                textAlign: TextAlign.center,
                style: AppText.small.copyWith(fontSize: 13),
              ),
              if (token != null) ...[
                const SizedBox(height: 10),
                Text(token,
                    style: AppText.display.copyWith(fontSize: 26, color: DogonColors.ochre)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SecondaryButton(label: 'Annuler', onPressed: _session.backToSearch),
      ],
    );
  }

  Widget _lobby() {
    final seat = _session.mySeat;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        InfoCard(
          child: Row(
            children: [
              if (seat != null) MaskBadge(seat: seat, size: 56, ring: true),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tu es dans la partie !', style: AppText.title),
                    const SizedBox(height: 4),
                    Text(
                      seat == null
                          ? 'En attente de l\'hôte…'
                          : 'Ton masque : ${seatStyles[seat].mask}. '
                              '${_session.hostName ?? 'L\'hôte'} va lancer la partie.',
                      style: AppText.small.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('JOUEURS · ${_session.lobby.length}/4', style: AppText.label),
        const SizedBox(height: 10),
        for (final p in _session.lobby) ...[
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: DogonColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: p.seat == seat ? DogonColors.ochre : DogonColors.outline,
                width: p.seat == seat ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                MaskBadge(seat: p.seat, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p.seat == seat ? '${p.name} (toi)' : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  switch (p.kind) {
                    PlayerKind.bot => 'Ordinateur',
                    PlayerKind.human => 'Hôte',
                    PlayerKind.remote => 'Connecté',
                  },
                  style: AppText.small,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
        const SizedBox(height: 10),
        const Text('En attente du lancement…', textAlign: TextAlign.center, style: AppText.small),
      ],
    );
  }

  Widget _failed() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        InfoCard(
          child: Column(
            children: [
              const DogonIconView(DogonIcon.bluetooth,
                  size: 40, color: DogonColors.danger, strokeWidth: 2),
              const SizedBox(height: 12),
              const Text('Impossible de rejoindre', style: AppText.title),
              const SizedBox(height: 8),
              Text(_session.error ?? 'Une erreur est survenue.',
                  textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Chercher à nouveau',
          icon: DogonIcon.refresh,
          onPressed: _session.backToSearch,
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.onJoin});

  final FoundGame game;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: DogonColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DogonColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: DogonColors.outline, shape: BoxShape.circle),
            child: const Center(
              child: DogonIconView(DogonIcon.toguna,
                  size: 24, color: DogonColors.kaolin, strokeWidth: 1.8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Partie de ${game.hostName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                const Text('À proximité', style: AppText.small),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: DogonColors.ochre,
              foregroundColor: DogonColors.night,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onJoin,
            child: const Text('Rejoindre', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
