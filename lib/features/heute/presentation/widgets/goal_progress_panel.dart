import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/feature_gate.dart';
import '../../../settings/domain/models/feature_keys.dart';
import '../../../goal_progress/presentation/screens/goal_progress_screen.dart'
    show goalColor;
import '../../../phase_goals/data/phase_goals_provider.dart';
import '../../../phase_goals/domain/models/phase_goal.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';

// ---------------------------------------------------------------------------
// Stage-Logik (geteilt zwischen Karte und GoalProgressScreen)
// ---------------------------------------------------------------------------

const _stageLabels = ['Gestartet', 'Aktiv', 'Wirkung', 'Erreicht'];

int stageForEntries(List<StackEntry> entries) {
  if (entries.isEmpty) return 1;
  final first = entries.map((e) => e.addedAt).reduce((a, b) => a.isBefore(b) ? a : b);
  final weeks = DateTime.now().difference(first).inDays / 7.0;
  if (weeks < 1) return 1;
  if (weeks < 3) return 2;
  if (weeks < 6) return 3;
  return 4;
}

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------

/// Großes "Meine Ziele" Panel — prominentestes Element auf dem Home Screen.
class GoalProgressPanel extends ConsumerWidget {
  const GoalProgressPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(stackProvider);
    final phaseGoals = ref.watch(phaseGoalsProvider);

    // Aktive (nicht abgelaufene) Phasenziele
    final activePhaseGoals = phaseGoals.where((g) => !g.isExpired).toList();

    // Normale Ziele aus addedFromGoals (ohne Phasenziel-Einträge herausfiltern)
    final normalGoals = <String>{};
    for (final entry in stack) {
      if (entry.phaseGoalId == null) {
        normalGoals.addAll(entry.addedFromGoals);
      }
    }
    final sortedNormalGoals = normalGoals.toList()..sort();

    final isEmpty = sortedNormalGoals.isEmpty && activePhaseGoals.isEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusM + 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header ----
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: const Icon(Icons.track_changes,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meine Ziele',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${sortedNormalGoals.length + activePhaseGoals.length} aktive Ziele',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // "+" Button
              GestureDetector(
                onTap: () => _showAddGoalSheet(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.30), width: 1.2),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spaceL),

          // ---- Inhalt ----
          if (isEmpty)
            _EmptyState(onAdd: () => _showAddGoalSheet(context))
          else ...[
            // Normale Ziele (Problemfelder / Basis)
            ...sortedNormalGoals.map((goal) {
              final entries = stack
                  .where((e) =>
                      e.phaseGoalId == null &&
                      e.addedFromGoals.contains(goal))
                  .toList();
              final stage = stageForEntries(entries);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
                child: NormalGoalCard(
                  goalName: goal,
                  supplementCount: entries.length,
                  stage: stage,
                  onTap: () =>
                      context.push(AppRoutes.goalProgress, extra: goal),
                ),
              );
            }),

            // Phasenziele
            ...activePhaseGoals.map((pg) {
              final def = pg.definition;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
                child: _PhaseGoalCard(
                  phaseGoal: pg,
                  definition: def,
                  onTap: () => context.push(
                    '${AppRoutes.phaseGoalDetail}/${pg.id}',
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddGoalSheet(parentContext: context),
    );
  }
}

// ---------------------------------------------------------------------------
// Normales Ziel: Problemfeld / Basis — 4-Stufen Progress
// ---------------------------------------------------------------------------

class NormalGoalCard extends StatelessWidget {
  final String goalName;
  final int supplementCount;
  final int stage; // 1–4
  final VoidCallback onTap;
  /// Überschreibt die sonst per-Thema unterschiedliche goalColor() (z.B.
  /// Blau für "Besserer Schlaf") — nötig wenn diese Karte auf einem eigenen
  /// farbigen Hintergrund landet (z.B. der Optimization-Kachel), wo die
  /// Themenfarbe mit dem Kachel-Grün zusammenstößt statt sich einzufügen.
  final Color? accentColorOverride;

  const NormalGoalCard({
    super.key,
    required this.goalName,
    required this.supplementCount,
    required this.stage,
    required this.onTap,
    this.accentColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColorOverride ?? goalColor(goalName);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zeile 1: Name + Chevron
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceS),
                Expanded(
                  child: Text(
                    goalName,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '$supplementCount Suppl.',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceS),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.white.withOpacity(0.40)),
              ],
            ),

            const SizedBox(height: AppConstants.spaceM),

            // Zeile 2: 4-Stufen Fortschritt
            _StageDots(stage: stage, color: color),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4-Stufen Dots
// ---------------------------------------------------------------------------

class _StageDots extends StatelessWidget {
  final int stage; // 1–4
  final Color color;

  const _StageDots({required this.stage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final stepNum = i + 1;
        final isDone = stepNum < stage;
        final isCurrent = stepNum == stage;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  // Verbindungslinie links (außer beim ersten)
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: (isDone || isCurrent)
                            ? color
                            : Colors.white.withOpacity(0.15),
                      ),
                    ),

                  // Dot
                  Container(
                    width: isCurrent ? 16 : 12,
                    height: isCurrent ? 16 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? color
                          : isCurrent
                              ? color
                              : Colors.white.withOpacity(0.12),
                      border: Border.all(
                        color: (isDone || isCurrent)
                            ? color
                            : Colors.white.withOpacity(0.25),
                        width: isCurrent ? 2.5 : 1.5,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.50),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 8, color: Colors.white)
                        : null,
                  ),

                  // Verbindungslinie rechts (außer beim letzten)
                  if (i < 3)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isDone
                            ? color
                            : Colors.white.withOpacity(0.15),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // Label
              Text(
                _stageLabels[i],
                style: AppTextStyles.caption.copyWith(
                  color: (isDone || isCurrent)
                      ? Colors.white.withOpacity(0.85)
                      : Colors.white.withOpacity(0.30),
                  fontSize: 9,
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Phasenziel-Karte: Fortschrittsbalken + Tage
// ---------------------------------------------------------------------------

class _PhaseGoalCard extends StatelessWidget {
  final ActivePhaseGoal phaseGoal;
  final PhaseGoalDefinition? definition;
  final VoidCallback onTap;

  const _PhaseGoalCard({
    required this.phaseGoal,
    required this.definition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = definition?.accentColor ?? AppColors.primary;
    final name = definition?.name ?? 'Phasenziel';
    final elapsed = phaseGoal.elapsedDays;
    final total = phaseGoal.totalDays;
    final progress = phaseGoal.progress;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: color.withOpacity(0.40), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zeile 1: Icon + Name + Chevron
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    definition?.icon ?? Icons.flag_outlined,
                    color: color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceS),
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Tage-Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceS, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.20),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    '${phaseGoal.remainingDays}d',
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceS),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.white.withOpacity(0.40)),
              ],
            ),

            const SizedBox(height: AppConstants.spaceM),

            // Zeile 2: Fortschrittsbalken
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),

            const SizedBox(height: 6),

            // Zeile 3: Tage-Text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tag $elapsed von $total',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leer-Zustand
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spaceXL,
          horizontal: AppConstants.spaceM,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline,
                color: Colors.white.withOpacity(0.45), size: 36),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Ziel hinzufügen',
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Problemfelder oder Phasenziele',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withOpacity(0.40),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "+" Modal Bottom Sheet
// ---------------------------------------------------------------------------

class _AddGoalSheet extends StatelessWidget {
  final BuildContext parentContext;

  const _AddGoalSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppConstants.spaceM, 0, AppConstants.spaceM, AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM + 4),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppConstants.spaceM),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppConstants.spaceM),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Was möchtest du hinzufügen?',
                      style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Wähle eine Kategorie um passende Supplements zu entdecken.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  FeatureGate(
                    featureKey: FeatureKeys.problemfelder,
                    child: _SheetOption(
                      icon: Icons.search,
                      color: AppColors.primary,
                      title: 'Problemfelder',
                      subtitle: 'Schlaf, Energie, Fokus, Stress & mehr',
                      onTap: () {
                        Navigator.pop(context);
                        parentContext.go(AppRoutes.recommendations);
                      },
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  FeatureGate(
                    featureKey: FeatureKeys.phasenziele,
                    child: _SheetOption(
                      icon: Icons.flag_outlined,
                      color: const Color(0xFF5C35CC),
                      title: 'Phasenziele',
                      subtitle: 'Marathon, Diät, Reise & temporäre Phasen',
                      onTap: () {
                        Navigator.pop(context);
                        parentContext.push(AppRoutes.phaseGoals);
                      },
                    ),
                  ),
                  SizedBox(height: AppConstants.spaceL + bottomInset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.labelLarge
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
