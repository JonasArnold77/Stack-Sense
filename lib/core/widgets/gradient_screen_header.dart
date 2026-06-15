import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';

/// Wiederverwendbarer Gradient-Header für alle Haupt-Screens.
/// Stellt die visuelle Verbindung zum Welcome/Onboarding-Screen her.
///
/// Wird als erstes Element in einem [Column] oder [CustomScrollView] eingesetzt.
/// Setzt automatisch die Statusbar-Icons auf Weiß (hell auf dunkel).
class GradientScreenHeader extends StatelessWidget {
  /// Haupttitel (z.B. "Entdecken")
  final String title;

  /// Optionaler Untertitel (z.B. "Personalisierte Empfehlungen")
  final String? subtitle;

  /// Optionale Action-Icons rechts (z.B. IconButton)
  final List<Widget> actions;

  /// Optionaler Inhalt unterhalb von Titel (z.B. TabBar, Chips)
  final Widget? bottom;

  /// Innenabstand unten — kleiner wenn [bottom] vorhanden
  final double bottomPadding;

  const GradientScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.bottomPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        padding: EdgeInsets.only(
          top: topPadding + AppConstants.spaceM,
          left: AppConstants.screenPaddingH,
          right: AppConstants.screenPaddingH,
          bottom: bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zeile: Titel + Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.68),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: AppConstants.spaceS),
                  ...actions,
                ],
              ],
            ),
            // Optionaler Bottom-Bereich (z.B. TabBar, Chips)
            if (bottom != null) ...[
              const SizedBox(height: AppConstants.spaceM),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Kompakter Icon-Button für die Gradient-Header Actions (weiß).
class GradientHeaderAction extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const GradientHeaderAction({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.12),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

/// Pill-Badge für den Gradient-Header (z.B. "3 Supplements").
class GradientHeaderBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const GradientHeaderBadge({
    super.key,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white.withOpacity(0.85)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
