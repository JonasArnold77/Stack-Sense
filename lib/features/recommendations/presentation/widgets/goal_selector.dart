import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'goal_tile_grid.dart' show goalData;

/// Horizontale Chip-Leiste zur Zielauswahl (erscheint wenn ein Ziel aktiv ist).
class GoalSelector extends StatelessWidget {
  final String? selectedGoal;
  final void Function(String) onSelect;

  /// Wenn true: für dunklen (Gradient-)Hintergrund gestylt.
  final bool onDark;

  const GoalSelector({
    super.key,
    required this.selectedGoal,
    required this.onSelect,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingH,
        ),
        itemCount: goalData.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spaceS),
        itemBuilder: (context, index) {
          final goal = goalData[index];
          final selected = selectedGoal == goal.label;

          final bgSelected =
              onDark ? Colors.white.withOpacity(0.22) : AppColors.primary;
          final bgUnselected = onDark
              ? Colors.white.withOpacity(0.09)
              : AppColors.surfaceVariant;
          final borderSelected =
              onDark ? Colors.white.withOpacity(0.7) : AppColors.primary;
          final borderUnselected =
              onDark ? Colors.white.withOpacity(0.2) : AppColors.border;
          final textSelected =
              onDark ? Colors.white : AppColors.textInverse;
          final textUnselected = onDark
              ? Colors.white.withOpacity(0.75)
              : AppColors.textSecondary;

          return GestureDetector(
            onTap: () => onSelect(goal.label),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? bgSelected : bgUnselected,
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                border: Border.all(
                  color: selected ? borderSelected : borderUnselected,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      goal.icon,
                      size: 13,
                      color: selected ? textSelected : textUnselected,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      goal.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected ? textSelected : textUnselected,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
