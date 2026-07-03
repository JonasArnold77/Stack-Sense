import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Abschnittsüberschrift mit optionalem Action-Widget rechts.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionTitle({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.headlineSmall),
        if (action != null) action!,
      ],
    );
  }
}
