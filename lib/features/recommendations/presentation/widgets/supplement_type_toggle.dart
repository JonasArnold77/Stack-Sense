import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/supplement.dart' show SupplementType;

/// Toggle zwischen "Einzelwirkstoffe" und "Kombipräparate".
class SupplementTypeToggle extends StatelessWidget {
  final SupplementType selected;
  final void Function(SupplementType) onSelect;

  const SupplementTypeToggle({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        0,
        AppConstants.screenPaddingH,
        10,
      ),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _ToggleOption(
              label: 'Einzelwirkstoffe',
              icon: Icons.science_outlined,
              isSelected: selected == SupplementType.single,
              onTap: () => onSelect(SupplementType.single),
            ),
            _ToggleOption(
              label: 'Kombipräparate',
              icon: Icons.layers_outlined,
              isSelected: selected == SupplementType.group,
              onTap: () => onSelect(SupplementType.group),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.textInverse
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
