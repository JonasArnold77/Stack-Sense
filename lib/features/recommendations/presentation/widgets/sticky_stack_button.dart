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
  /// Der Problemfeld-/Phasenziel-/Basissupplementierung-Kontext, aus dem
  /// heraus dieser Screen geöffnet wurde (z.B. "Immunsystem"). Ist das
  /// Supplement bereits über einen ANDEREN Kontext im Stack, zeigt
  /// _InStackSection dann einen zusätzlichen, deutlich von "Zum Stack
  /// hinzufügen" unterscheidbaren Button, um auch DIESEN Kontext zu
  /// verknüpfen — gleiches Prinzip wie der "+ [Ziel]"-Button in der
  /// Kartenliste (siehe EvidenceCard/_InStackPanel).
  final String? goalContext;

  const StickyStackButton({
    super.key,
    required this.supplement,
    required this.isInStack,
    this.goalContext,
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
    final unlinkedGoalContext =
        (goalContext != null && !addedFromGoals.contains(goalContext)) ? goalContext : null;

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
              unlinkedGoalContext: unlinkedGoalContext,
              onAddGoalContext: unlinkedGoalContext == null
                  ? null
                  : () async {
                      await ref
                          .read(stackProvider.notifier)
                          .addGoalContext(supplement.id, unlinkedGoalContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${supplement.name} auch „$unlinkedGoalContext" zugeordnet',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
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
  /// Gesetzt, wenn der aktuelle Kontext noch NICHT in [addedFromGoals]
  /// enthalten ist — steuert, ob der "Auch hier zuordnen"-Button erscheint.
  final String? unlinkedGoalContext;
  final VoidCallback? onAddGoalContext;
  final VoidCallback onRemove;

  const _InStackSection({
    required this.supplement,
    required this.addedFromGoals,
    this.unlinkedGoalContext,
    this.onAddGoalContext,
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

        // "Auch hier zuordnen"-Button — nur wenn der aktuelle Kontext noch
        // nicht mit-gespeichert ist. Bewusst als primärfarbener
        // OutlinedButton mit "add_link"-Icon, damit er weder mit dem grünen
        // "Zum Stack hinzufügen" (neuer Eintrag!) noch mit dem grünen
        // "Entfernen"-Button verwechselt werden kann.
        if (unlinkedGoalContext != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('add_goal_context'),
              onPressed: onAddGoalContext,
              icon: const Icon(Icons.add_link, size: 18),
              label: Text('Auch zu „$unlinkedGoalContext" zuordnen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
        ],

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
