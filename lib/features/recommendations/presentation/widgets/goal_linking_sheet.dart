import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Gemeinsame Ziele die in der Auswahl erscheinen.
const _kCommonGoals = [
  'Schlaf',
  'Energie',
  'Immunsystem',
  'Fokus',
  'Sport',
  'Stress',
  'Herzgesundheit',
  'Verdauung',
  'Knochen',
  'Haare & Haut',
];

/// Farb-Map für bekannte Ziele.
const Map<String, Color> kGoalColors = {
  'Schlaf': Color(0xFF3F51B5),
  'Energie': Color(0xFFE65100),
  'Immunsystem': Color(0xFF2E7D32),
  'Fokus': Color(0xFF6A1B9A),
  'Sport': Color(0xFFD32F2F),
  'Stress': Color(0xFF0277BD),
  'Herzgesundheit': Color(0xFFAD1457),
  'Verdauung': Color(0xFF558B2F),
  'Knochen': Color(0xFF4E342E),
  'Haare & Haut': Color(0xFF00838F),
};

/// Gibt die Farbe für ein Ziel zurück, fallback = primary.
Color goalColor(String goal) => kGoalColors[goal] ?? AppColors.primary;

/// Öffnet ein BottomSheet zum Verknüpfen eines bereits im Stack befindlichen
/// Supplements mit einem weiteren Ziel.
///
/// Gibt den ausgewählten Ziel-String zurück, oder null wenn abgebrochen.
Future<String?> showGoalLinkingSheet({
  required BuildContext context,
  required String supplementName,
  required List<String> existingGoalIds,
  required List<String> supplementCategories,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GoalLinkingSheet(
      supplementName: supplementName,
      existingGoalIds: existingGoalIds,
      supplementCategories: supplementCategories,
    ),
  );
}

// ---------------------------------------------------------------------------
// Sheet-Widget
// ---------------------------------------------------------------------------

class _GoalLinkingSheet extends StatefulWidget {
  final String supplementName;
  final List<String> existingGoalIds;
  final List<String> supplementCategories;

  const _GoalLinkingSheet({
    required this.supplementName,
    required this.existingGoalIds,
    required this.supplementCategories,
  });

  @override
  State<_GoalLinkingSheet> createState() => _GoalLinkingSheetState();
}

class _GoalLinkingSheetState extends State<_GoalLinkingSheet> {
  String? _selected;

  /// Alle möglichen Ziele: erst Kategorien des Supplements, dann allgemeine.
  List<String> get _allGoals {
    final seen = <String>{};
    final result = <String>[];

    for (final c in widget.supplementCategories) {
      if (seen.add(c)) result.add(c);
    }
    for (final g in _kCommonGoals) {
      if (seen.add(g)) result.add(g);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final goals = _allGoals;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.spaceM,
        AppConstants.screenPaddingH,
        AppConstants.spaceM + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),

          // Titel
          Text(
            '${widget.supplementName} mit einem Ziel verknüpfen',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppConstants.spaceXS),

          if (widget.existingGoalIds.isNotEmpty) ...[
            Text(
              'Bereits aktiv für: ${widget.existingGoalIds.join(', ')}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppConstants.spaceM),
          ] else
            const SizedBox(height: AppConstants.spaceM),

          // Ziel-Chips
          Wrap(
            spacing: AppConstants.spaceS,
            runSpacing: AppConstants.spaceS,
            children: goals.map((goal) {
              final isExisting = widget.existingGoalIds.contains(goal);
              final isSelected = _selected == goal;
              final color = goalColor(goal);

              return GestureDetector(
                onTap: isExisting
                    ? null
                    : () => setState(() =>
                        _selected = isSelected ? null : goal),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM,
                    vertical: AppConstants.spaceS,
                  ),
                  decoration: BoxDecoration(
                    color: isExisting
                        ? AppColors.border.withOpacity(0.3)
                        : isSelected
                            ? color
                            : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                    border: Border.all(
                      color: isExisting
                          ? AppColors.border
                          : isSelected
                              ? color
                              : color.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      Text(
                        goal,
                        style: AppTextStyles.caption.copyWith(
                          color: isExisting
                              ? AppColors.textTertiary
                              : isSelected
                                  ? Colors.white
                                  : color,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (isExisting) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_outline,
                            size: 12,
                            color: AppColors.textTertiary),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppConstants.spaceL),

          // Button-Zeile
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: const Text('Verknüpfen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
