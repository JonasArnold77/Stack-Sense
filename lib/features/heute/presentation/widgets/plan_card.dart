import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/day_key.dart';
import '../../../stack/data/recipe_override_provider.dart';
import '../../../stack/data/taken_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';
import '../../../recommendations/domain/models/supplement.dart';

// ---------------------------------------------------------------------------
// Temporär-Badge
// ---------------------------------------------------------------------------

class TemporaryBadgeSmall extends StatelessWidget {
  final DateTime endDate;
  const TemporaryBadgeSmall({super.key, required this.endDate});

  String get _formatted =>
      '${endDate.day.toString().padLeft(2, '0')}.${endDate.month.toString().padLeft(2, '0')}.${endDate.year}';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.flag_outlined, size: 9, color: AppColors.accent),
        const SizedBox(width: 3),
        Text(
          'Temporär · bis $_formatted',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rezept-Abdeckungs-Badge — "heute durch Rezept abgedeckt" (siehe
// RecipeOverrideNotifier). Gilt nur für den aktuellen Tag, dank
// datumsbasiertem Schlüssel automatisch zurückgesetzt am nächsten Tag.
// ---------------------------------------------------------------------------

class RecipeOverrideBadgeSmall extends StatelessWidget {
  final RecipeOverride recipeOverride;
  const RecipeOverrideBadgeSmall({super.key, required this.recipeOverride});

  @override
  Widget build(BuildContext context) {
    final label = recipeOverride.action == RecipeOverrideAction.removed
        ? 'Heute durch Rezept abgedeckt · ${recipeOverride.recipeTitle}'
        : 'Heute reduziert (${recipeOverride.recipeTitle})';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.restaurant_menu, size: 9, color: AppColors.accent),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kompakte Supplement-Zeile im Tagesplan
// ---------------------------------------------------------------------------

class CompactSupplementRow extends ConsumerWidget {
  final StackEntry entry;
  final DateTime today;

  const CompactSupplementRow({
    super.key,
    required this.entry,
    required this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takenNotifier = ref.read(takenProvider.notifier);
    ref.watch(takenProvider);
    final taken = takenNotifier.isTaken(entry.id, today);
    final override = ref.watch(recipeOverrideProvider)[dayKey(entry.id, today)];
    final isRemoved = override?.action == RecipeOverrideAction.removed;

    final evidenceColor = switch (entry.evidenceLevel) {
      EvidenceLevel.green  => AppColors.evidenceGreen,
      EvidenceLevel.yellow => AppColors.evidenceYellow,
      EvidenceLevel.red    => AppColors.evidenceRed,
    };

    final dosageText = override?.action == RecipeOverrideAction.reduced
        ? '${override!.reducedToAmount!.toStringAsFixed(0)}${override.reducedToUnit ?? ''} (statt ${entry.dosage})'
        : entry.dosage;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isRemoved
                  ? AppColors.accent
                  : (taken ? AppColors.evidenceGreen : evidenceColor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: (taken || isRemoved) ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: (taken || isRemoved) ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!isRemoved)
                  Text(dosageText,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                if (override != null) ...[
                  const SizedBox(height: 3),
                  RecipeOverrideBadgeSmall(recipeOverride: override),
                ] else if (entry.isTemporary && entry.phaseEndDate != null) ...[
                  const SizedBox(height: 3),
                  TemporaryBadgeSmall(endDate: entry.phaseEndDate!),
                ],
              ],
            ),
          ),
          if (!isRemoved)
            GestureDetector(
              onTap: () => takenNotifier.toggle(entry.id, today),
              child: AnimatedContainer(
                duration: AppConstants.animFast,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: taken ? AppColors.evidenceGreen : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  border: Border.all(
                    color: taken ? AppColors.evidenceGreen : AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: taken ? Colors.white : AppColors.border,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slot-Sektion (Morgen / Mittag / Abend / Nacht)
// ---------------------------------------------------------------------------

class PlanSlotSection extends ConsumerWidget {
  final IntakeSlot slot;
  final List<StackEntry> supplements;
  final DateTime today;
  final bool isCurrent;

  const PlanSlotSection({
    super.key,
    required this.slot,
    required this.supplements,
    required this.today,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takenNotifier = ref.read(takenProvider.notifier);
    ref.watch(takenProvider);
    final overrides = ref.watch(recipeOverrideProvider);

    // Heute durch Rezept abgedeckte Supplements zählen nicht als "offen" —
    // ein komplett abgedeckter Tag soll nicht fälschlich unvollständig wirken.
    final active = supplements
        .where((s) => overrides[dayKey(s.id, today)]?.action != RecipeOverrideAction.removed)
        .toList();
    final allTaken = active.every((s) => takenNotifier.isTaken(s.id, today));
    final takenCount = active.where((s) => takenNotifier.isTaken(s.id, today)).length;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(slot.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                slot.label,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text('Jetzt',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              Text(
                '$takenCount/${active.length}',
                style: AppTextStyles.caption.copyWith(
                  color: allTaken ? AppColors.evidenceGreen : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),
          ...supplements.map((entry) => CompactSupplementRow(entry: entry, today: today)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leerer Stack-Platzhalter
// ---------------------------------------------------------------------------

class EmptyPlanCard extends StatelessWidget {
  const EmptyPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline, color: AppColors.textTertiary, size: 20),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Text(
              'Noch keine Supplements im Stack.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tagesplan-Card (Hauptkomponente)
// ---------------------------------------------------------------------------

class PlanCard extends ConsumerWidget {
  final List<StackEntry> stack;
  final DateTime today;

  const PlanCard({super.key, required this.stack, required this.today});

  IntakeSlot get _currentSlot {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return IntakeSlot.morning;
    if (h >= 12 && h < 15) return IntakeSlot.noon;
    if (h >= 15 && h < 22) return IntakeSlot.evening;
    return IntakeSlot.night;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stack.isEmpty) return const EmptyPlanCard();

    final slotsWithSupplements = IntakeSlot.values
        .map((slot) => MapEntry(slot, stack.where((e) => e.intakeSlot == slot).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (slotsWithSupplements.isEmpty) return const EmptyPlanCard();

    final current = _currentSlot;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: slotsWithSupplements.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final slot = mapEntry.value.key;
          final supplements = mapEntry.value.value;
          final isLast = index == slotsWithSupplements.length - 1;
          return Column(
            children: [
              PlanSlotSection(
                slot: slot,
                supplements: supplements,
                today: today,
                isCurrent: slot == current,
              ),
              if (!isLast) const Divider(height: 1, color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}
