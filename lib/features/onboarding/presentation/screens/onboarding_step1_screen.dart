import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/onboarding_provider.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/onboarding_progress_header.dart';

/// Onboarding Schritt 1 — Basis-Parameter: Alter, Geschlecht, Sport
class OnboardingStep1Screen extends ConsumerStatefulWidget {
  const OnboardingStep1Screen({super.key});

  @override
  ConsumerState<OnboardingStep1Screen> createState() =>
      _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState
    extends ConsumerState<OnboardingStep1Screen> {
  final _ageController = TextEditingController();
  Gender? _selectedGender;
  SportLevel? _selectedSportLevel;

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _ageController.text.isNotEmpty &&
      int.tryParse(_ageController.text) != null &&
      _selectedGender != null &&
      _selectedSportLevel != null;

  void _continue() {
    if (!_isValid) return;

    final notifier = ref.read(onboardingProvider.notifier);
    notifier.updateAge(int.parse(_ageController.text));
    notifier.updateGender(_selectedGender!);
    notifier.updateSportLevel(_selectedSportLevel!);

    context.go(AppRoutes.onboardingStep2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressHeader(currentStep: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppConstants.spaceL),

                    Text(
                      'Dein Basis-Profil',
                      style: AppTextStyles.displayMedium,
                    ),
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      'Diese Angaben helfen uns, die Basis-Supplementierung '
                      'für dich zu kalibrieren.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Alter ---
                    Text('Wie alt bist du?',
                        style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppConstants.spaceM),
                    TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'z.B. 32',
                        suffixText: 'Jahre',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Geschlecht ---
                    Text('Biologisches Geschlecht',
                        style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      'Relevant für hormonsensitive Nährstoffbedarfe.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Row(
                      children: [
                        _GenderChip(
                          label: 'Männlich',
                          icon: Icons.male,
                          selected: _selectedGender == Gender.male,
                          onTap: () => setState(
                              () => _selectedGender = Gender.male),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        _GenderChip(
                          label: 'Weiblich',
                          icon: Icons.female,
                          selected: _selectedGender == Gender.female,
                          onTap: () => setState(
                              () => _selectedGender = Gender.female),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        _GenderChip(
                          label: 'Divers',
                          icon: Icons.transgender,
                          selected: _selectedGender == Gender.diverse,
                          onTap: () => setState(
                              () => _selectedGender = Gender.diverse),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Sport ---
                    Text('Wie aktiv bist du?',
                        style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppConstants.spaceM),
                    ..._sportOptions.map((option) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppConstants.spaceS),
                          child: _SportOption(
                            title: option.title,
                            subtitle: option.subtitle,
                            level: option.level,
                            selected:
                                _selectedSportLevel == option.level,
                            onTap: () => setState(
                                () => _selectedSportLevel = option.level),
                          ),
                        )),

                    const SizedBox(height: AppConstants.spaceXXL),
                  ],
                ),
              ),
            ),

            // --- CTA ---
            Padding(
              padding: const EdgeInsets.all(AppConstants.screenPaddingH),
              child: FilledButton(
                onPressed: _isValid ? _continue : null,
                child: const Text('Weiter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Sub-Widgets ----

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected
                      ? AppColors.textInverse
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final SportLevel level;
  final bool selected;
  final VoidCallback onTap;

  const _SportOption({
    required this.title,
    required this.subtitle,
    required this.level,
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
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// --- Daten für Sport-Optionen ---
class _SportData {
  final String title;
  final String subtitle;
  final SportLevel level;
  const _SportData(this.title, this.subtitle, this.level);
}

const _sportOptions = [
  _SportData('Kaum aktiv', 'Wenig Bewegung im Alltag, kein Sport', SportLevel.none),
  _SportData('Leicht aktiv', '1–2x Sport pro Woche oder viel Gehen', SportLevel.light),
  _SportData('Moderat aktiv', '3–4x Sport pro Woche', SportLevel.moderate),
  _SportData('Sehr aktiv', '5+ Trainings pro Woche, intensiver Sport', SportLevel.intense),
];
