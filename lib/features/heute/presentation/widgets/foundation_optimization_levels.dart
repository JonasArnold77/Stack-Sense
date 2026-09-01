import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/feature_gate.dart';
import '../../../settings/domain/models/feature_keys.dart';
import '../../../stack/data/foundation_optimization_provider.dart';
import '../../../stack/data/stack_provider.dart';
import 'foundation_detail_sheet.dart';
import 'goal_progress_panel.dart' show NormalGoalCard, stageForEntries;
import 'optimization_detail_sheet.dart';

/// Zwei unabhängige Level-Systeme, im selben großen Karten-Format wie
/// "Meine Ziele" (GoalProgressPanel) — volle Breite, übereinander statt
/// nebeneinander. Foundation (wie gut die Gesundheitsbasis abgedeckt ist,
/// Level 1 Beginner bis 5 Complete) und Optimization (wie viele Problemfeld-
/// Supplements aktiv sind, Level 1 Explorer bis 5 Elite) sind komplett
/// unabhängig — Optimization kann steigen ohne dass Foundation
/// abgeschlossen ist. Tap auf eine Kachel öffnet die jeweilige Detailliste;
/// die Basissupplementierung-/Problemfelder-Buttons sitzen jetzt INNERHALB
/// der jeweiligen Kachel statt darunter.
class FoundationOptimizationLevels extends ConsumerWidget {
  const FoundationOptimizationLevels({super.key});

  // Foundation: tiefes Teal-Grün (an die Markenfarbe angelehnt).
  static const _foundationColor = Color(0xFF0F7A5D);
  static const _foundationColorDark = Color(0xFF083D2E);
  // Optimization: warmes Oliv-Grün — bleibt in der Grün-Familie, aber
  // deutlich wärmer/gelber, damit beide Kacheln trotz gemeinsamer
  // Grün-Markenfarbe klar unterscheidbar bleiben.
  static const _optimizationColor = Color(0xFF7C8A1E);
  static const _optimizationColorDark = Color(0xFF454E0F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(foundationOptimizationProvider);
    final stack = ref.watch(stackProvider);

    // Angewendete Problemfelder — dieselbe Gruppierung wie in
    // GoalProgressPanel ("normale Ziele"), aber ohne die generische
    // "Basissupplementierung"-Quelle, die dort mitzählt.
    final problemfeldGoals = <String>{};
    for (final entry in stack) {
      if (entry.phaseGoalId == null) {
        problemfeldGoals.addAll(entry.addedFromGoals.where((g) => g != 'Basissupplementierung'));
      }
    }
    final sortedProblemfeldGoals = problemfeldGoals.toList()..sort();

    return Column(
      children: [
        _LevelCard(
          icon: Icons.foundation,
          categoryLabel: 'Foundation',
          color: _foundationColor,
          colorDark: _foundationColorDark,
          level: result.foundationLevel,
          onTap: () => FoundationDetailSheet.show(context, result.foundationItems),
          footer: FeatureGate(
            featureKey: FeatureKeys.basisSupplementierung,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.profileRecommendations),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Basissupplementierung'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.evidenceGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceM),
        _LevelCard(
          icon: Icons.trending_up_rounded,
          categoryLabel: 'Optimization',
          color: _optimizationColor,
          colorDark: _optimizationColorDark,
          level: result.optimizationLevel,
          onTap: () => OptimizationDetailSheet.show(
            context,
            entries: result.activeOptimizationEntries,
            foundationScorePct: result.foundationScorePct,
          ),
          content: sortedProblemfeldGoals.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedProblemfeldGoals.map((goal) {
                    final entries = stack
                        .where((e) => e.phaseGoalId == null && e.addedFromGoals.contains(goal))
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
                      child: NormalGoalCard(
                        goalName: goal,
                        supplementCount: entries.length,
                        stage: stageForEntries(entries),
                        onTap: () => context.push(AppRoutes.goalProgress, extra: goal),
                        accentColorOverride: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
          footer: FeatureGate(
            featureKey: FeatureKeys.problemfelder,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.recommendations),
                icon: const Icon(Icons.search, size: 18, color: Colors.white),
                label: const Text('Problemfelder', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final IconData icon;
  final String categoryLabel;
  final Color color;
  final Color colorDark;
  final LevelInfo level;
  final VoidCallback onTap;
  final Widget? content;
  final Widget footer;

  const _LevelCard({
    required this.icon,
    required this.categoryLabel,
    required this.color,
    required this.colorDark,
    required this.level,
    required this.onTap,
    this.content,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, colorDark],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusM + 4),
        boxShadow: [
          BoxShadow(
            color: colorDark.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header (Tap öffnet die Detailliste) ----
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppConstants.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryLabel,
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Level ${level.level} · ${level.name}',
                        style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.55)),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            child: LinearProgressIndicator(
              value: level.progressToNext,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            level.isMax ? 'Maximal erreicht' : 'Level ${level.level + 1} in Sicht',
            style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.75)),
          ),
          if (content != null) ...[
            const SizedBox(height: AppConstants.spaceL),
            content!,
          ],
          const SizedBox(height: AppConstants.spaceM),
          footer,
        ],
      ),
    );
  }
}
