import 'package:flutter/material.dart';

/// Palette de l'application. Toutes les couleurs passent par ici pour garder
/// un rendu cohérent d'un écran à l'autre.
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0F0F11);
  static const surfaceHigh = Color(0xFF18181B);
  static const surfaceHighest = Color(0xFF232327);
  static const border = Color(0x12FFFFFF); // blanc 7 %
  static const borderStrong = Color(0x24FFFFFF); // blanc 14 %

  static const textPrimary = Color(0xFFF4F4F5);
  static const textSecondary = Color(0x9EFFFFFF); // blanc 62 %
  static const textTertiary = Color(0x66FFFFFF); // blanc 40 %

  static const danger = Color(0xFFFF5A5F);
  static const warning = Color(0xFFFFB020);
  static const success = Color(0xFF30D158);

  static const spotify = Color(0xFF1DB954);
  static const discord = Color(0xFF5865F2);
  static const google = Color(0xFF4285F4);

  /// Couleurs prêtes à l'emploi (accent, boutons de la soundboard…).
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
    Color(0xFFE5E5EA), // Blanc
  ];
}

abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Marge horizontale des pages.
  static const page = 20.0;

  /// Espace réservé en bas des listes pour la barre de navigation flottante.
  static const navBarClearance = 112.0;

  /// Largeur maximale du contenu sur grand écran.
  static const maxContentWidth = 720.0;
}

abstract final class AppRadius {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutBack;
}
