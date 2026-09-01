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
import 'foundation_detail_sheet.dart';
import 'optimization_detail_sheet.dart';

/// Zwei unabhängige Level-Systeme, prominent nebeneinander auf dem Heute-
/// Screen: Foundation (wie gut die Gesundheitsbasis abgedeckt ist, Level 1
/// Beginner bis 5 Complete) und Optimization (wie viele Problemfeld-
/// Supplements aktiv sind, Level 1 Explorer bis 5 Elite). Beide Level sind
/// komplett unabhängig — Optimization kann steigen ohne dass Foundation
/// abgeschlossen ist. Tap auf eine Kachel öffnet die jeweilige Detailliste.
class FoundationOptimizationLevels extends ConsumerWidget {
  const FoundationOptimizationLevels({super.key});

  // Foundation: tiefes Teal-Grün (an die Markenfarbe angelehnt).
  static const _foundationColor = Color(0xFF0F7A5D);
  // Optimization: warmes Oliv-Grün — bleibt in der Grün-Familie, aber
  // deutlich wärmer/gelber, damit beide Kacheln trotz gemeinsamer
  // Grün-Markenfarbe klar unterscheidbar bleiben.
  static const _optimizationColor = Color(0xFF7C8A1E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(foundationOptimizationProvider);
    final foundationLevel = result.foundationLevel;
    final optimizationLevel = result.optimizationLevel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _LevelTile(
                categoryLabel: 'Foundation',
                color: _foundationColor,
                level: foundationLevel,
                onTap: () => FoundationDetailSheet.show(context, result.foundationItems),
              ),
              const SizedBox(height: AppConstants.spaceS),
              FeatureGate(
                featureKey: FeatureKeys.basisSupplementierung,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.profileRecommendations),
                    icon: const Icon(Icons.foundation, size: 16),
                    label: const Text('Basissupplementierung'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.evidenceGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Column(
            children: [
              _LevelTile(
                categoryLabel: 'Optimization',
                color: _optimizationColor,
                level: optimizationLevel,
                onTap: () => OptimizationDetailSheet.show(
                  context,
                  entries: result.activeOptimizationEntries,
                  foundationScorePct: result.foundationScorePct,
                ),
              ),
              const SizedBox(height: AppConstants.spaceS),
              FeatureGate(
                featureKey: FeatureKeys.problemfelder,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.recommendations),
                    icon: Icon(Icons.search, size: 16, color: _optimizationColor),
                    label: Text('Problemfelder', style: TextStyle(color: _optimizationColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _optimizationColor.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String categoryLabel;
  final Color color;
  final LevelInfo level;
  final VoidCallback onTap;

  const _LevelTile({
    required this.categoryLabel,
    required this.color,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryLabel.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppConstants.spaceS),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${level.level}',
                  style: AppTextStyles.displayLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    level.name,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spaceS),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              child: LinearProgressIndicator(
                value: level.progressToNext,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              level.isMax ? 'Maximal erreicht' : 'Level ${level.level + 1} in Sicht',
              style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.75)),
            ),
          ],
        ),
      ),
    );
  }
}
