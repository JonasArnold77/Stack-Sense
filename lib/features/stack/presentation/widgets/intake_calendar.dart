import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/stack_provider.dart';
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

  const _TimeSlotSection({
    required this.slot,
    required this.supplements,
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
            ...supplements.map((entry) => _CalendarSupplementTile(entry: entry)),
        ],
      ),
    );
  }
}

class _CalendarSupplementTile extends StatelessWidget {
  final StackEntry entry;
  const _CalendarSupplementTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _evidenceColor(entry.evidenceLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: AppTextStyles.labelLarge),
                Text(entry.dosage, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (entry.intakeHint != null)
            Flexible(
              child: Text(
                entry.intakeHint!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.end,
                maxLines: 2,
              ),
            ),
          const SizedBox(width: AppConstants.spaceS),
          // Einnahme-Checkbox (visuell, TODO: echtes Tracking in Phase 2)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.check,
                size: 16, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Color _evidenceColor(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppColors.evidenceGreen,
        EvidenceLevel.yellow => AppColors.evidenceYellow,
        EvidenceLevel.red => AppColors.evidenceRed,
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
