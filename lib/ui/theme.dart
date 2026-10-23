/// Couleurs, polices et styles de Ludo Dogon.
library;

import 'package:flutter/material.dart';

/// Palette inspirée du pays dogon : nuit sur la latérite, banco, ocre,
/// indigo, terre cuite, mil et kaolin.
abstract final class DogonColors {
  static const Color night = Color(0xFF22160F); // fond de l'application
  static const Color nightDeep = Color(0xFF1E140D); // traits sombres
  static const Color surface = Color(0xFF34241A); // cartes
  static const Color surfaceHigh = Color(0xFF3D2A1C); // carte active
  static const Color outline = Color(0xFF4A3426);
  static const Color wood = Color(0xFF5A3B24); // cadre du plateau
  static const Color banco = Color(0xFFF1E2C4); // cases du plateau
  static const Color bancoLine = Color(0xFF8C6B44);
  static const Color earthText = Color(0xFF6B4A2B);
  static const Color kaolin = Color(0xFFF4ECDD); // texte clair
  static const Color muted = Color(0xFFC9B391); // texte secondaire
  static const Color ochre = Color(0xFFE0A43A);
  static const Color ochreDeep = Color(0xFF9A6A1F);
  static const Color indigo = Color(0xFF2D4878);
  static const Color clay = Color(0xFFA3402A);
  static const Color millet = Color(0xFF6E9440);
  static const Color danger = Color(0xFFE07A5F);
}

/// Identité visuelle de chaque siège (masque et couleur).
class SeatStyle {
  const SeatStyle({
    required this.mask,
    required this.color,
    required this.shade,
    required this.onColor,
    required this.colorName,
    required this.textColor,
  });

  /// Nom du masque dogon associé au siège.
  final String mask;
  final Color color;

  /// Teinte plus sombre utilisée pour les damiers.
  final Color shade;

  /// Couleur lisible posée sur [color].
  final Color onColor;
  final String colorName;

  /// Variante claire, lisible en texte sur le fond sombre.
  final Color textColor;
}

const List<SeatStyle> seatStyles = [
  SeatStyle(
    mask: 'Kanaga',
    color: DogonColors.ochre,
    shade: Color(0xFFC98A2C),
    onColor: DogonColors.night,
    colorName: 'ocre',
    textColor: DogonColors.ochre,
  ),
  SeatStyle(
    mask: 'Sirige',
    color: DogonColors.indigo,
    shade: Color(0xFF243B63),
    onColor: DogonColors.kaolin,
    colorName: 'indigo',
    textColor: Color(0xFF9DB4E0),
  ),
  SeatStyle(
    mask: 'Walu',
    color: DogonColors.clay,
    shade: Color(0xFF8A3522),
    onColor: DogonColors.kaolin,
    colorName: 'terre cuite',
    textColor: Color(0xFFEB8C70),
  ),
  SeatStyle(
    mask: 'Satimbe',
    color: DogonColors.millet,
    shade: Color(0xFF5C7D35),
    onColor: DogonColors.night,
    colorName: 'vert mil',
    textColor: Color(0xFFAACB7C),
  ),
];

abstract final class AppFonts {
  static const String display = 'Unbounded';
  static const String body = 'NunitoSans';
}

/// Styles de texte récurrents.
abstract final class AppText {
  static const TextStyle display = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    color: DogonColors.kaolin,
    letterSpacing: 1,
  );

  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: DogonColors.kaolin,
  );

  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w800,
    fontSize: 13,
    letterSpacing: 1,
    color: DogonColors.muted,
  );

  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: DogonColors.kaolin,
    height: 1.35,
  );

  static const TextStyle small = TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: DogonColors.muted,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: DogonColors.ochre,
    onPrimary: DogonColors.night,
    secondary: DogonColors.indigo,
    onSecondary: DogonColors.kaolin,
    error: DogonColors.danger,
    onError: DogonColors.night,
    surface: DogonColors.surface,
    onSurface: DogonColors.kaolin,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DogonColors.night,
    fontFamily: AppFonts.body,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: AppFonts.body,
      bodyColor: DogonColors.kaolin,
      displayColor: DogonColors.kaolin,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: DogonColors.surface,
      titleTextStyle: AppText.title,
      contentTextStyle: AppText.body,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: DogonColors.kaolin,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontWeight: FontWeight.w700,
        color: DogonColors.night,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DogonColors.surface,
      hintStyle: AppText.body.copyWith(color: DogonColors.muted),
      labelStyle: AppText.small,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DogonColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DogonColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DogonColors.ochre, width: 2),
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: DogonColors.ochre),
  );
}
