import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/same_goal_repeat_provider.dart';

String _repeatMessage(SameGoalRepeat r) =>
    'Du hast bereits ${r.count} Supplements für "${r.goal}" hinzugefügt. '
    'Es wird empfohlen, erst einmal auf die Wirkung zu warten, bevor du weitere ergänzt.';

/// Dauerhafter Hinweis im Stack-Screen — ein Kärtchen pro Problemfeld/
/// Phasenziel, das die Schwelle erreicht hat (siehe pendingSameGoalRepeatsProvider).
/// Siehe auch [showSameGoalRepeatPopup] für die sofortige Variante direkt
/// nach dem Hinzufügen.
class SameGoalRepeatBanner extends ConsumerWidget {
  const SameGoalRepeatBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSameGoalRepeatsProvider);
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final r in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
            child: _SameGoalRepeatCard(repeat: r),
          ),
      ],
    );
  }
}

class _SameGoalRepeatCard extends ConsumerWidget {
  final SameGoalRepeat repeat;
  const _SameGoalRepeatCard({required this.repeat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: const Color(0xFFEF6C00).withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty, color: Color(0xFFEF6C00), size: 20),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Text(
              _repeatMessage(repeat),
              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF7A4200)),
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.read(sameGoalRepeatHandledProvider.notifier).markHandled(repeat.goal, repeat.signature),
            icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
            tooltip: 'Verstanden',
            style: IconButton.styleFrom(minimumSize: const Size(28, 28), padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

/// Zeigt denselben Hinweis sofort als Dialog — aufgerufen direkt nachdem ein
/// Supplement zum Stack hinzugefügt wurde (siehe stack_add_warnings.dart).
/// Tippt der Nutzer außerhalb weg (statt auf "Verstanden"), bleibt der
/// Hinweis im Stack-Screen weiterhin stehen.
Future<void> showSameGoalRepeatPopup(BuildContext context, WidgetRef ref, SameGoalRepeat repeat) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('"${repeat.goal}" — mehrere neue Supplements'),
      content: Text(_repeatMessage(repeat)),
      actions: [
        FilledButton(
          onPressed: () {
            ref.read(sameGoalRepeatHandledProvider.notifier).markHandled(repeat.goal, repeat.signature);
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Verstanden'),
        ),
      ],
    ),
  );
}
