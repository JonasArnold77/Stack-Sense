import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primärfarben ── exakt das dunkle Marineblau aus dem Logo-Hexagon
  // (#162E52) als Basis, Light/Dark-Varianten davon abgeleitet (gleicher
  // Farbton, nur Helligkeit verschoben) statt eines helleren Extra-Blaus.
  static const Color primary      = Color(0xFF162E52); // Logo-Marineblau
  static const Color primaryLight = Color(0xFF2C5BA2); // gleicher Ton, heller
  static const Color primaryDark  = Color(0xFF091322); // gleicher Ton, fast Schwarzblau

  // ── Header-Ton ── derselbe Farbton wie primary/primaryLight, nur GANZ
  // LEICHT dunkler (~5% Lightness) als die Foundation-Kachel (primaryLight
  // → primary). Genutzt vom globalen Header (primaryGradient) UND der
  // Optimization-Kachel, die bewusst exakt dieselbe Farbe wie der Header
  // haben soll — dadurch wirken beide Home-Screen-Kacheln fast identisch,
  // Optimization nur minimal dunkler als Foundation.
  static const Color headerLight = Color(0xFF27508E); // primaryLight, ~5% dunkler
  static const Color headerDark  = Color(0xFF11233E); // primary, ~5% dunkler

  // ── Akzentfarben ── elektrisches Blau für CTAs
  static const Color accent      = Color(0xFF1967FF); // leuchtend elektrisch blau
  static const Color accentLight = Color(0xFFE4EFFF); // sehr helles Blau für Highlights

  // ── Hintergrund ── klares, eindeutig blaues Background
  static const Color background     = Color(0xFFB8D4F6); // vivid clear sky blue
  static const Color surface        = Color(0xFFFFFFFF); // rein weiß — Karten poppen ab
  static const Color surfaceVariant = Color(0xFFEAF2FF); // leichtes Blau für sekundäre Flächen

  // ── Rahmen & Trennlinien ── blau getönt
  static const Color border  = Color(0xFF99BCE0);
  static const Color divider = Color(0xFFB0CDE8);

  // ── Textfarben ── blaugetönte Grautöne für mehr Harmonie
  static const Color textPrimary   = Color(0xFF0D1B3E); // tiefdunkles Blau-Schwarz
  static const Color textSecondary = Color(0xFF2F4F79); // gedämpftes Mittelblau
  static const Color textTertiary  = Color(0xFF6B8CB8); // helles Blau-Grau
  static const Color textInverse   = Color(0xFFFFFFFF); // weiß auf dunklen Flächen

  // ── Evidenzampel (semantisch — bewusst UNVERÄNDERT trotz Marineblau-
  // Rebranding, da grün/gelb/rot hier eine eigene, von der Markenfarbe
  // unabhängige Bedeutung tragen — Verwechslung mit der Markenfarbe wäre
  // kontraproduktiv)
  static const Color evidenceGreen      = Color(0xFF059669);
  static const Color evidenceGreenLight = Color(0xFFD4EEE6);
  static const Color evidenceGreenBadge = Color(0xFF10B981);
  static const Color evidenceYellow      = Color(0xFFD97706);
  static const Color evidenceYellowLight = Color(0xFFEDE8D5);
  static const Color evidenceYellowBadge = Color(0xFFF59E0B);
  static const Color evidenceRed         = Color(0xFFDC2626);
  static const Color evidenceRedLight    = Color(0xFFEDD8D8);
  static const Color evidenceRedBadge    = Color(0xFFEF4444);

  // ── Semantische Farben
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error   = Color(0xFFDC2626);
  static const Color info    = Color(0xFF1967FF);

  // ── Gamification (Medaillen-Metapher — bewusst unverändert)
  static const Color xpGold   = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  // ── Home-Screen-Panel-Töne — bewusst LEICHT unterschiedliche Blau-Nuancen
  // für Nachbar-Panels auf dem Heute-Screen, statt überall exakt derselbe
  // Flächenton (AppColors.surface). Alle nah beieinander (kein Kontrast-
  // Bruch), aber erkennbar different genug für optische Abwechslung.
  static const Color panelTintSky     = Color(0xFFEAF3FE);
  static const Color panelTintAzure   = Color(0xFFE6F0FC);
  static const Color panelTintSteel   = Color(0xFFE9F0FA);
  static const Color panelTintCobalt  = Color(0xFFE3EDFC);

  // ── Primär-Gradient ── identisch zur Optimization-Kachel (headerLight →
  // headerDark), für Header & prominente Flächen.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [headerLight, headerDark], // #27508E → #11233E
  );

  // ── Akzent-Gradient (für spezielle Cards / Highlights)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryDark], // #1967FF → #091322
  );

  // ── Schatten ── blaugetönter Schatten für mehr Tiefe
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: primary.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Stärkerer Schatten für floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primary.withOpacity(0.18),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: primary.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
