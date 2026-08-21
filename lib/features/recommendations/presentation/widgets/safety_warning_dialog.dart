import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/supplement_safety_warning.dart';

/// Warnung mit aktiver Bestätigungspflicht, bevor ein Supplement mit
/// Überdosierungs-/Sicherheitsrisiko zum Stack hinzugefügt wird.
///
/// Gibt `true` zurück, wenn der Nutzer aktiv bestätigt hat, sonst `null`/`false`.
/// Zeigt bei Bedarf [SafetyWarningDialog] für die gegebene Supplement-ID an.
/// Gibt `true` zurück, wenn kein Warnhinweis existiert oder der Nutzer aktiv
/// bestätigt hat — `false`, wenn der Nutzer abgebrochen hat.
Future<bool> confirmSupplementSafetyIfNeeded(
  BuildContext context, {
  required String supplementId,
  required String supplementName,
}) async {
  final warning = getSupplementSafetyWarning(supplementId);
  if (warning == null) return true;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SafetyWarningDialog(
      supplementName: supplementName,
      warning: warning,
    ),
  );
  return confirmed ?? false;
}

class SafetyWarningDialog extends StatefulWidget {
  final String supplementName;
  final SupplementSafetyWarning warning;

  const SafetyWarningDialog({
    super.key,
    required this.supplementName,
    required this.warning,
  });

  @override
  State<SafetyWarningDialog> createState() => _SafetyWarningDialogState();
}

class _SafetyWarningDialogState extends State<SafetyWarningDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF6C00), size: 22),
          SizedBox(width: 8),
          Text('Überdosierungsrisiko'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.supplementName} kann bei falscher Dosierung gesundheitsschädlich sein.',
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600),
          ),
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
                    widget.warning.message,
                    style: AppTextStyles.caption.copyWith(
                      color: const Color(0xFFEF6C00),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          InkWell(
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acknowledged,
                  activeColor: AppColors.primary,
                  onChanged: (val) =>
                      setState(() => _acknowledged = val ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Ich habe die Warnung gelesen und möchte trotzdem fortfahren.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed:
              _acknowledged ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Trotzdem hinzufügen'),
        ),
      ],
    );
  }
}
