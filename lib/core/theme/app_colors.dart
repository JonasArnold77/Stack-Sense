import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primärfarben ── Lime Green, die App-Markenfarbe
  static const Color primary      = Color(0xFF4D7C0F); // Lime-700 — dunkel genug für weißen Text
  static const Color primaryLight = Color(0xFF65A30D); // Lime-600
  static const Color primaryDark  = Color(0xFF365314); // Lime-900 — tiefstes Oliv-Grün

  // ── Akzentfarben ── funktioniert auf hellem Lime-Hintergrund
  static const Color accent      = Color(0xFF84CC16); // Lime-500 — kräftiges Signal-Lime
  static const Color accentLight = Color(0xFFECFCCB); // Lime-100 — sehr helles Lime für Highlights

  // ── Hintergrund ── heller Lime-Ton
  static const Color background     = Color(0xFFF7FEE7); // Lime-50
  static const Color surface        = Color(0xFFFBFEF3); // fast weiß, leichter Lime-Schimmer
  static const Color surfaceVariant = Color(0xFFF1F8DC); // sekundäre Flächen, etwas tiefer

  // ── Rahmen & Trennlinien ── Lime-getönt, gedämpft
  static const Color border  = Color(0xFFD9E9AE);
  static const Color divider = Color(0xFFE3EFC4);

  // ── Textfarben ── Lime-Familie, gut lesbar auf hellem Lime-Hintergrund
  static const Color textPrimary   = Color(0xFF1F2E05); // sehr dunkles Oliv für Kontrast
  static const Color textSecondary = Color(0xFF3F5212);
  static const Color textTertiary  = Color(0xFF6B7F4A);
  static const Color textInverse   = Color(0xFFFFFFFF); // weiß auf dunklen Flächen

  // ── Evidenzampel (semantisch — bewusst UNVERÄNDERT trotz Lime-Rebranding,
  // da grün/gelb/rot hier eine eigene, von der Markenfarbe unabhängige
  // Bedeutung tragen — Verwechslung mit der Markenfarbe wäre kontraproduktiv)
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
  static const Color info    = Color(0xFF84CC16);

  // ── Gamification (Medaillen-Metapher — bewusst unverändert)
  static const Color xpGold   = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  // ── Home-Screen-Panel-Töne — bewusst LEICHT unterschiedliche Lime-Nuancen
  // für Nachbar-Panels auf dem Heute-Screen, statt überall exakt derselbe
  // Flächenton (AppColors.surface). Alle nah beieinander (kein Kontrast-
  // Bruch), aber erkennbar different genug für optische Abwechslung.
  static const Color panelTintMint    = Color(0xFFEFFAE0);
  static const Color panelTintSage    = Color(0xFFF2F8E0);
  static const Color panelTintMoss    = Color(0xFFEFF6DB);
  static const Color panelTintEmerald = Color(0xFFEBF7DC);

  // ── Primär-Gradient ── Lime für Header & prominente Flächen
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark], // #4D7C0F → #365314
  );

  // ── Akzent-Gradient (für spezielle Cards / Highlights)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryDark], // #84CC16 → #365314
  );

  // ── Schatten ── Lime-getönter Schatten
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF365314).withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF365314).withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Stärkerer Schatten für floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF365314).withOpacity(0.22),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF365314).withOpacity(0.07),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
