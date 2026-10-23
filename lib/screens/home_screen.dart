/// Accueil : nom, choix du masque et modes de jeu.
library;

import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../ui/board_painter.dart';
import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'bluetooth_screen.dart';
import 'local_setup_screen.dart';
import 'rules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final profile = PlayerProfile.instance;
  late final TextEditingController _name =
      TextEditingController(text: profile.name == 'Joueur' ? '' : profile.name);

  @override
  void initState() {
    super.initState();
    profile.addListener(_syncName);
  }

  @override
  void dispose() {
    profile.removeListener(_syncName);
    _name.dispose();
    super.dispose();
  }

  /// Reprend le nom saisi ailleurs (par exemple avant une partie Bluetooth).
  void _syncName() {
    if (_name.text.trim().isEmpty && profile.name != 'Joueur') {
      _name.text = profile.name;
    }
  }

  void _saveName() => profile.name = _name.text;

  Future<void> _open(Widget screen) async {
    _saveName();
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: profile,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SquareIconButton(
                          icon: DogonIcon.book,
                          label: 'Règles du jeu',
                          onPressed: () => _open(const RulesScreen()),
                        ),
                      ],
                    ),
                    _Emblem(seat: profile.seat),
                    const SizedBox(height: 14),
                    Text(
                      'LUDO DOGON',
                      textAlign: TextAlign.center,
                      style: AppText.display.copyWith(fontSize: 30, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Le jeu des masques de la falaise',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DogonColors.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('TON NOM', style: AppText.label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      maxLength: 16,
                      textCapitalization: TextCapitalization.words,
                      style: AppText.body,
                      decoration: const InputDecoration(
                        hintText: 'Écris ton nom',
                        counterText: '',
                      ),
                      onChanged: (_) => _saveName(),
                      onSubmitted: (_) => _saveName(),
                    ),
                    const SizedBox(height: 22),
                    const Text('CHOISIS TON MASQUE', style: AppText.label),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var seat = 0; seat < 4; seat++)
                          Expanded(
                            child: _MaskChoice(
                              seat: seat,
                              selected: profile.seat == seat,
                              onTap: () => profile.seat = seat,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _ModeButton(
                      primary: true,
                      icon: DogonIcon.bluetooth,
                      title: 'Jouer en Bluetooth',
                      subtitle: '2 à 4 téléphones, sans internet',
                      onTap: () => _open(const BluetoothScreen()),
                    ),
                    const SizedBox(height: 10),
                    _ModeButton(
                      icon: DogonIcon.robot,
                      title: 'Contre l\'ordinateur',
                      subtitle: 'Pour t\'entraîner seul',
                      onTap: () => _open(const LocalSetupScreen(versusComputer: true)),
                    ),
                    const SizedBox(height: 10),
                    _ModeButton(
                      icon: DogonIcon.people,
                      title: 'Sur le même téléphone',
                      subtitle: 'Chacun son tour, de 2 à 4',
                      onTap: () => _open(const LocalSetupScreen(versusComputer: false)),
                    ),
                  ],
                ),
              ),
            ),
            const DamierStrip(),
          ],
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.seat});

  final int seat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 148,
        height: 148,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: DogonColors.nightDeep, spreadRadius: 3)],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: ColoredBox(
                  color: DogonColors.wood,
                  child: CustomPaint(painter: DamierPainter(color: DogonColors.ochre, square: 9)),
                ),
              ),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: DogonColors.kaolin,
                  shape: BoxShape.circle,
                  border: Border.all(color: DogonColors.nightDeep, width: 3),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: DogonIconView(
                      maskIcon(seat),
                      key: ValueKey(seat),
                      size: 64,
                      color: DogonColors.night,
                      strokeWidth: 1.6,
                      semanticLabel: 'Masque ${seatStyles[seat].mask}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaskChoice extends StatelessWidget {
  const _MaskChoice({required this.seat, required this.selected, required this.onTap});

  final int seat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = seatStyles[seat];
    return Semantics(
      button: true,
      selected: selected,
      label: 'Masque ${style.mask}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? const [
                          BoxShadow(color: DogonColors.night, spreadRadius: 3),
                          BoxShadow(color: DogonColors.kaolin, spreadRadius: 6),
                        ]
                      : null,
                ),
                child: Center(
                  child: DogonIconView(maskIcon(seat), size: 30, color: style.onColor),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                style.mask,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? DogonColors.kaolin : DogonColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final DogonIcon icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? DogonColors.night : DogonColors.kaolin;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: primary
            ? const [BoxShadow(color: DogonColors.ochreDeep, offset: Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: primary ? DogonColors.ochre : DogonColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: primary ? BorderSide.none : const BorderSide(color: DogonColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: primary ? 16 : 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary ? DogonColors.night : DogonColors.outline,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: DogonIconView(icon,
                        size: 22,
                        color: primary ? DogonColors.ochre : DogonColors.kaolin,
                        strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: primary
                            ? const TextStyle(
                                fontFamily: AppFonts.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: DogonColors.night,
                              )
                            : AppText.body.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary ? fg : DogonColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                DogonIconView(DogonIcon.chevron, size: 20, color: fg, strokeWidth: 2.2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
