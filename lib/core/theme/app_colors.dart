import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primärfarben ── tiefes Teal-Grün, das App-Markenfarbe
  static const Color primary      = Color(0xFF146356); // Teal-Forest
  static const Color primaryLight = Color(0xFF1F8A75); // aufgehelltes Teal-Grün
  static const Color primaryDark  = Color(0xFF0A3D34); // tiefstes Nacht-Grün

  // ── Akzentfarben ── funktioniert auf hellem Grün-Hintergrund
  static const Color accent      = Color(0xFF2FAE8B); // frisches Signal-Grün
  static const Color accentLight = Color(0xFFDCF3EC); // sehr helles Mint für Highlights

  // ── Hintergrund ── gleicher Grün-Ton wie Panel, deutlich aufgehellt
  static const Color background     = Color(0xFFDCEEE7); // helles Salbei-Mint
  static const Color surface        = Color(0xFFEEF7F3); // Evidenz-Karten: leichtes Salbei
  static const Color surfaceVariant = Color(0xFFDFF0E9); // sekundäre Flächen, etwas tiefer

  // ── Rahmen & Trennlinien ── Grün-getönt
  static const Color border  = Color(0xFF9FC7BA); // gedämpfte Salbei-Kontur
  static const Color divider = Color(0xFFB8DCD0); // Salbei-Trennlinie

  // ── Textfarben ── Grün-Familie, gut lesbar auf hellem Grün-Hintergrund
  static const Color textPrimary   = Color(0xFF0A3D34); // tiefstes Nacht-Grün
  static const Color textSecondary = Color(0xFF1F5449); // gedämpftes Grün
  static const Color textTertiary  = Color(0xFF4D8A79); // helles Grün-Grau
  static const Color textInverse   = Color(0xFFFFFFFF); // weiß auf dunklen Flächen

  // ── Evidenzampel (semantisch — bewusst UNVERÄNDERT trotz Grün-Rebranding,
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
  static const Color info    = Color(0xFF2FAE8B);

  // ── Gamification (Medaillen-Metapher — bewusst unverändert)
  static const Color xpGold   = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  // ── Home-Screen-Panel-Töne — bewusst LEICHT unterschiedliche Grün-Nuancen
  // für Nachbar-Panels auf dem Heute-Screen, statt überall exakt derselbe
  // Flächenton (AppColors.surface). Alle nah beieinander (kein Kontrast-
  // Bruch), aber erkennbar different genug für optische Abwechslung.
  static const Color panelTintMint    = Color(0xFFE6F5EF); // kühles Minz-Grün
  static const Color panelTintSage    = Color(0xFFEAF2E4); // warmes Salbei-Grün
  static const Color panelTintMoss    = Color(0xFFE3F0E9); // gedämpftes Moos-Grün
  static const Color panelTintEmerald = Color(0xFFE0F2EA); // klares Smaragd-Grün

  // ── Primär-Gradient ── Panel-Teal für Header & prominente Flächen
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark], // #146356 → #0A3D34
  );

  // ── Akzent-Gradient (für spezielle Cards / Highlights)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryDark], // #2FAE8B → #0A3D34
  );

  // ── Schatten ── Grün-getönter Schatten
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0A3D34).withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0A3D34).withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Stärkerer Schatten für floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0A3D34).withOpacity(0.22),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0A3D34).withOpacity(0.07),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
