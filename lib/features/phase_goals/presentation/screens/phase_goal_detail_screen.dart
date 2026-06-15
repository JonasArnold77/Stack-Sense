import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../data/phase_goals_provider.dart';
import '../../domain/models/phase_goal.dart';

/// Detailansicht eines aktiven Phasenziels.
/// Zeigt Fortschrittsbalken, verbleibende Tage, zugehörige Supplements
/// und optional eine Retrospektiv-Karte mit Check-in-Vergleich.
class PhaseGoalDetailScreen extends ConsumerWidget {
  final String goalId;

  const PhaseGoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(phaseGoalsProvider);
    final goal = goals.where((g) => g.id == goalId).firstOrNull;

    if (goal == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_outlined,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppConstants.spaceM),
              Text('Phasenziel nicht gefunden.',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppConstants.spaceS),
              FilledButton(
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
    final stack = ref.watch(stackProvider);

    // Alle temporären Supplements die zu diesem Ziel gehören
    final phaseSupplements =
        stack.where((e) => e.phaseGoalId == goalId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // --- Header ---
          SliverToBoxAdapter(
            child: _DetailHeader(goal: goal, accent: accent),
          ),

          // --- Retrospektiv (wenn genug Check-in Daten) ---
          SliverToBoxAdapter(
            child: _RetroCard(goal: goal, accent: accent),
          ),

          // --- Supplement-Liste ---
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppConstants.spaceL),
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
                        'Temporäre Supplements',
                        style: AppTextStyles.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phaseSupplements.isEmpty
                        ? 'Noch keine Supplements für diese Phase hinzugefügt.'
                        : 'Diese Supplements werden am ${_formatDate(goal.endDate)} automatisch entfernt.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: AppConstants.spaceM),

                  if (phaseSupplements.isEmpty)
                    _EmptySupplementsCard(
                      onTap: () => context.push(
                          '${AppRoutes.phaseGoalRecommendations}/$goalId'),
                    )
                  else
                    ...phaseSupplements.map(
                      (e) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppConstants.spaceS),
                        child: _PhaseSupplementCard(
                          entry: e,
                          accent: accent,
                          endDate: goal.endDate,
                        ),
                      ),
                    ),

                  const SizedBox(height: AppConstants.spaceL),

                  // Empfehlungen Button
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                        '${AppRoutes.phaseGoalRecommendations}/$goalId'),
                    icon: Icon(Icons.add, size: 18, color: accent),
                    label: const Text('Weitere Empfehlungen laden'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: accent),
                      foregroundColor: accent,
                    ),
                  ),

                  const SizedBox(height: AppConstants.spaceXXL),

                  // Ziel beenden
                  _EndGoalButton(goal: goal, accent: accent),

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

  String _formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';
}

// ---------------------------------------------------------------------------
// Header mit Fortschrittsbalken
// ---------------------------------------------------------------------------

class _DetailHeader extends StatelessWidget {
  final ActivePhaseGoal goal;
  final Color accent;

  const _DetailHeader({required this.goal, required this.accent});

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
          // Back
          GestureDetector(
            onTap: () => context.pop(),
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

          // Icon + Name
          Row(
            children: [
              if (def != null) ...[
                Icon(def.icon, color: Colors.white, size: 28),
                const SizedBox(width: AppConstants.spaceM),
              ],
              Expanded(
                child: Text(
                  def?.name ?? goal.definitionId,
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),

          // Status-Chips
          Row(
            children: [
              _HeaderChip(
                icon: Icons.hourglass_top_outlined,
                label: '${goal.remainingDays} Tage verbleibend',
              ),
              const SizedBox(width: AppConstants.spaceS),
              _HeaderChip(
                icon: Icons.calendar_today_outlined,
                label: 'bis ${goal.endDate.day}.${goal.endDate.month}.${goal.endDate.year}',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),

          // Fortschrittsbalken
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusRound),
                  child: LinearProgressIndicator(
                    value: goal.progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Text(
                '${goal.elapsedDays} / ${goal.totalDays} Tage',
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white.withOpacity(0.75)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Retrospektiv-Karte (Check-in Vergleich)
// ---------------------------------------------------------------------------

class _RetroCard extends ConsumerWidget {
  final ActivePhaseGoal goal;
  final Color accent;

  const _RetroCard({required this.goal, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkins = ref.watch(checkinProvider);
    if (checkins.length < 4) return const SizedBox.shrink();

    // Checkins vor und während dem Ziel
    final sorted = [...checkins]
      ..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));

    final before = sorted.where((c) => c.dateOnly.isBefore(goal.startDate)).toList();
    final during = sorted
        .where((c) => !c.dateOnly.isBefore(goal.startDate))
        .toList();

    if (before.isEmpty || during.isEmpty) return const SizedBox.shrink();

    final avgBefore = before.map((c) => c.average).reduce((a, b) => a + b) /
        before.length;
    final avgDuring =
        during.map((c) => c.average).reduce((a, b) => a + b) / during.length;

    final delta = avgDuring - avgBefore;
    final isPositive = delta >= 0;
    final changeStr =
        '${isPositive ? '+' : ''}${delta.toStringAsFixed(1)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.spaceL,
        AppConstants.screenPaddingH,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: isPositive
              ? AppColors.evidenceGreenLight
              : AppColors.evidenceYellowLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(
            color: isPositive
                ? AppColors.evidenceGreen.withOpacity(0.3)
                : AppColors.evidenceYellow.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPositive
                    ? AppColors.evidenceGreen.withOpacity(0.12)
                    : AppColors.evidenceYellow.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Center(
                child: Text(
                  isPositive ? '📈' : '📊',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rückblick auf diese Phase',
                    style: AppTextStyles.labelLarge
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Dein durchschnittlicher Wohlbefindens-Score hat sich während dieser Phase um $changeStr verändert.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase-Supplement Card
// ---------------------------------------------------------------------------

class _PhaseSupplementCard extends StatelessWidget {
  final StackEntry entry;
  final Color accent;
  final DateTime endDate;

  const _PhaseSupplementCard({
    required this.entry,
    required this.accent,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final evidenceColor = switch (entry.evidenceLevel) {
      EvidenceLevel.green => AppColors.evidenceGreen,
      EvidenceLevel.yellow => AppColors.evidenceYellow,
      EvidenceLevel.red => AppColors.evidenceRed,
    };

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Evidenz-Balken
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: evidenceColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: AppTextStyles.labelLarge
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(entry.dosage,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                // Temporär-Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    'Temporär · bis ${endDate.day}.${endDate.month}.${endDate.year}',
                    style: AppTextStyles.caption.copyWith(
                        color: accent, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Text(
            entry.intakeTime,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

class _EmptySupplementsCard extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptySupplementsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(
              color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline,
                color: AppColors.textTertiary, size: 22),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Text(
                'Empfehlungen laden und Supplements temporär hinzufügen →',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ziel beenden Button
// ---------------------------------------------------------------------------

class _EndGoalButton extends ConsumerWidget {
  final ActivePhaseGoal goal;
  final Color accent;

  const _EndGoalButton({required this.goal, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => _confirmEnd(context, ref),
      icon: const Icon(Icons.stop_circle_outlined,
          size: 18, color: AppColors.evidenceRed),
      label: const Text('Ziel vorzeitig beenden',
          style: TextStyle(color: AppColors.evidenceRed)),
    );
  }

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ziel beenden?'),
        content: const Text(
            'Alle temporären Supplements dieses Ziels werden aus deinem Stack entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Beenden',
                style: TextStyle(color: AppColors.evidenceRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref
        .read(stackProvider.notifier)
        .removeByPhaseGoal(goal.id);
    await ref.read(phaseGoalsProvider.notifier).deactivate(goal.id);

    if (context.mounted) context.pop();
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
