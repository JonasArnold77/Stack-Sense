import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../stack/data/foundation_optimization_provider.dart';
import 'foundation_detail_sheet.dart';
import 'optimization_detail_sheet.dart';

/// Prominenter Balken auf dem Heute-Screen: links Foundation (Teal, 0-100%),
/// rechts Optimization (Amber, 100-130%, gedeckelt — bei mehr aktiven
/// Supplements wächst der Balken nicht weiter, stattdessen erscheint die
/// Anzahl als Zahl). Tap auf einen Bereich öffnet die jeweilige Detailliste.
class FoundationOptimizationBar extends ConsumerWidget {
  const FoundationOptimizationBar({super.key});

  static const _teal = Color(0xFF00897B);
  static const _amber = Color(0xFFFFA000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(foundationOptimizationProvider);
    final foundationFraction = (result.foundationScorePct / 100).clamp(0.0, 1.0);
    final optimizationFraction =
        ((result.optimizationBarPct - 100) / (kOptimizationBarCap - 100)).clamp(0.0, 1.0);
    final isCapped = result.optimizationBarPct >= kOptimizationBarCap;
    final optimizationCount = result.activeOptimizationEntries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gesundheitsbasis',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppConstants.spaceS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            child: SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FoundationDetailSheet.show(context, result.foundationItems),
                      child: _BarSegment(
                        trackColor: _teal.withOpacity(0.12),
                        fillColor: _teal,
                        fraction: foundationFraction,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => OptimizationDetailSheet.show(
                        context,
                        entries: result.activeOptimizationEntries,
                        foundationScorePct: result.foundationScorePct,
                      ),
                      child: _BarSegment(
                        trackColor: _amber.withOpacity(0.12),
                        fillColor: _amber,
                        fraction: optimizationFraction,
                        overflowBadge: isCapped ? '$optimizationCount' : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            'Foundation: ${result.foundationScorePct.round()}% · '
            '$optimizationCount Optimization-Supplement${optimizationCount == 1 ? '' : 'e'} aktiv',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  final Color trackColor;
  final Color fillColor;
  final double fraction; // 0.0 - 1.0
  final String? overflowBadge;

  const _BarSegment({
    required this.trackColor,
    required this.fillColor,
    required this.fraction,
    this.overflowBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: trackColor,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1,
              child: Container(color: fillColor),
            ),
          ),
          if (overflowBadge != null)
            Center(
              child: Text(
                overflowBadge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
