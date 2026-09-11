import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/stack_provider.dart';
import '../../domain/models/combination_check_result.dart';

/// Zeigt das Ergebnis eines Kombinationschecks — gruppiert nach Warnkategorie,
/// mit den jeweils betroffenen Supplements. Wer eine Karteikarte hier
/// entfernt, entfernt sie direkt aus dem Stack (kein neuer KI-Aufruf nötig —
/// die Warnung für diesen Namen wird lokal als "erledigt" markiert).
void showCombinationCheckResultSheet(BuildContext context, CombinationCheckResult result) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusL)),
    ),
    builder: (_) => _CombinationCheckResultSheet(result: result),
  );
}

class _CombinationCheckResultSheet extends ConsumerStatefulWidget {
  final CombinationCheckResult result;
  const _CombinationCheckResultSheet({required this.result});

  @override
  ConsumerState<_CombinationCheckResultSheet> createState() => _CombinationCheckResultSheetState();
}

class _CombinationCheckResultSheetState extends ConsumerState<_CombinationCheckResultSheet> {
  // Namen, die der Nutzer aus dieser Ansicht heraus schon entfernt hat — rein
  // lokale Darstellung, kein erneuter KI-Aufruf.
  final Set<String> _removedNames = {};

  ({IconData icon, Color color, String label}) _categoryInfo(CombinationWarningGroup g) {
    final color = g.severity == CombinationWarningSeverity.high
        ? AppColors.evidenceRed
        : const Color(0xFFEF6C00);
    return switch (g.category) {
      CombinationWarningCategory.interaction =>
        (icon: Icons.compare_arrows, color: color, label: 'Wechselwirkung'),
      CombinationWarningCategory.overdose =>
        (icon: Icons.trending_up, color: color, label: 'Überdosierungsrisiko'),
      CombinationWarningCategory.duplicate =>
        (icon: Icons.content_copy, color: color, label: 'Doppelter Wirkstoff'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final stack = ref.watch(stackProvider);
    final entryByName = {for (final e in stack) e.name: e};
    final groups = widget.result.groups;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kombinationscheck', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.result.summary, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppConstants.spaceM),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceL),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.evidenceGreen),
                    const SizedBox(width: AppConstants.spaceS),
                    Expanded(
                      child: Text(
                        'Keine Auffälligkeiten in deiner aktuellen Kombination gefunden.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppConstants.spaceM),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    final info = _categoryInfo(g);
                    return Container(
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: info.color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                        border: Border.all(color: info.color.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(info.icon, size: 16, color: info.color),
                              const SizedBox(width: 6),
                              Text(
                                info.label.toUpperCase(),
                                style: AppTextStyles.caption.copyWith(
                                  color: info.color,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(g.title, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(g.explanation, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: AppConstants.spaceS),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: g.supplementNames.map((name) {
                              final removed = _removedNames.contains(name);
                              final entry = entryByName[name];
                              return Chip(
                                label: Text(
                                  name,
                                  style: AppTextStyles.caption.copyWith(
                                    color: removed ? AppColors.textTertiary : AppColors.textPrimary,
                                    decoration: removed ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                avatar: removed
                                    ? const Icon(Icons.check, size: 14, color: AppColors.evidenceGreen)
                                    : null,
                                deleteIcon: (!removed && entry != null)
                                    ? const Icon(Icons.close, size: 14)
                                    : null,
                                onDeleted: (!removed && entry != null)
                                    ? () {
                                        ref.read(stackProvider.notifier).remove(entry.id);
                                        setState(() => _removedNames.add(name));
                                      }
                                    : null,
                                backgroundColor: AppColors.surfaceVariant,
                                side: const BorderSide(color: AppColors.border),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppConstants.spaceM),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fertig'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
