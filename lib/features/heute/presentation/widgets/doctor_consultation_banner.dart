import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../recommendations/domain/models/supplement.dart';
import '../../../stack/data/doctor_consultation_provider.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';

/// Supplements mit moderater/starker Wechselwirkungswarnung dürfen zwar in
/// den Stack aufgenommen werden (keine Blockade beim Hinzufügen) — aber
/// solange der Nutzer nicht separat bestätigt hat, das mit einem Arzt
/// besprochen zu haben, erscheint hier ein auffälliges Warnfeld auf dem
/// Heute-Screen, das nicht einfach im "Mein Stack"-Tab untergeht.
bool _needsDoctorConfirmation(StackEntry entry) =>
    entry.interactionSeverity == InteractionSeverity.moderate ||
    entry.interactionSeverity == InteractionSeverity.high;

class DoctorConsultationBanner extends ConsumerWidget {
  const DoctorConsultationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(stackProvider);
    final confirmed = ref.watch(doctorConsultationProvider);
    final pending = stack.where((e) => _needsDoctorConfirmation(e) && !confirmed.contains(e.id)).toList();

    if (pending.isEmpty) return const SizedBox.shrink();

    final hasHigh = pending.any((e) => e.interactionSeverity == InteractionSeverity.high);
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
          if (entry.drugInteraction != null) ...[
            const SizedBox(height: 2),
            Text(
              entry.drugInteraction!,
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
