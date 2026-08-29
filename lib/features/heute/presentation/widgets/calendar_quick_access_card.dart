import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Prominenter Schnellzugriff auf den Einnahme-Kalender (Kalender-Tab in
/// StackScreen) direkt vom Heute-Screen aus — bisher nur über "Mein Stack" →
/// zweiten Tab erreichbar, ohne eigenen Einstiegspunkt.
class CalendarQuickAccessCard extends StatelessWidget {
  const CalendarQuickAccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('${AppRoutes.stack}?tab=calendar'),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withOpacity(0.09),
              AppColors.primary.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.accent.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Einnahme-Kalender',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Wochenplan ansehen & Mengen eintragen →',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceS),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
