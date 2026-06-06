import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';

/// Erster Screen — Willkommen bei StackSense.
/// Erklärt den Nutzen in 3 Bullet Points, dann CTA zum Onboarding.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH,
              vertical: AppConstants.screenPaddingV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Logo / Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusL),
                  ),
                  child: const Icon(
                    Icons.science_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceL),

                // Headline
                Text(
                  'Supplements,\ndie wirklich\nzu dir passen.',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceM),

                Text(
                  'Evidenzbasierte Empfehlungen — '
                  'personalisiert auf deinen Körper, '
                  'deine Ziele und deine Situation.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),

                const SizedBox(height: AppConstants.spaceXL),

                // Feature-Punkte
                ...[
                  (Icons.verified_outlined, 'Nur mit echter Evidenz'),
                  (Icons.person_outline, 'Personalisiert auf dein Profil'),
                  (Icons.notifications_none, 'Tägliche Einnahme-Begleitung'),
                ].map((item) => Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppConstants.spaceM),
                      child: _FeatureRow(
                        icon: item.$1,
                        label: item.$2,
                      ),
                    )),

                const Spacer(),

                // CTA Button
                FilledButton(
                  onPressed: () =>
                      context.go(AppRoutes.onboardingStep1),
                  child: const Text('Profil erstellen'),
                ),

                const SizedBox(height: AppConstants.spaceM),

                // Datenschutz-Hinweis
                Center(
                  child: Text(
                    'Deine Gesundheitsdaten bleiben auf deinem Gerät.',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceS),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius:
                BorderRadius.circular(AppConstants.radiusS),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
