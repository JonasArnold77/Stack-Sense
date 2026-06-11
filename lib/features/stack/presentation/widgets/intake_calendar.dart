import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/stack_provider.dart';
import '../../data/taken_provider.dart';
import '../../domain/models/stack_entry.dart';
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

class _CalendarSupplementTile extends ConsumerWidget {
  final StackEntry entry;
  final DateTime selectedDay;

  const _CalendarSupplementTile({
    required this.entry,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch löst Rebuild aus wenn sich der Set ändert
    ref.watch(takenProvider);
    final takenNotifier = ref.read(takenProvider.notifier);
    final taken = takenNotifier.isTaken(entry.id, selectedDay);
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
                                  entry.dosage,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceS),
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

                      // Einnahme-Button
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
                                onPressed: () =>
                                    takenNotifier.toggle(entry.id, selectedDay),
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
