import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Streak + Check-in Statistiken nebeneinander.
class ProfileStatsRow extends StatelessWidget {
  final int streak;
  final int checkinCount;

  const ProfileStatsRow({
    super.key,
    required this.streak,
    required this.checkinCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProfileStatBox(
            emoji: '🔥',
            value: '$streak',
            label: streak == 1 ? 'Tag Streak' : 'Tage Streak',
          ),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: ProfileStatBox(
            emoji: '✅',
            value: '$checkinCount',
            label: checkinCount == 1 ? 'Check-in' : 'Check-ins',
          ),
        ),
      ],
    );
  }
}

/// Einzelne Stat-Box (Emoji + Zahl + Label).
class ProfileStatBox extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const ProfileStatBox({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: AppConstants.spaceXS),
          Text(value, style: AppTextStyles.headlineMedium),
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
