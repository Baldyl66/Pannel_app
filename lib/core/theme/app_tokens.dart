import 'package:flutter/material.dart';

/// Palette de l'application. Toutes les couleurs passent par ici pour garder
/// un rendu cohérent d'un écran à l'autre.
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF111113);
  static const surfaceHigh = Color(0xFF1A1A1D);
  static const surfaceHighest = Color(0xFF242428);
  static const border = Color(0x14FFFFFF); // blanc 8 %
  static const borderStrong = Color(0x24FFFFFF); // blanc 14 %

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0x99FFFFFF); // blanc 60 %
  static const textTertiary = Color(0x61FFFFFF); // blanc 38 %

  static const danger = Color(0xFFFF5A5F);
  static const success = Color(0xFF34C759);

  static const spotify = Color(0xFF1DB954);
  static const discord = Color(0xFF5865F2);
  static const google = Color(0xFF4285F4);

  /// Couleurs proposées pour l'accent et les boutons de la soundboard.
  static const swatches = <Color>[
    Color(0xFF1DB954), // Vert
    Color(0xFF0A84FF), // Bleu
    Color(0xFF5E5CE6), // Indigo
    Color(0xFFBF5AF2), // Violet
    Color(0xFFFF375F), // Rose
    Color(0xFFFF453A), // Rouge
    Color(0xFFFF9F0A), // Orange
    Color(0xFFFFD60A), // Jaune
    Color(0xFF64D2FF), // Cyan
  ];
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Largeur maximale du contenu sur grand écran (desktop / tablette).
  static const maxContentWidth = 760.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
