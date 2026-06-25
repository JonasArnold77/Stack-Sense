import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primärfarben ── vivides Marineblau mit mehr Sättigung
  static const Color primary      = Color(0xFF1746A2); // sattes Mittelblau
  static const Color primaryLight = Color(0xFF2D60CE); // heller, leuchtendes Blau
  static const Color primaryDark  = Color(0xFF0A2060); // tiefes Mitternachtsblau

  // ── Akzentfarben ── elektrisches Blau für CTAs
  static const Color accent      = Color(0xFF1967FF); // leuchtend elektrisch blau
  static const Color accentLight = Color(0xFFE4EFFF); // sehr helles Blau für Highlights

  // ── Hintergrund ── klares, eindeutig blaues Background
  static const Color background     = Color(0xFFB8D4F6); // vivid clear sky blue
  static const Color surface        = Color(0xFFFFFFFF); // rein weiß – Karten poppen ab
  static const Color surfaceVariant = Color(0xFFEAF2FF); // leichtes Blau für sekundäre Flächen

  // ── Rahmen & Trennlinien
  static const Color border  = Color(0xFF99BCE0); // blaue Konturlinien
  static const Color divider = Color(0xFFB0CDE8); // blaue Trennlinien

  // ── Textfarben ── blaugetönte Grautöne für mehr Harmonie
  static const Color textPrimary   = Color(0xFF0D1B3E); // tiefdunkles Blau-Schwarz
  static const Color textSecondary = Color(0xFF2F4F79); // gedämpftes Mittelblau
  static const Color textTertiary  = Color(0xFF6B8CB8); // helles Blau-Grau
  static const Color textInverse   = Color(0xFFFFFFFF); // weiß auf dunklen Flächen

  // ── Evidenzampel (semantisch – keine Änderung)
  static const Color evidenceGreen      = Color(0xFF059669);
  static const Color evidenceGreenLight = Color(0xFFECFDF5);
  static const Color evidenceGreenBadge = Color(0xFF10B981);
  static const Color evidenceYellow      = Color(0xFFD97706);
  static const Color evidenceYellowLight = Color(0xFFFFFBEB);
  static const Color evidenceYellowBadge = Color(0xFFF59E0B);
  static const Color evidenceRed         = Color(0xFFDC2626);
  static const Color evidenceRedLight    = Color(0xFFFEF2F2);
  static const Color evidenceRedBadge    = Color(0xFFEF4444);

  // ── Semantische Farben
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error   = Color(0xFFDC2626);
  static const Color info    = Color(0xFF1967FF);

  // ── Gamification
  static const Color xpGold   = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  // ── Primär-Gradient ── vivides Tiefen-Blau für Header
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark], // #2D60CE → #0A2060
  );

  // ── Akzent-Gradient (für spezielle Cards / Highlights)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryDark], // #1967FF → #0A2060
  );

  // ── Schatten ── blaugetönter Schatten für mehr Tiefe
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1746A2).withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF1746A2).withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Stärkerer Schatten für floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF1746A2).withOpacity(0.18),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF1746A2).withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
