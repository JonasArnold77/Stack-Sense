import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/stack_entry.dart';
import '../../../recommendations/domain/models/supplement.dart';

/// Card für einen Eintrag im Stack des Nutzers.
/// Kompakter als die EvidenceCard — zeigt das Wichtigste auf einen Blick.
class StackSupplementCard extends StatelessWidget {
  final StackEntry entry;
  final VoidCallback onRemove;

  const StackSupplementCard({
    super.key,
    required this.entry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = _evidenceColor(entry.evidenceLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // --- Header ---
          Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Row(
              children: [
                // Evidenz-Indikator (farbiger Balken links)
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusRound),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceM),

                // Name + Substanz
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name, style: AppTextStyles.headlineSmall),
                      if (entry.substanceName != null)
                        Text(entry.substanceName!,
                            style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),

                // Einnahmezeit-Slot Badge
                _SlotBadge(slot: entry.intakeSlot),

                const SizedBox(width: AppConstants.spaceS),

                // Entfernen-Button
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textTertiary, size: 20),
                  tooltip: 'Aus Stack entfernen',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // --- Einnahme-Info ---
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              0,
              AppConstants.cardPadding,
              AppConstants.cardPadding,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceM,
              vertical: AppConstants.spaceS,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            child: Row(
              children: [
                const Icon(Icons.scale_outlined,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: AppConstants.spaceS),
                Expanded(
                  child: Text(
                    entry.dosage,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                if (entry.intakeHint != null) ...[
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: AppConstants.spaceXS),
                  Flexible(
                    child: Text(
                      entry.intakeHint!,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Wechselwirkungs-Warnung (falls vorhanden)
          if (entry.drugInteraction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.cardPadding,
                0,
                AppConstants.cardPadding,
                AppConstants.cardPadding,
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: AppConstants.spaceS),
                  Expanded(
                    child: Text(
                      entry.drugInteraction!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _evidenceColor(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppColors.evidenceGreen,
        EvidenceLevel.yellow => AppColors.evidenceYellow,
        EvidenceLevel.red => AppColors.evidenceRed,
      };
}

class _SlotBadge extends StatelessWidget {
  final IntakeSlot slot;
  const _SlotBadge({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '${slot.emoji} ${slot.label}',
        style: AppTextStyles.caption,
      ),
    );
  }
}
