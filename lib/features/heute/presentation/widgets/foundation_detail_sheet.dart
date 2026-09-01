import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../recommendations/domain/models/supplement_thresholds.dart';
import '../../../stack/data/foundation_optimization_provider.dart';

/// Liste aller Foundation-Referenz-Nährstoffe mit individuellem
/// Abdeckungsgrad — geöffnet per Tap auf den Teal-Bereich des Balkens.
class FoundationDetailSheet extends StatelessWidget {
  final List<FoundationItemStatus> items;

  const FoundationDetailSheet({super.key, required this.items});

  static void show(BuildContext context, List<FoundationItemStatus> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
      ),
      builder: (_) => FoundationDetailSheet(items: items),
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
              'Foundation-Nährstoffe',
              style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Deine grundlegende Gesundheitsbasis — Mängel hier zu vermeiden hat Priorität.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppConstants.spaceM),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spaceS),
                itemBuilder: (context, i) => _FoundationItemRow(item: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundationItemRow extends StatelessWidget {
  final FoundationItemStatus item;

  const _FoundationItemRow({required this.item});

  ({Color color, String label}) get _statusInfo {
    switch (item.matchState) {
      case FoundationMatchState.missing:
        return (color: AppColors.textTertiary, label: 'Nicht im Stack');
      case FoundationMatchState.unknownAmount:
        return (color: AppColors.textTertiary, label: 'Im Stack · Menge nicht erkennbar');
      case FoundationMatchState.matched:
        switch (item.zone!) {
          case DoseZone.deficient:
            return (color: AppColors.evidenceRed, label: 'Unter Mindestbedarf');
          case DoseZone.foundation:
            return (color: AppColors.evidenceGreen, label: '${item.coveragePct.round()}% abgedeckt');
          case DoseZone.optimization:
            return (color: const Color(0xFFFFA000), label: 'Über Optimal · zählt zu Optimization');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo;
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
                Row(
                  children: [
                    Text(item.label, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    if (item.priorityForProfile) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                        ),
                        child: Text(
                          'Besonders wichtig für dich',
                          style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 9),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(status.label, style: AppTextStyles.caption.copyWith(color: status.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
