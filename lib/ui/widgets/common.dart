/// Éléments d'interface réutilisés sur tous les écrans.
library;

import 'package:flutter/material.dart';

import '../../services/sound.dart';
import '../board_painter.dart';
import '../dogon_icons.dart';
import '../theme.dart';

/// Frise en damier ocre (sous les en-têtes).
class DamierStrip extends StatelessWidget {
  const DamierStrip({super.key, this.height = 12, this.color = DogonColors.ochre});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: DamierPainter(color: color, square: height / 2)),
        ),
      );
}

/// Frise de triangles (bas des écrans).
class CliffFrieze extends StatelessWidget {
  const CliffFrieze({super.key, this.height = 8});

  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: const CustomPaint(painter: SawtoothPainter(color: DogonColors.ochre)),
        ),
      );
}

/// Bouton carré d'en-tête (retour, menu…).
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final DogonIcon icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: DogonColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: DogonColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: DogonIconView(icon, size: 22, color: DogonColors.kaolin, strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton qui active ou coupe les sons du jeu.
class SoundToggleButton extends StatelessWidget {
  const SoundToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final fx = SoundFx.instance;
    return ListenableBuilder(
      listenable: fx,
      builder: (context, _) => SquareIconButton(
        icon: fx.enabled ? DogonIcon.sound : DogonIcon.soundOff,
        label: fx.enabled ? 'Couper le son' : 'Activer le son',
        onPressed: () => fx.setEnabled(!fx.enabled),
      ),
    );
  }
}

/// En-tête des écrans : retour, titre, sous-titre, action à droite.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              if (onBack != null)
                SquareIconButton(icon: DogonIcon.back, label: 'Retour', onPressed: onBack)
              else
                const SizedBox(width: 44),
              Expanded(
                child: Column(
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: AppText.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          textAlign: TextAlign.center,
                          style: AppText.small,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              trailing ?? const SizedBox(width: 44),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const DamierStrip(),
      ],
    );
  }
}

/// Grand bouton ocre.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final DogonIcon? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: DogonColors.ochreDeep, offset: Offset(0, 4))],
          ),
          child: Material(
            color: DogonColors.ochre,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      DogonIconView(icon!, size: 20, color: DogonColors.night, strokeWidth: 2.2),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: DogonColors.night,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire sombre.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final DogonIcon? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DogonColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: DogonColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  DogonIconView(icon!, size: 20, color: DogonColors.kaolin, strokeWidth: 2),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Disque coloré portant le masque d'un siège.
class MaskBadge extends StatelessWidget {
  const MaskBadge({super.key, required this.seat, this.size = 40, this.ring = false});

  final int seat;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final style = seatStyles[seat];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color,
        shape: BoxShape.circle,
        boxShadow: ring
            ? const [
                BoxShadow(color: DogonColors.night, spreadRadius: 3),
                BoxShadow(color: DogonColors.kaolin, spreadRadius: 6),
              ]
            : null,
      ),
      child: Center(
        child: DogonIconView(
          maskIcon(seat),
          size: size * 0.6,
          color: style.onColor,
          semanticLabel: 'Masque ${style.mask}',
        ),
      ),
    );
  }
}

/// Carte d'information (fond sombre arrondi).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: DogonColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DogonColors.outline),
        ),
        child: child,
      );
}

/// Affiche une boîte de dialogue de confirmation ; renvoie vrai si accepté.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String cancel = 'Annuler',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancel, style: const TextStyle(color: DogonColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm,
              style: const TextStyle(color: DogonColors.ochre, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return result ?? false;
}
