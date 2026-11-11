import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../data/onboarding_provider.dart';
import '../../domain/models/lifestyle_options.dart';
import '../widgets/onboarding_progress_header.dart';

/// Onboarding Schritt 2 — Ernährung, Lebensstil & Medikamente (optional)
class OnboardingStep2Screen extends ConsumerStatefulWidget {
  const OnboardingStep2Screen({super.key});

  @override
  ConsumerState<OnboardingStep2Screen> createState() =>
      _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState
    extends ConsumerState<OnboardingStep2Screen> {
  final _medicationController = TextEditingController();
  final List<String> _medications = [];

  @override
  void dispose() {
    _medicationController.dispose();
    super.dispose();
  }

  void _addMedication() {
    final text = _medicationController.text.trim();
    if (text.isNotEmpty && !_medications.contains(text)) {
      setState(() {
        _medications.add(text);
        _medicationController.clear();
      });
    }
  }

  Future<void> _finish() async {
    final notifier = ref.read(onboardingProvider.notifier);
    notifier.updateMedications(_medications);
    await notifier.completeOnboarding();
    if (mounted) {
      context.go('${AppRoutes.profileRecommendations}?from=onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressHeader(currentStep: 2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppConstants.spaceL),
                    Text('Ernährung & Alltag',
                        style: AppTextStyles.displayMedium),
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      'Optional — aber so erkennen wir, welche Nährstoffe '
                      'bei dir am ehesten zu kurz kommen.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Ernährungsform (eine) ---
                    _ChipSection(
                      title: 'Wie ernährst du dich?',
                      subtitle: 'Wähle eine Ernährungsform.',
                      options: kDietOptions,
                      selected: profile.lifestyle,
                      onTap: (o) =>
                          ref.read(onboardingProvider.notifier).setDiet(o),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Essgewohnheiten (mehrere) ---
                    _ChipSection(
                      title: 'Essgewohnheiten',
                      subtitle: 'Wähle alles aus, was zutrifft.',
                      options: kEatingHabitOptions,
                      selected: profile.lifestyle,
                      onTap: (o) => ref
                          .read(onboardingProvider.notifier)
                          .toggleLifestyle(o),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Alltag (mehrere) ---
                    _ChipSection(
                      title: 'Dein Alltag',
                      subtitle: 'Wähle alles aus, was zutrifft.',
                      options: kDailyLifeOptions,
                      selected: profile.lifestyle,
                      onTap: (o) => ref
                          .read(onboardingProvider.notifier)
                          .toggleLifestyle(o),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // --- Schwangerschaft (nur wenn weiblich/divers) ---
                    if (profile.gender != null &&
                        profile.gender!.name != 'male') ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Schwangerschaft / Stillzeit',
                                    style: AppTextStyles.headlineSmall),
                                Text(
                                  'Beeinflusst den Nährstoffbedarf stark.',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: profile.isPregnant,
                            activeColor: AppColors.primary,
                            onChanged: (v) => ref
                                .read(onboardingProvider.notifier)
                                .setIsPregnant(v),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spaceXL),
                    ],

                    // --- Medikamente ---
                    Text('Dauermedikamente', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      'z.B. Levothyroxin, Metoprolol, Metformin. '
                      'Wir prüfen Wechselwirkungen.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _medicationController,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Medikament eingeben...',
                            ),
                            onSubmitted: (_) => _addMedication(),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        FilledButton.tonal(
                          onPressed: _addMedication,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(52, 52),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),

                    if (_medications.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      Wrap(
                        spacing: AppConstants.spaceS,
                        runSpacing: AppConstants.spaceS,
                        children: _medications
                            .map((med) => Chip(
                                  label: Text(med),
                                  deleteIcon: const Icon(Icons.close,
                                      size: 16),
                                  onDeleted: () => setState(
                                      () => _medications.remove(med)),
                                ))
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: AppConstants.spaceXXL),
                  ],
                ),
              ),
            ),

            // Überspringen möglich — dieser Schritt ist optional
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingH),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _finish,
                    child: const Text('Profil erstellen & starten'),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Überspringen',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Überschrift + Untertitel + Chip-Wrap für eine Auswahlgruppe.
class _ChipSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onTap;

  const _ChipSection({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppConstants.spaceS),
        Text(subtitle, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppConstants.spaceM),
        Wrap(
          spacing: AppConstants.spaceS,
          runSpacing: AppConstants.spaceS,
          children: options
              .map((o) => _ConditionChip(
                    label: o,
                    selected: selected.contains(o),
                    onTap: () => onTap(o),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
