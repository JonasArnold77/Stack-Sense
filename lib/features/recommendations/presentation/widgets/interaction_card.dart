import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/supplement.dart';

/// Farbige Wechselwirkungs-Warnung. Wird nur angezeigt wenn
/// [Supplement.drugInteraction] nicht null ist.
class InteractionCard extends StatelessWidget {
  final Supplement supplement;

  const InteractionCard({super.key, required this.supplement});

  @override
  Widget build(BuildContext context) {
    final severity = supplement.interactionSeverity;
    final color = switch (severity) {
      InteractionSeverity.timing => AppColors.evidenceYellow,
      InteractionSeverity.moderate => const Color(0xFFEF6C00),
      InteractionSeverity.high => AppColors.evidenceRed,
      _ => AppColors.textSecondary,
    };
    final bg = switch (severity) {
      InteractionSeverity.timing => AppColors.evidenceYellowLight,
      InteractionSeverity.moderate => const Color(0xFFFFF3E0),
      InteractionSeverity.high => AppColors.evidenceRedLight,
      _ => AppColors.surfaceVariant,
    };
    final icon = switch (severity) {
      InteractionSeverity.timing => Icons.timer_outlined,
      InteractionSeverity.moderate => Icons.warning_amber_outlined,
      InteractionSeverity.high => Icons.dangerous_outlined,
      _ => Icons.info_outline,
    };

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppConstants.spaceS),
              Text(
                'WECHSELWIRKUNGEN',
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            supplement.drugInteraction!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
