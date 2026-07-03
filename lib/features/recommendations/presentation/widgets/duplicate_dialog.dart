import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/supplement.dart';
import '../../../stack/domain/models/stack_entry.dart';

// ---------------------------------------------------------------------------
// Typen (public — werden vom Screen genutzt)
// ---------------------------------------------------------------------------

enum DuplicateAction { remove, keepBoth, cancel }

class DuplicateDialogResult {
  final DuplicateAction action;
  final List<String> toRemove; // IDs der zu entfernenden Einträge

  const DuplicateDialogResult({
    required this.action,
    this.toRemove = const [],
  });
}

// ---------------------------------------------------------------------------
// Dialog
// ---------------------------------------------------------------------------

class DuplicateDialog extends StatefulWidget {
  final Supplement newSupplement;
  final List<StackEntry> duplicates;
  final String reasoning;

  const DuplicateDialog({
    super.key,
    required this.newSupplement,
    required this.duplicates,
    this.reasoning = '',
  });

  @override
  State<DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<DuplicateDialog> {
  late Map<String, bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {for (final e in widget.duplicates) e.id: true};
  }

  List<String> get _selectedIds =>
      _checked.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  Widget build(BuildContext context) {
    final isMultiple = widget.duplicates.length > 1;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF6C00), size: 22),
          SizedBox(width: 8),
          Text('Wirkstoff bereits vorhanden'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMultiple
                ? 'Diese Wirkstoffe sind bereits in deinem Stack und werden durch '
                    '${widget.newSupplement.name} abgedeckt.\n\n'
                    'Welche möchtest du entfernen?'
                : '${widget.duplicates.first.name} ist bereits in deinem Stack '
                    'und wird durch ${widget.newSupplement.name} abgedeckt.\n\n'
                    'Möchtest du ${widget.duplicates.first.name} entfernen?',
            style: AppTextStyles.bodyMedium,
          ),
          if (widget.reasoning.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceM),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF6C00).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF6C00).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Color(0xFFEF6C00)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.reasoning,
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFFEF6C00),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isMultiple) ...[
            const SizedBox(height: AppConstants.spaceM),
            ...widget.duplicates.map((entry) => CheckboxListTile(
                  dense: true,
                  title: Text(entry.name, style: AppTextStyles.bodyMedium),
                  subtitle: entry.substanceName != null
                      ? Text(entry.substanceName!,
                          style: AppTextStyles.caption)
                      : null,
                  value: _checked[entry.id] ?? true,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) =>
                      setState(() => _checked[entry.id] = val ?? false),
                )),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const DuplicateDialogResult(action: DuplicateAction.cancel),
          ),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const DuplicateDialogResult(action: DuplicateAction.keepBoth),
          ),
          child: Text(
            'Beides behalten',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            DuplicateDialogResult(
              action: DuplicateAction.remove,
              toRemove: _selectedIds,
            ),
          ),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(isMultiple ? 'Markierte entfernen' : 'Ja, entfernen'),
        ),
      ],
    );
  }
}
