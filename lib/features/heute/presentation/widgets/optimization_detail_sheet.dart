import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../stack/domain/models/stack_entry.dart';

/// Liste aller aktiven Optimization-Supplements — geöffnet per Tap auf den
/// Amber-Bereich des Balkens. Zeigt bei unvollständigem Foundation-Score
/// einen sanften (nicht blockierenden) Hinweis, siehe [foundationScorePct].
class OptimizationDetailSheet extends StatelessWidget {
  final List<StackEntry> entries;
  final double foundationScorePct;

  const OptimizationDetailSheet({
    super.key,
    required this.entries,
    required this.foundationScorePct,
  });

  static void show(BuildContext context, {required List<StackEntry> entries, required double foundationScorePct}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
      ),
      builder: (_) => OptimizationDetailSheet(entries: entries, foundationScorePct: foundationScorePct),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optimization-Supplements',
              style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Leistung, Wohlbefinden & Longevity — zusätzlich zu deiner Basis.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (foundationScorePct < 100) ...[
              const SizedBox(height: AppConstants.spaceM),
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  border: Border.all(color: const Color(0xFFFFA000).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFEF6C00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dein Foundation-Score ist erst bei ${foundationScorePct.round()}%. '
                        'Erwäge zuerst deine Basis zu vervollständigen.',
                        style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFEF6C00)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spaceM),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceL),
                child: Text(
                  'Aktuell keine aktiven Optimization-Supplements.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spaceS),
                  itemBuilder: (context, i) => _OptimizationEntryRow(entry: entries[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptimizationEntryRow extends StatelessWidget {
  final StackEntry entry;
  const _OptimizationEntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(entry.dosage, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.trending_up, size: 16, color: Color(0xFFFFA000)),
        ],
      ),
    );
  }
}
