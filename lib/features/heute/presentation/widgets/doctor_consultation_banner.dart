import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../../recommendations/domain/models/supplement_safety_warning.dart';
import '../../../stack/data/doctor_consultation_provider.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';

/// Zwei unabhängige Gründe, warum ein Supplement hier auftaucht:
/// (1) moderate/starke Wechselwirkung mit einem Medikament, oder
/// (2) Überdosierungsrisiko der Substanz selbst (siehe
/// SupplementSafetyWarning — z.B. Vitamin D3, Eisen). Letzteres wird beim
/// Hinzufügen zum Stack bereits EINMALIG per SafetyWarningDialog bestätigt
/// ("Ich habe die Warnung gelesen") — das ist aber nur ein Lese-Nachweis,
/// keine ärztliche Rücksprache. Diese zweite, separate Bestätigung bleibt
/// deshalb PFLICHT und dauerhaft sichtbar, bis sie explizit gegeben wird.
bool _needsDoctorConfirmation(StackEntry entry) =>
    entry.interactionSeverity == InteractionSeverity.moderate ||
    entry.interactionSeverity == InteractionSeverity.high ||
    getSupplementSafetyWarning(entry.id) != null;

class _WarningInfo {
  final String kicker;
  final String message;
  const _WarningInfo(this.kicker, this.message);
}

/// Überdosierungsrisiko hat Vorrang in der Anzeige (das ist der Fall, den
/// der Nutzer auf keinen Fall übersehen soll), Wechselwirkung als Fallback.
_WarningInfo? _warningInfoFor(StackEntry entry) {
  final safety = getSupplementSafetyWarning(entry.id);
  if (safety != null) return _WarningInfo('Überdosierungsrisiko', safety.message);
  if (entry.drugInteraction != null) {
    final kicker =
        entry.interactionSeverity == InteractionSeverity.high ? 'Starke Wechselwirkung' : 'Wechselwirkung';
    return _WarningInfo(kicker, entry.drugInteraction!);
  }
  return null;
}

class DoctorConsultationBanner extends ConsumerWidget {
  const DoctorConsultationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(stackProvider);
    final confirmed = ref.watch(doctorConsultationProvider);
    final pending = stack.where((e) => _needsDoctorConfirmation(e) && !confirmed.contains(e.id)).toList();

    if (pending.isEmpty) return const SizedBox.shrink();

    // Überdosierungsrisiko zählt genauso als "höchste Stufe" wie eine starke
    // Wechselwirkung — beides soll unübersehbar rot sein, kein blasses Orange.
    final hasHigh = pending.any((e) =>
        e.interactionSeverity == InteractionSeverity.high || getSupplementSafetyWarning(e.id) != null);
    final accent = hasHigh ? const Color(0xFFC62828) : const Color(0xFFEF6C00);
    final bg = hasHigh ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceL),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital_outlined, color: accent, size: 20),
              const SizedBox(width: AppConstants.spaceS),
              Expanded(
                child: Text(
                  pending.length == 1
                      ? 'Ärztliche Rücksprache empfohlen'
                      : '${pending.length} Supplements: Ärztliche Rücksprache empfohlen',
                  style: AppTextStyles.labelLarge.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            'Bitte bestätige für jedes Supplement unten, dass du die Einnahme mit einem Arzt besprochen hast.',
            style: AppTextStyles.bodySmall.copyWith(color: accent.withOpacity(0.9)),
          ),
          const SizedBox(height: AppConstants.spaceM),
          ...pending.map((e) => _PendingEntryRow(entry: e, accent: accent)),
        ],
      ),
    );
  }
}

class _PendingEntryRow extends ConsumerWidget {
  final StackEntry entry;
  final Color accent;

  const _PendingEntryRow({required this.entry, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warning = _warningInfoFor(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.name, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
          if (warning != null) ...[
            const SizedBox(height: 4),
            Text(
              warning.kicker.toUpperCase(),
              style: AppTextStyles.caption.copyWith(color: accent, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
            const SizedBox(height: 2),
            Text(
              warning.message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppConstants.spaceS),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(doctorConsultationProvider.notifier).confirm(entry.id),
              icon: Icon(Icons.check_circle_outline, size: 16, color: accent),
              label: Text('Mit Arzt besprochen', style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusM)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
