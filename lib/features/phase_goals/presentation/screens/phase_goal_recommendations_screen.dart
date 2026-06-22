import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../../recommendations/presentation/widgets/evidence_card.dart';
import '../../../stack/data/stack_provider.dart';
import '../../data/phase_goals_provider.dart';
import '../../domain/models/phase_goal.dart';

/// Empfehlungen für ein aktives Phasenziel.
/// Lädt via ApiService Supplements die speziell für das Ziel sinnvoll sind.
/// Hinzugefügte Supplements werden als temporär (mit phaseGoalId + endDate) markiert.
class PhaseGoalRecommendationsScreen extends ConsumerStatefulWidget {
  final String goalId; // ActivePhaseGoal.id

  const PhaseGoalRecommendationsScreen({
    super.key,
    required this.goalId,
  });

  @override
  ConsumerState<PhaseGoalRecommendationsScreen> createState() =>
      _PhaseGoalRecommendationsScreenState();
}

class _PhaseGoalRecommendationsScreenState
    extends ConsumerState<PhaseGoalRecommendationsScreen> {
  List<Supplement> _supplements = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final goal = ref.read(phaseGoalsProvider.notifier).find(widget.goalId);
    if (goal == null) return;

    final def = goal.definition;
    if (def == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _supplements = [];
    });

    final profile = ref.read(onboardingProvider);

    try {
      final results = await ApiService.instance.getRecommendations(
        profile: profile,
        goal: def.name, // z.B. "Marathon-Vorbereitung"
        limit: 6,
      );
      if (mounted) setState(() => _supplements = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addToStack(Supplement supplement, ActivePhaseGoal goal) async {
    final stackNotifier = ref.read(stackProvider.notifier);
    await stackNotifier.addForPhaseGoal(
      supplement: supplement,
      phaseGoalId: goal.id,
      endDate: goal.endDate,
    );

    // Supplement-ID auch im PhaseGoal registrieren
    await ref
        .read(phaseGoalsProvider.notifier)
        .addSupplementIds(goal.id, [supplement.id]);

    if (mounted) {
      final def = goal.definition;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${supplement.name} temporär hinzugefügt (bis ${_formatDate(goal.endDate)})'),
          backgroundColor: def?.accentColor ?? AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(phaseGoalsProvider
            .select((goals) => goals.where((g) => g.id == widget.goalId)))
        .firstOrNull;

    if (goal == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.textTertiary, size: 40),
              const SizedBox(height: AppConstants.spaceM),
              Text('Phasenziel nicht gefunden.',
                  style: AppTextStyles.bodyMedium),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Zurück'),
              ),
            ],
          ),
        ),
      );
    }

    final def = goal.definition;
    final accent = def?.accentColor ?? AppColors.primary;
    final existingStack = ref.watch(stackProvider);
    // Nach Relevanz-Score sortieren: höchster Score zuerst
    final sortedSupplements = [..._supplements]
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Gradient Header ---
          _RecoHeader(goal: goal, accent: accent, onBack: () => context.pop()),

          // --- Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingH,
                vertical: AppConstants.spaceL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Empfehlungen für diese Phase',
                        style: AppTextStyles.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diese Supplements werden temporär bis ${_formatDate(goal.endDate)} zu deinem Stack hinzugefügt.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),

                  const SizedBox(height: AppConstants.spaceL),

                  // --- Ziel-Info Chip ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceM,
                        vertical: AppConstants.spaceS),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.07),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusM),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(def?.icon ?? Icons.flag_outlined,
                            color: accent, size: 18),
                        const SizedBox(width: AppConstants.spaceS),
                        Expanded(
                          child: Text(
                            '${goal.remainingDays} Tage verbleibend · ${def?.name ?? goal.definitionId}',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.spaceL),

                  if (_isLoading)
                    _LoadingPlaceholder(accent: accent)
                  else if (_error != null)
                    _ErrorCard(error: _error!, onRetry: _load)
                  else if (_supplements.isEmpty)
                    _EmptyResult()
                  else
                    ...List.generate(sortedSupplements.length, (i) {
                      final s = sortedSupplements[i];
                      final alreadyInStack =
                          existingStack.any((e) => e.id == s.id);
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppConstants.spaceS),
                        child: EvidenceCard(
                          supplement: s,
                          isInStack: alreadyInStack,
                          rank: i < 3 ? i + 1 : null,
                          onAddToStack:
                              alreadyInStack ? null : () => _addToStack(s, goal),
                        ),
                      );
                    }),

                  const SizedBox(height: AppConstants.spaceL),

                  // --- CTA: Zum Stack ---
                  if (!_isLoading && _supplements.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.stack),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('Meinen Stack ansehen'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: accent),
                        foregroundColor: accent,
                      ),
                    ),

                  SizedBox(
                    height: AppConstants.spaceXL +
                        MediaQuery.of(context).padding.bottom,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _RecoHeader extends StatelessWidget {
  final ActivePhaseGoal goal;
  final Color accent;
  final VoidCallback onBack;

  const _RecoHeader({
    required this.goal,
    required this.accent,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final def = goal.definition;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.lerp(accent, Colors.black, 0.3) ?? accent,
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: topPadding + AppConstants.spaceM,
        left: AppConstants.screenPaddingH,
        right: AppConstants.screenPaddingH,
        bottom: AppConstants.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text('Zurück',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            children: [
              if (def != null) ...[
                Icon(def.icon, color: Colors.white, size: 28),
                const SizedBox(width: AppConstants.spaceM),
              ],
              Expanded(
                child: Text(
                  def?.name ?? 'Phasenziel',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${goal.remainingDays} Tage verbleibend',
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white.withOpacity(0.75)),
          ),
          const SizedBox(height: AppConstants.spaceM),
          // Fortschrittsbalken
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / Error / Empty
// ---------------------------------------------------------------------------

class _LoadingPlaceholder extends StatelessWidget {
  final Color accent;

  const _LoadingPlaceholder({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.evidenceRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.evidenceRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_outlined,
              size: 18, color: AppColors.evidenceRed),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Text('Backend nicht erreichbar.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.evidenceRed)),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Text(
        'Keine Empfehlungen für dieses Ziel verfügbar.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

// Extension helper
extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
