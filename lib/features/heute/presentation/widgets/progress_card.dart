import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../gamification/domain/models/xp_level.dart';

class ProgressCard extends StatelessWidget {
  final XpLevel xpLevel;
  final int streak;
  final VoidCallback onTap;

  const ProgressCard({
    super.key,
    required this.xpLevel,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        decoration: BoxDecoration(
          color: AppColors.panelTintSage,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Center(
                child: Text(
                  '${xpLevel.level}',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(xpLevel.levelName,
                          style: AppTextStyles.labelLarge
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        xpLevel.isMaxLevel
                            ? 'Max!'
                            : '${xpLevel.xpRemaining} XP bis Level ${xpLevel.level + 1}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpLevel.progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.xpGold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 13, color: AppColors.xpGold),
                      const SizedBox(width: 3),
                      Text('$streak Tage Streak',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(width: AppConstants.spaceM),
                      const Icon(Icons.star_outline,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text('${xpLevel.totalXp} XP',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceS),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
