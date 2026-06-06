import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/onboarding_provider.dart';
import '../widgets/onboarding_progress_header.dart';

/// Onboarding Schritt 3 — Ziele auswählen
/// Der Nutzer aktiviert Problembereiche, für die er Empfehlungen möchte.
class OnboardingStep3Screen extends ConsumerStatefulWidget {
  const OnboardingStep3Screen({super.key});

  @override
  ConsumerState<OnboardingStep3Screen> createState() =>
      _OnboardingStep3ScreenState();
}

class _OnboardingStep3ScreenState
    extends ConsumerState<OnboardingStep3Screen> {
  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final hasGoals = profile.goals.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressHeader(currentStep: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppConstants.spaceL),
                    Text('Deine Ziele', style: AppTextStyles.displayMedium),
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      'Wähle aus, wofür du Empfehlungen möchtest. '
                      'Du kannst das jederzeit ändern.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // Ziele als 2-spaltige Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppConstants.spaceS,
                      mainAxisSpacing: AppConstants.spaceS,
                      childAspectRatio: 1.6,
                      children: _goals.map((goal) {
                        final selected =
                            profile.goals.contains(goal.label);
                        return _GoalCard(
                          icon: goal.icon,
                          label: goal.label,
                          selected: selected,
                          onTap: () => ref
                              .read(onboardingProvider.notifier)
                              .toggleGoal(goal.label),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppConstants.spaceXXL),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppConstants.screenPaddingH),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: hasGoals ? _finish : null,
                    child: const Text('Profil erstellen & starten'),
                  ),
                  if (!hasGoals) ...[
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      'Bitte wähle mindestens ein Ziel aus.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const Spacer(),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalData {
  final IconData icon;
  final String label;
  const _GoalData(this.icon, this.label);
}

const _goals = [
  _GoalData(Icons.bolt_outlined, 'Mehr Energie'),
  _GoalData(Icons.bedtime_outlined, 'Besserer Schlaf'),
  _GoalData(Icons.psychology_outlined, 'Fokus & Konzentration'),
  _GoalData(Icons.fitness_center_outlined, 'Sport & Regeneration'),
  _GoalData(Icons.shield_outlined, 'Immunsystem stärken'),
  _GoalData(Icons.mood_outlined, 'Stimmung & Wohlbefinden'),
  _GoalData(Icons.favorite_outline, 'Herzgesundheit'),
  _GoalData(Icons.spa_outlined, 'Haut & Haare'),
  _GoalData(Icons.scale_outlined, 'Gewichtsmanagement'),
  _GoalData(Icons.elderly_outlined, 'Gelenkgesundheit'),
  _GoalData(Icons.female, 'Frauengesundheit / Zyklus'),
  _GoalData(Icons.science_outlined, 'Hormonbalance'),
];
