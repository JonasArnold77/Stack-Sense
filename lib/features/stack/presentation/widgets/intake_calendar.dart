import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/day_key.dart';
import '../../../../core/widgets/xp_reward_overlay.dart';
import '../../data/recipe_override_provider.dart';
import '../../data/stack_provider.dart';
import '../../data/taken_provider.dart';
import '../../domain/models/stack_entry.dart';
import '../../../gamification/data/xp_provider.dart';
import '../../../recommendations/domain/models/supplement.dart';

/// Einnahme-Kalender — zeigt die Supplements in Zeitslots (Morgen/Mittag/Abend/Nacht).
/// Wochenansicht: aktuelle Woche, heute hervorgehoben.
class IntakeCalendar extends ConsumerStatefulWidget {
  const IntakeCalendar({super.key});

  @override
  ConsumerState<IntakeCalendar> createState() => _IntakeCalendarState();
}

class _IntakeCalendarState extends ConsumerState<IntakeCalendar> {
  // Heute als Index 0-6 (Mo-So)
  late int _selectedDayIndex;
  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _buildWeek();
  }

  void _buildWeek() {
    final now = DateTime.now();
    // Montag der aktuellen Woche
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    _selectedDayIndex = now.weekday - 1; // 0 = Montag
  }

  @override
  Widget build(BuildContext context) {
    final stack = ref.watch(stackProvider);

    return Column(
      children: [
        // --- Wochenstreifen ---
        _WeekStrip(
          days: _weekDays,
          selectedIndex: _selectedDayIndex,
          onDayTap: (i) => setState(() => _selectedDayIndex = i),
        ),

        const SizedBox(height: AppConstants.spaceL),

        // --- Zeitslots ---
        if (stack.isEmpty)
          _EmptyCalendar()
        else
          ...IntakeSlot.values.map((slot) {
            final supplements =
                stack.where((e) => e.intakeSlot == slot).toList();
            return _TimeSlotSection(
              slot: slot,
              supplements: supplements,
              selectedDay: _weekDays[_selectedDayIndex],
            );
          }),
      ],
    );
  }
}

// ---- Sub-Widgets ----

class _WeekStrip extends StatelessWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final void Function(int) onDayTap;

  const _WeekStrip({
    required this.days,
    required this.selectedIndex,
    required this.onDayTap,
  });

  static const _dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Row(
      children: List.generate(7, (i) {
        final day = days[i];
        final isToday = day.day == today.day &&
            day.month == today.month &&
            day.year == today.year;
        final isSelected = i == selectedIndex;

        return Expanded(
          child: GestureDetector(
            onTap: () => onDayTap(i),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceXS),
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceS),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Column(
                children: [
                  Text(
                    _dayNames[i],
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primary
                              : AppColors.textPrimary,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  // Heute-Punkt
                  if (isToday && !isSelected)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimeSlotSection extends StatelessWidget {
  final IntakeSlot slot;
  final List<StackEntry> supplements;
  final DateTime selectedDay;

  const _TimeSlotSection({
    required this.slot,
    required this.supplements,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot-Header
          Row(
            children: [
              Text(slot.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: AppConstants.spaceS),
              Text(slot.label, style: AppTextStyles.headlineSmall),
              const SizedBox(width: AppConstants.spaceS),
              if (supplements.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    '${supplements.length}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppConstants.spaceM),

          if (supplements.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
                vertical: AppConstants.spaceM,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid),
              ),
              child: Text(
                'Keine Supplements für diesen Zeitslot',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            )
          else
            ...supplements.map((entry) => _CalendarSupplementTile(
                  entry: entry,
                  selectedDay: selectedDay,
                )),
        ],
      ),
    );
  }
}

/// Rundet auf eine sinnvolle Nachkommastellenzahl — ganze Zahlen ohne
/// Nachkommastellen, kleinere Mengen (z.B. Vitamin-D-IE oder Bruchteile
/// eines Gramms) mit einer Nachkommastelle.
String _fmtAmount(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

Future<double?> _promptAmount(
  BuildContext context, {
  required String unit,
  required double initial,
}) {
  final controller = TextEditingController(
    text: initial > 0 ? _fmtAmount(initial) : '',
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Menge eingeben'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))],
        decoration: InputDecoration(suffixText: unit),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
            Navigator.of(ctx).pop(parsed);
          },
          child: const Text('Speichern'),
        ),
      ],
    ),
  );
}

class _CalendarSupplementTile extends ConsumerWidget {
  final StackEntry entry;
  final DateTime selectedDay;

  const _CalendarSupplementTile({
    required this.entry,
    required this.selectedDay,
  });

  Future<void> _awardXpIfNewlyComplete(WidgetRef ref, bool wasComplete, bool isComplete) async {
    if (wasComplete || !isComplete) return;
    ref.read(xpProvider.notifier).addXp(15);
    ref.read(xpRewardProvider.notifier).state =
        XpRewardEvent(amount: 15, id: DateTime.now().microsecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch löst Rebuild aus wenn sich Einnahme- oder Rezept-Status ändert
    ref.watch(takenProvider);
    final takenNotifier = ref.read(takenProvider.notifier);
    final recipeOverride = ref.watch(recipeOverrideProvider)[dayKey(entry.id, selectedDay)];
    final isRecipeCovered = recipeOverride?.action == RecipeOverrideAction.removed;

    final hasStructuredDose = entry.dosageAmount != null && entry.dosageUnit != null;
    final unit = entry.dosageUnit;

    // Ziel für die manuelle Einnahme heute: die volle Dosis, oder — falls ein
    // Rezept heute schon einen Teil abdeckt — nur der verbleibende Rest.
    double? target = entry.dosageAmount;
    if (hasStructuredDose &&
        recipeOverride?.action == RecipeOverrideAction.reduced &&
        recipeOverride!.reducedToUnit == unit) {
      target = recipeOverride.reducedToAmount;
    }

    final takenAmount = hasStructuredDose ? takenNotifier.amountTaken(entry.id, selectedDay) : 0.0;
    final remaining = hasStructuredDose ? (target! - takenAmount).clamp(0, target).toDouble() : 0.0;
    final fullyDone = isRecipeCovered ||
        (hasStructuredDose ? remaining <= 0 : takenNotifier.isTaken(entry.id, selectedDay));
    final taken = fullyDone;
    final evidenceColor = _evidenceColor(entry.evidenceLevel);

    return AnimatedContainer(
      duration: AppConstants.animFast,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      decoration: BoxDecoration(
        color: taken
            ? AppColors.evidenceGreen.withOpacity(0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: taken ? AppColors.evidenceGreen.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Evidenzfarb-Streifen links
              Container(
                width: 4,
                color: evidenceColor,
              ),
              // Inhalt
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Dosierung
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: taken
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    decoration: taken
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasStructuredDose
                                      ? 'Ziel: ${_fmtAmount(entry.dosageAmount!)}$unit'
                                      : entry.dosage,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (isRecipeCovered) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '🍽 Heute komplett durch Rezept abgedeckt',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.evidenceGreen, fontWeight: FontWeight.w600),
                                  ),
                                ] else if (hasStructuredDose) ...[
                                  if (recipeOverride?.action == RecipeOverrideAction.reduced)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '🍽 ${_fmtAmount(entry.dosageAmount! - target!)}$unit durch Rezept abgedeckt',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      remaining <= 0
                                          ? '✓ Vollständig eingenommen'
                                          : 'Noch ${_fmtAmount(remaining.toDouble())}$unit nötig'
                                              '${takenAmount > 0 ? ' (${_fmtAmount(takenAmount)}$unit bereits genommen)' : ''}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: remaining <= 0 ? AppColors.evidenceGreen : AppColors.textTertiary,
                                        fontWeight: remaining <= 0 ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceS),
                          // Badges-Spalte rechts
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Evidenz-Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: evidenceColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusRound),
                                ),
                                child: Text(
                                  _evidenceLabel(entry.evidenceLevel),
                                  style: AppTextStyles.caption.copyWith(
                                    color: evidenceColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Temporär-Badge
                              if (entry.isTemporary &&
                                  entry.phaseEndDate != null) ...[
                                const SizedBox(height: 4),
                                _TemporaryBadge(
                                    endDate: entry.phaseEndDate!),
                              ],
                            ],
                          ),
                        ],
                      ),

                      // Einnahme-Hinweis
                      if (entry.intakeHint != null) ...[
                        const SizedBox(height: AppConstants.spaceS),
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 12, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                entry.intakeHint!,
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textTertiary),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: AppConstants.spaceM),

                      // Einnahme-Aktionen
                      if (isRecipeCovered)
                        const SizedBox.shrink()
                      else if (hasStructuredDose)
                        Row(
                          children: [
                            Expanded(
                              child: remaining <= 0
                                  ? OutlinedButton.icon(
                                      onPressed: () =>
                                          takenNotifier.uncheck(entry.id, selectedDay),
                                      icon: const Icon(Icons.check_circle,
                                          size: 16, color: AppColors.evidenceGreen),
                                      label: Text('Eingenommen',
                                          style: AppTextStyles.labelMedium
                                              .copyWith(color: AppColors.evidenceGreen)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: AppColors.evidenceGreen.withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                        ),
                                      ),
                                    )
                                  : FilledButton.icon(
                                      onPressed: () async {
                                        await takenNotifier.setAmount(entry.id, selectedDay, target!);
                                        await _awardXpIfNewlyComplete(ref, false, true);
                                      },
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Alles einchecken'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary.withOpacity(0.1),
                                        foregroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: AppConstants.spaceS),
                            OutlinedButton(
                              onPressed: () async {
                                final wasComplete = remaining <= 0;
                                final entered = await _promptAmount(
                                  context,
                                  unit: unit!,
                                  initial: takenAmount,
                                );
                                if (entered == null) return;
                                await takenNotifier.setAmount(entry.id, selectedDay, entered);
                                await _awardXpIfNewlyComplete(ref, wasComplete, entered >= target!);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                ),
                              ),
                              child: const Icon(Icons.edit_outlined, size: 16),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: taken
                              ? OutlinedButton.icon(
                                  onPressed: () =>
                                      takenNotifier.toggle(entry.id, selectedDay),
                                  icon: const Icon(Icons.check_circle,
                                      size: 16,
                                      color: AppColors.evidenceGreen),
                                  label: Text(
                                    'Eingenommen',
                                    style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.evidenceGreen),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: AppColors.evidenceGreen
                                            .withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.radiusM),
                                    ),
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: () async {
                                    await takenNotifier.toggle(entry.id, selectedDay);
                                    // 15 XP vergeben + Belohnungsanimation auslösen
                                    ref.read(xpProvider.notifier).addXp(15);
                                    ref.read(xpRewardProvider.notifier).state =
                                        XpRewardEvent(
                                      amount: 15,
                                      id: DateTime.now().microsecondsSinceEpoch,
                                    );
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Als eingenommen markieren'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.1),
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.radiusM),
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _evidenceColor(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppColors.evidenceGreen,
        EvidenceLevel.yellow => AppColors.evidenceYellow,
        EvidenceLevel.red => AppColors.evidenceRed,
      };

  String _evidenceLabel(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppConstants.evidenceGreenLabel,
        EvidenceLevel.yellow => AppConstants.evidenceYellowLabel,
        EvidenceLevel.red => AppConstants.evidenceRedLabel,
      };
}

/// Lila Badge für temporäre Phasenziel-Supplements.
class _TemporaryBadge extends StatelessWidget {
  final DateTime endDate;
  const _TemporaryBadge({required this.endDate});

  static const _accent = Color(0xFF5C35CC);

  String get _formatted =>
      '${endDate.day.toString().padLeft(2, '0')}.${endDate.month.toString().padLeft(2, '0')}.${endDate.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: _accent.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_outlined, size: 10, color: _accent),
          const SizedBox(width: 3),
          Text(
            'Temporär · bis $_formatted',
            style: AppTextStyles.caption.copyWith(
              color: _accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: AppConstants.spaceM),
            Text('Kein Einnahmeplan',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spaceS),
            Text(
              'Füge Supplements zu deinem Stack hinzu — '
              'sie erscheinen automatisch hier.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
