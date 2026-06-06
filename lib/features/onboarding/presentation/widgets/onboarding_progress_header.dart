import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';

/// Fortschrittsanzeige oben in jedem Onboarding-Screen.
/// Zeigt Schritt-Nummer, Gesamtschritte und einen animierten Progress-Balken.
class OnboardingProgressHeader extends StatelessWidget {
  final int currentStep; // 1-basiert

  const OnboardingProgressHeader({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / AppConstants.onboardingTotalSteps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.spaceM,
        AppConstants.screenPaddingH,
        AppConstants.spaceS,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Zurück-Button (außer auf Step 1)
              if (currentStep > 1)
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusS),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 16, color: AppColors.textSecondary),
                  ),
                )
              else
                const SizedBox(width: 36),

              const Spacer(),

              Text(
                'Schritt $currentStep von ${AppConstants.onboardingTotalSteps}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),
              const SizedBox(width: 36), // Symmetrie
            ],
          ),

          const SizedBox(height: AppConstants.spaceM),

          // Animierter Progress-Balken
          ClipRRect(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusRound),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AppConstants.animNormal,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
