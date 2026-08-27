import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Kleines Label für Problemfelder, die sich mit mittlerer oder hoher
/// Aussagekraft über Smartwatch-/Wearable-Daten abbilden lassen — siehe
/// [kWearableCompatibleFields] in core/constants/wearable_compatible_fields.dart.
class WearableBadge extends StatelessWidget {
  const WearableBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.watch_outlined, size: 12, color: AppColors.primary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            'Wearable kompatibel',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
