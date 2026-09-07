import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../goal_progress/presentation/screens/goal_progress_screen.dart'
    show goalColor;
import '../../../phase_goals/domain/models/phase_goal.dart';
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
// Kartenwidgets — werden nicht mehr in einem eigenen "Meine Ziele"-Panel
// gezeigt (das gab es hier früher, ist aber komplett entfallen: Problemfeld-
// und Phasenziel-Fortschritt laufen inzwischen beide über die Optimization-
// Kachel, siehe foundation_optimization_levels.dart), sondern direkt von
// dort aus verwendet.
// ---------------------------------------------------------------------------

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
// Phasenziel-Karte: Fortschrittsbalken + Tage — wird auf der Optimization-
// Kachel gerendert (siehe foundation_optimization_levels.dart).
// ---------------------------------------------------------------------------

class PhaseGoalCard extends StatelessWidget {
  final ActivePhaseGoal phaseGoal;
  final PhaseGoalDefinition? definition;
  final VoidCallback onTap;
  /// Überschreibt die sonst per-Definition unterschiedliche accentColor
  /// (z.B. Lila) — nötig auf der Optimization-Kachel, wo die Themenfarbe
  /// mit dem Kachel-Grün zusammenstößt statt sich einzufügen (gleiches
  /// Prinzip wie bei NormalGoalCard.accentColorOverride).
  final Color? accentColorOverride;

  const PhaseGoalCard({
    super.key,
    required this.phaseGoal,
    required this.definition,
    required this.onTap,
    this.accentColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColorOverride ?? definition?.accentColor ?? AppColors.primary;
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
