import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/supplement.dart';
import '../../../stack/data/stack_provider.dart';
import 'safety_warning_dialog.dart';

/// Sticky-Button am unteren Bildschirmrand — fügt das Supplement zum Stack
/// hinzu oder entfernt es. Wenn bereits im Stack, zeigt einen
/// „Im Stack"-Status mit den gespeicherten Ziel-Kontexten.
class StickyStackButton extends ConsumerWidget {
  final Supplement supplement;
  final bool isInStack;

  const StickyStackButton({
    super.key,
    required this.supplement,
    required this.isInStack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Aktuellen Stack-Eintrag beobachten (für addedFromGoals).
    final stackEntry = ref
        .watch(stackProvider)
        .where((e) => e.id == supplement.id)
        .firstOrNull;
    final addedFromGoals = stackEntry?.addedFromGoals ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.spaceM,
        AppConstants.screenPaddingH,
        AppConstants.spaceM + bottomPadding,
      ),
      child: isInStack
          ? _InStackSection(
              supplement: supplement,
              addedFromGoals: addedFromGoals,
              onRemove: () {
                ref.read(stackProvider.notifier).remove(supplement.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${supplement.name} aus Stack entfernt'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            )
          : FilledButton.icon(
              key: const ValueKey('add_stack'),
              onPressed: () async {
                // Gleicher Sicherheits-Check wie in den drei Empfehlungs-
                // Feeds (recommendations/phase_goal/profile_recommendations
                // _screen.dart) — dieser Button wurde bisher übersprungen,
                // z.B. beim Öffnen eines Supplements über die Home-Screen-
                // Suche, wo dieser Screen der einzige Weg zum Stack ist.
                final safetyConfirmed = await confirmSupplementSafetyIfNeeded(
                  context,
                  supplementId: supplement.id,
                  supplementName: supplement.name,
                );
                if (!context.mounted || !safetyConfirmed) return;

                ref.read(stackProvider.notifier).add(supplement);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${supplement.name} zum Stack hinzugefügt'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Zum Stack hinzufügen'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusM),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Im-Stack-Sektion: Status-Badge mit Ziel-Chips + Entfernen-Button
// ---------------------------------------------------------------------------

class _InStackSection extends StatelessWidget {
  final Supplement supplement;
  final List<String> addedFromGoals;
  final VoidCallback onRemove;

  const _InStackSection({
    required this.supplement,
    required this.addedFromGoals,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status-Badge: zeigt gespeicherte Ziele
        if (addedFromGoals.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceM,
              vertical: AppConstants.spaceS,
            ),
            decoration: BoxDecoration(
              color: AppColors.evidenceGreen.withOpacity(0.07),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                  color: AppColors.evidenceGreen.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 12, color: AppColors.evidenceGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Im Stack · hinzugefügt aus',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.evidenceGreen.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: addedFromGoals
                      .map((g) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusRound),
                              border: Border.all(
                                  color:
                                      AppColors.primary.withOpacity(0.30)),
                            ),
                            child: Text(
                              g,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

        // Entfernen-Button
        OutlinedButton.icon(
          key: const ValueKey('in_stack'),
          onPressed: onRemove,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Im Stack — tippen zum Entfernen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.evidenceGreen,
            side: const BorderSide(color: AppColors.evidenceGreen),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
          ),
        ),
      ],
    );
  }
}
