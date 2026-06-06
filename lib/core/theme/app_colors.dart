import 'package:flutter/material.dart';

/// StackSense Design System — Farben
///
/// Primärpalette: Navy (Brand), Grün/Gelb/Rot (Evidenzampel)
/// Immer diese Konstanten verwenden, niemals hardcodierte Hex-Werte im UI-Code.
class AppColors {
  AppColors._();

  // --- Brand ---
  static const Color primary = Color(0xFF1A2744); // Navy
  static const Color primaryLight = Color(0xFF2A3F6B);
  static const Color primaryDark = Color(0xFF0D1526);
  static const Color accent = Color(0xFF4A90D9); // Hellblau für CTAs

  // --- Evidenzampel ---
  static const Color evidenceGreen = Color(0xFF2E7D32); // Belegt
  static const Color evidenceGreenLight = Color(0xFFE8F5E9);
  static const Color evidenceGreenBadge = Color(0xFF43A047);

  static const Color evidenceYellow = Color(0xFFF57F17); // Hinweise
  static const Color evidenceYellowLight = Color(0xFFFFFDE7);
  static const Color evidenceYellowBadge = Color(0xFFFFA000);

  static const Color evidenceRed = Color(0xFFC62828); // Unbewiesen
  static const Color evidenceRedLight = Color(0xFFFFEBEE);
  static const Color evidenceRedBadge = Color(0xFFE53935);

  // --- Neutrals ---
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F8);
  static const Color border = Color(0xFFE0E4EF);
  static const Color divider = Color(0xFFEEF0F5);

  // --- Text ---
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  // --- Status ---
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // --- XP / Gamification ---
  static const Color xpGold = Color(0xFFFFB300);
  static const Color xpSilver = Color(0xFF9E9E9E);
  static const Color xpBronze = Color(0xFF8D6E63);

  // --- Gradient (Onboarding / Splash) ---
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark],
  );
}
