import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Liste aller XP-Aktionen mit ihrem jeweiligen XP-Wert.
class XpSourcesCard extends StatelessWidget {
  const XpSourcesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          XpRow(
            icon: Icons.check_circle_outline,
            label: 'Täglicher Check-in',
            xp: AppConstants.xpCheckin,
          ),
          const Divider(height: AppConstants.spaceL),
          XpRow(
            icon: Icons.layers_outlined,
            label: 'Stack aktualisieren',
            xp: AppConstants.xpStackUpdate,
          ),
          const Divider(height: AppConstants.spaceL),
          XpRow(
            icon: Icons.menu_book_outlined,
            label: 'Evidenz lesen',
            xp: AppConstants.xpEvidenceRead,
          ),
          const Divider(height: AppConstants.spaceL),
          XpRow(
            icon: Icons.share_outlined,
            label: 'Protokoll teilen',
            xp: AppConstants.xpProtocolShare,
          ),
          const Divider(height: AppConstants.spaceL),
          XpRow(
            icon: Icons.biotech_outlined,
            label: 'Blutbild hochladen',
            xp: AppConstants.xpBloodworkUpload,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

/// Einzelne Zeile: Icon + Label + XP-Badge.
class XpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int xp;
  final bool isLast;

  const XpRow({
    super.key,
    required this.icon,
    required this.label,
    required this.xp,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceS,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.xpGold.withAlpha(25),
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          ),
          child: Text(
            '+$xp XP',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.xpGold),
          ),
        ),
      ],
    );
  }
}
