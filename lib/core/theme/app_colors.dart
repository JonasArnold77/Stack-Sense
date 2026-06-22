import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1B3A6B);
  static const Color primaryLight = Color(0xFF2952A3);
  static const Color primaryDark = Color(0xFF0D1E3A);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentLight = Color(0xFFEFF6FF);

  static const Color evidenceGreen = Color(0xFF059669);
  static const Color evidenceGreenLight = Color(0xFFECFDF5);
  static const Color evidenceGreenBadge = Color(0xFF10B981);
  static const Color evidenceYellow = Color(0xFFD97706);
  static const Color evidenceYellowLight = Color(0xFFFFFBEB);
  static const Color evidenceYellowBadge = Color(0xFFF59E0B);
  static const Color evidenceRed = Color(0xFFDC2626);
  static const Color evidenceRedLight = Color(0xFFFEF2F2);
  static const Color evidenceRedBadge = Color(0xFFEF4444);

  static const Color background = Color(0xFFDEEAF8);
  static const Color surface = Color(0xFFF2F7FF);
  static const Color surfaceVariant = Color(0xFFE4EEFA);
  static const Color border = Color(0xFFC4D5EC);
  static const Color divider = Color(0xFFD3E3F4);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  static const Color xpGold = Color(0xFFF59E0B);
  static const Color xpSilver = Color(0xFF94A3B8);
  static const Color xpBronze = Color(0xFF92400E);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark],
  );

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
