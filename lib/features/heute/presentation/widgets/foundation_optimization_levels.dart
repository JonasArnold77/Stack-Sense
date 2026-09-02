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
/// die Basissupplementierung-/Problemfelder-Buttons sitzen INNERHALB der
/// jeweiligen Kachel. Zeigt immer den AKTUELLEN, statischen Stand — die
/// hochzählende Feier-Animation bei einer Änderung übernimmt LevelUpOverlay
/// (siehe level_up_overlay.dart), separat über dieser Karte eingeblendet.
class FoundationOptimizationLevels extends ConsumerWidget {
  const FoundationOptimizationLevels({super.key});

  // Foundation: an die Lime-Markenfarbe angelehnt.
  static const foundationColor = AppColors.primary;
  static const foundationColorDark = AppColors.primaryDark;
  // Optimization: warmes Bernstein/Gold statt Grün — bewusst NICHT Teil der
  // Lime-Familie, damit beide Kacheln trotz gemeinsamer Markenfarbe klar
  // unterscheidbar bleiben (passt zusätzlich zum "Elite"-Erfolgs-Thema).
  static const optimizationColor = Color(0xFFB45309);
  static const optimizationColorDark = Color(0xFF78350F);

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
        LevelCard(
          icon: Icons.foundation,
          categoryLabel: 'Foundation',
          color: foundationColor,
          colorDark: foundationColorDark,
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
        LevelCard(
          icon: Icons.trending_up_rounded,
          categoryLabel: 'Optimization',
          color: optimizationColor,
          colorDark: optimizationColorDark,
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

/// Öffentlich (nicht nur von hier genutzt) — LevelUpOverlay baut daraus seine
/// vergrößerte Feier-Version mit denselben Farben/Level-Daten, nur mit
/// [scale] > 1 skaliert statt eine komplett eigene Karte nachzubauen.
class LevelCard extends StatelessWidget {
  final IconData icon;
  final String categoryLabel;
  final Color color;
  final Color colorDark;
  final LevelInfo level;
  final VoidCallback? onTap;
  final Widget? content;
  final Widget? footer;
  final double scale;
  /// 0-1 — legt ein weißes "Aufblitzen" über die Karte, genutzt von
  /// LevelUpOverlay bei einem tatsächlichen Levelaufstieg während der
  /// Zähl-Animation. 0 = unsichtbar (Normalfall).
  final double overlayOpacity;

  const LevelCard({
    super.key,
    required this.icon,
    required this.categoryLabel,
    required this.color,
    required this.colorDark,
    required this.level,
    this.onTap,
    this.content,
    this.footer,
    this.scale = 1.0,
    this.overlayOpacity = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.radiusM + 4);
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, colorDark],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colorDark.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              child: Column(
        mainAxisSize: MainAxisSize.min,
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
                if (onTap != null) Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.55)),
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
          if (footer != null) ...[
            const SizedBox(height: AppConstants.spaceM),
            footer!,
          ],
        ],
              ),
            ),
            if (overlayOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: Colors.white.withOpacity(overlayOpacity)),
                ),
              ),
          ],
        ),
      ),
    );

    if (scale == 1.0) return card;
    return Transform.scale(scale: scale, alignment: Alignment.topCenter, child: card);
  }
}
