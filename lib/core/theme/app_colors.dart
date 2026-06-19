import 'package:flutter/material.dart';

/// StackSense Design System — Farben
///
/// Primärpalette: Deep Blue (Brand), Emerald/Amber/Red (Evidenzampel)
/// Immer diese Konstanten verwenden, niemals hardcodierte Hex-Werte im UI-Code.
class AppColors {
  AppColors._();

  // --- Brand ---
  static const Color primary = Color(0xFF1B3A6B);      // Deep Blue
  static const Color primaryLight = Color(0xFF2952A3);  // Vibrant Blue
  static const Color primaryDark = Color(0xFF0D1E3A);   // Near Black Blue
  static const Color accent = Color(0xFF3B82F6);        // Bright Blue für CTAs
  static const Color accentLight = Color(0xFFEFF6FF);   // Sehr helles Blau

  // --- Evidenzampel (moderner, satter) ---
  static const Color evidenceGreen = Color(0xFF059669);       // Emerald
  static const Color evidenceGreenLight = Color(0xFFECFDF5);
  static const Color evidenceGreenBadge = Color(0xFF10B981);

  static const Color evidenceYellow = Color(0xFFD97706);      // Amber
  static const Color evidenceYellowLight = Color(0xFFFFFBEB);
  static const Color evidenceYellowBadge = Color(0xFFF59E0B);

  static const Color evidenceRed = Color(0xFFDC2626);         // Modern Red
  static const Color evidenceRedLight = Color(0xFFFEF2F2);
  static const Color evidenceRedBadge = Color(0xFFEF4444);

  // --- Neutrals (leicht blau getönt für Frische) ---
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2F9);
  static const Color border = Color(0xFFDDE3EF);
  static const Color divider = Color(0xFFEEF2F9);

  // --- Text (Slate-Töne, moderner als reines Grau) ---
  static const Color textPrimary = Color(0xFF0F172A);    // Slate 900
  static const Color textSecondary = Color(0xFF475569);  // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8);   // Slate 400
  static const Color textInverse = Color(0xFFFFFFFF);

  // --- Status ---
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // --- XP / Gamification ---
  static const Color xpGold = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  // --- Gradient (satter, von vibrant zu dunkel) ---
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark],
  );

  // --- Subtiler Karten-Schatten ---
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1B3A6B).withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF1B3A6B).withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}
