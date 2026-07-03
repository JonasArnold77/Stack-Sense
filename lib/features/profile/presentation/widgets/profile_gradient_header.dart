import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../gamification/domain/models/xp_level.dart';

/// Gradient-Header des Profil-Screens — Level, XP-Balken, Streak-Badge.
class ProfileGradientHeader extends StatelessWidget {
  final XpLevel xpLevel;
  final int streak;

  const ProfileGradientHeader({
    super.key,
    required this.xpLevel,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final xpFraction = xpLevel.isMaxLevel
        ? 1.0
        : xpLevel.xpInLevel / xpLevel.xpForNextLevel;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        padding: EdgeInsets.only(
          top: topPadding + AppConstants.spaceM,
          left: AppConstants.screenPaddingH,
          right: AppConstants.screenPaddingH,
          bottom: AppConstants.spaceL,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Level-Nummer im Kreis
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${xpLevel.level}',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: Colors.white,
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
                      Text(
                        xpLevel.levelName,
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        xpLevel.isMaxLevel
                            ? '${xpLevel.totalXp} XP · Maximum erreicht 🏆'
                            : '${xpLevel.totalXp} XP · noch ${xpLevel.xpRemaining} bis Level ${xpLevel.level + 1}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak Badge
                if (streak > 0)
                  Column(
                    children: [
                      Icon(Icons.local_fire_department,
                          color: AppColors.xpGold, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        '$streak',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tage',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: AppConstants.spaceM),

            // XP-Fortschrittsbalken
            if (!xpLevel.isMaxLevel) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level ${xpLevel.level}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    'Level ${xpLevel.level + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: xpFraction.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.xpGold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
