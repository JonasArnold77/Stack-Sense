import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';
import '../widgets/evidence_card.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../onboarding/data/onboarding_provider.dart';

/// Entdecken-Screen — Ziel auswählen → Claude liefert Empfehlungen.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState
    extends ConsumerState<RecommendationsScreen> {
  String? _selectedGoal;
  List<Supplement>? _supplements;
  bool _isLoading = false;
  String? _error;

  Future<void> _loadRecommendations(String goal) async {
    setState(() {
      _selectedGoal = goal;
      _isLoading = true;
      _error = null;
      _supplements = null;
    });

    final profile = ref.read(onboardingProvider);

    try {
      final results = await ApiService.instance.getRecommendations(
        profile: profile,
        goal: goal,
      );
      if (mounted) {
        setState(() {
          _supplements = results;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stackNotifier = ref.read(stackProvider.notifier);
    final stack = ref.watch(stackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _GoalSelector(
            selectedGoal: _selectedGoal,
            onSelect: _loadRecommendations,
          ),
        ),
      ),
      body: _buildBody(stackNotifier, stack),
    );
  }

  Widget _buildBody(StackNotifier stackNotifier, List stack) {
    // 1. Noch kein Ziel gewählt
    if (_selectedGoal == null) return const _EmptyState();

    // 2. Lädt
    if (_isLoading) return const _LoadingState();

    // 3. Fehler
    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: () => _loadRecommendations(_selectedGoal!),
      );
    }

    // 4. Ergebnisse
    final supplements = _supplements ?? [];
    if (supplements.isEmpty) {
      return Center(
        child: Text('Keine Empfehlungen gefunden.',
            style: AppTextStyles.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.screenPaddingH),
      itemCount: supplements.length,
      itemBuilder: (context, index) {
        final supplement = supplements[index];
        final isInStack =
            stack.any((e) => e.id == supplement.id);
        return EvidenceCard(
          supplement: supplement,
          isInStack: isInStack,
          onAddToStack: () => stackNotifier.add(supplement),
          onRemoveFromStack: () => stackNotifier.remove(supplement.id),
        );
      },
    );
  }
}

// ---- Sub-Widgets ----

class _GoalSelector extends StatelessWidget {
  final String? selectedGoal;
  final void Function(String) onSelect;

  const _GoalSelector(
      {required this.selectedGoal, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingH,
          vertical: 10,
        ),
        itemCount: _goalCategories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppConstants.spaceS),
        itemBuilder: (context, index) {
          final goal = _goalCategories[index];
          final selected = selectedGoal == goal;
          return GestureDetector(
            onTap: () => onSelect(goal),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  goal,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.textInverse
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppConstants.spaceL),
          Text('Claude analysiert dein Profil...',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppConstants.spaceS),
          Text('Dauert ~5 Sekunden',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppConstants.spaceL),
            Text('Verbindungsfehler',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spaceXL),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Nochmal versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.border),
            const SizedBox(height: AppConstants.spaceM),
            Text('Wähle ein Thema aus',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Claude analysiert dann dein Profil und gibt '
              'dir personalisierte Empfehlungen.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

const _goalCategories = [
  'Mehr Energie',
  'Besserer Schlaf',
  'Fokus & Konzentration',
  'Immunsystem',
  'Sport & Regeneration',
  'Stimmung & Wohlbefinden',
  'Herzgesundheit',
  'Frauengesundheit',
];
