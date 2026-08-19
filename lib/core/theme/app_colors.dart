import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primärfarben ── Navy-Blau des "Meine Ziele" Panels
  static const Color primary      = Color(0xFF1A3A6B); // Panel-Navy
  static const Color primaryLight = Color(0xFF2B5490); // aufgehelltes Panel-Navy
  static const Color primaryDark  = Color(0xFF0D2040); // tiefstes Mitternachts-Navy

  // ── Akzentfarben ── funktioniert auf hellem Navy-Hintergrund
  static const Color accent      = Color(0xFF4D8FE0); // helles Signalblau
  static const Color accentLight = Color(0xFFDBEAFB); // sehr helles Blau für Highlights

  // ── Hintergrund ── gleicher Navy-Ton wie Panel, deutlich aufgehellt
  static const Color background     = Color(0xFFC5D8EB); // helles Navy-Periwinkle
  static const Color surface        = Color(0xFFE8F1FA); // Evidenz-Karten: leichtes Navy
  static const Color surfaceVariant = Color(0xFFD5E6F3); // sekundäre Flächen, etwas tiefer

  // ── Rahmen & Trennlinien ── Navy-getönt
  static const Color border  = Color(0xFF8AABC8); // gedämpfte Navy-Kontur
  static const Color divider = Color(0xFF9FBFD9); // Navy-Trennlinie

  // ── Textfarben ── Navy-Familie, gut lesbar auf hellem Navy-Hintergrund
  static const Color textPrimary   = Color(0xFF0D2040); // tiefstes Panel-Navy
  static const Color textSecondary = Color(0xFF253D62); // gedämpftes Navy
  static const Color textTertiary  = Color(0xFF4D6B8A); // helles Navy-Grau
  static const Color textInverse   = Color(0xFFFFFFFF); // weiß auf dunklen Flächen

  // ── Evidenzampel (semantisch – Light-Töne navy-getönt statt reinem Weiß)
  static const Color evidenceGreen      = Color(0xFF059669);
  static const Color evidenceGreenLight = Color(0xFFD4EEE6); // navy-getöntes Grün-Hell
  static const Color evidenceGreenBadge = Color(0xFF10B981);
  static const Color evidenceYellow      = Color(0xFFD97706);
  static const Color evidenceYellowLight = Color(0xFFEDE8D5); // navy-getöntes Amber-Hell
  static const Color evidenceYellowBadge = Color(0xFFF59E0B);
  static const Color evidenceRed         = Color(0xFFDC2626);
  static const Color evidenceRedLight    = Color(0xFFEDD8D8); // navy-getöntes Rot-Hell
  static const Color evidenceRedBadge    = Color(0xFFEF4444);

  // ── Semantische Farben
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error   = Color(0xFFDC2626);
  static const Color info    = Color(0xFF4D8FE0);

  // ── Gamification
  static const Color xpGold   = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  // ── Primär-Gradient ── Panel-Navy für Header & prominente Flächen
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark], // #1A3A6B → #0D2040
  );

  // ── Akzent-Gradient (für spezielle Cards / Highlights)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primaryDark], // #4D8FE0 → #0D2040
  );

  // ── Schatten ── Navy-getönter Schatten
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0D2040).withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0D2040).withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // ── Stärkerer Schatten für floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0D2040).withOpacity(0.22),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0D2040).withOpacity(0.07),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}
