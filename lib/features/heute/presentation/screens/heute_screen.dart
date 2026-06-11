import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../checkin/domain/models/checkin_entry.dart';
import '../../../gamification/data/xp_provider.dart';
import '../../../gamification/domain/models/xp_level.dart';
import '../../../insights/data/insights_provider.dart';
import '../../../insights/domain/models/insight_data.dart';

import '../../../stack/data/stack_provider.dart';
import '../../../stack/data/taken_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';
import '../../../recommendations/domain/models/supplement.dart';

/// Heute-Screen — täglicher Einstiegspunkt der App.
/// Zeigt: Begrüßung, heutiger Einnahmeplan, Check-in-Status, Streak/Level, Insights-Snippet.
class HeuteScreen extends ConsumerWidget {
  const HeuteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(stackProvider);
    final checkinNotifier = ref.read(checkinProvider.notifier);
    final xpLevel = ref.watch(xpLevelProvider);
    final insights = ref.watch(insightsProvider);
    ref.watch(checkinProvider); // rebuild bei neuem Check-in
    ref.watch(takenProvider);   // rebuild bei Einnahme-Toggle

    final today = DateTime.now();
    final hasCheckedIn = checkinNotifier.hasCheckedInToday;
    final todayEntry = checkinNotifier.todayEntry;
    final streak = checkinNotifier.currentStreak;

    // Begrüßung nach Tageszeit
    final hour = today.hour;
    final greetingText = hour >= 5 && hour < 12
        ? 'Guten Morgen! 👋'
        : hour >= 12 && hour < 17
            ? 'Guten Tag! ☀️'
            : hour >= 17 && hour < 22
                ? 'Guten Abend! 🌙'
                : 'Gute Nacht! ✨';

    // Datum formatieren
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final months = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    final dateStr =
        '${weekdays[today.weekday - 1]}, ${today.day}. ${months[today.month]} ${today.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ---- Greeting Header ----
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + AppConstants.spaceL,
                left: AppConstants.screenPaddingH,
                right: AppConstants.screenPaddingH,
                bottom: AppConstants.spaceXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withOpacity(0.65),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingText,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  // Schnell-Stats Zeile
                  Row(
                    children: [
                      _QuickStatChip(
                        icon: Icons.local_fire_department,
                        label: '$streak Tage Streak',
                        color: AppColors.xpGold,
                      ),
                      const SizedBox(width: AppConstants.spaceS),
                      _QuickStatChip(
                        icon: Icons.star_outline,
                        label: 'Level ${xpLevel.level} · ${xpLevel.levelName}',
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ---- Content ----
          SliverPadding(
            padding: const EdgeInsets.all(AppConstants.screenPaddingH),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // --- Heutiger Einnahmeplan ---
                _SectionTitle(
                  title: 'Heutiger Plan',
                  action: stack.isNotEmpty
                      ? TextButton(
                          onPressed: () => context.go(AppRoutes.stack),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Alle anzeigen →',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.accent)),
                        )
                      : null,
                ),
                const SizedBox(height: AppConstants.spaceS),
                _PlanCard(stack: stack, today: today),

                const SizedBox(height: AppConstants.spaceL),

                // --- Check-in ---
                _SectionTitle(title: 'Tages-Check-in'),
                const SizedBox(height: AppConstants.spaceS),
                _CheckinCard(
                  hasCheckedIn: hasCheckedIn,
                  todayEntry: todayEntry,
                  onTap: () => context.go(AppRoutes.checkin),
                ),

                const SizedBox(height: AppConstants.spaceL),

                // --- XP / Level ---
                _SectionTitle(title: 'Mein Fortschritt'),
                const SizedBox(height: AppConstants.spaceS),
                _ProgressCard(
                  xpLevel: xpLevel,
                  streak: streak,
                  onTap: () => context.go(AppRoutes.profile),
                ),

                // --- Insights Snippet (nur wenn Daten vorhanden) ---
                if (insights.hasCorrelations) ...[
                  const SizedBox(height: AppConstants.spaceL),
                  _SectionTitle(
                    title: 'Dein Körper sagt',
                    action: TextButton(
                      onPressed: () => context.go(AppRoutes.insights),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Alle Insights →',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.accent)),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  _InsightSnippetCard(insights: insights),
                ],

                // Bottom Padding
                SizedBox(
                    height: AppConstants.spaceXXL +
                        MediaQuery.of(context).padding.bottom),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Sub-Widgets ----

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.headlineSmall),
        if (action != null) action!,
      ],
    );
  }
}

// ---- Plan Card ----

class _PlanCard extends ConsumerWidget {
  final List<StackEntry> stack;
  final DateTime today;

  const _PlanCard({required this.stack, required this.today});

  IntakeSlot get _currentSlot {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return IntakeSlot.morning;
    if (h >= 12 && h < 15) return IntakeSlot.noon;
    if (h >= 15 && h < 22) return IntakeSlot.evening;
    return IntakeSlot.night;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stack.isEmpty) {
      return _EmptyPlanCard();
    }

    // Nur Slots die Supplements haben
    final slotsWithSupplements = IntakeSlot.values
        .map((slot) => MapEntry(slot, stack.where((e) => e.intakeSlot == slot).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (slotsWithSupplements.isEmpty) {
      return _EmptyPlanCard();
    }

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
          final isCurrent = slot == current;

          return Column(
            children: [
              _PlanSlotSection(
                slot: slot,
                supplements: supplements,
                today: today,
                isCurrent: isCurrent,
              ),
              if (!isLast)
                const Divider(height: 1, color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PlanSlotSection extends ConsumerWidget {
  final IntakeSlot slot;
  final List<StackEntry> supplements;
  final DateTime today;
  final bool isCurrent;

  const _PlanSlotSection({
    required this.slot,
    required this.supplements,
    required this.today,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takenNotifier = ref.read(takenProvider.notifier);
    ref.watch(takenProvider);
    final allTaken = supplements.every((s) => takenNotifier.isTaken(s.id, today));
    final takenCount = supplements.where((s) => takenNotifier.isTaken(s.id, today)).length;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot Header
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
              // Fortschritts-Zähler
              Text(
                '$takenCount/${supplements.length}',
                style: AppTextStyles.caption.copyWith(
                  color: allTaken ? AppColors.evidenceGreen : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),

          // Supplement-Zeilen
          ...supplements.map((entry) => _CompactSupplementRow(
                entry: entry,
                today: today,
              )),
        ],
      ),
    );
  }
}

class _CompactSupplementRow extends ConsumerWidget {
  final StackEntry entry;
  final DateTime today;

  const _CompactSupplementRow({required this.entry, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takenNotifier = ref.read(takenProvider.notifier);
    ref.watch(takenProvider);
    final taken = takenNotifier.isTaken(entry.id, today);

    final evidenceColor = switch (entry.evidenceLevel) {
      EvidenceLevel.green => AppColors.evidenceGreen,
      EvidenceLevel.yellow => AppColors.evidenceYellow,
      EvidenceLevel.red => AppColors.evidenceRed,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
      child: Row(
        children: [
          // Farbpunkt
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: taken ? AppColors.evidenceGreen : evidenceColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          // Name + Dosierung
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: taken ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: taken ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  entry.dosage,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          // Toggle Button
          GestureDetector(
            onTap: () => takenNotifier.toggle(entry.id, today),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: taken
                    ? AppColors.evidenceGreen
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
                border: Border.all(
                  color: taken ? AppColors.evidenceGreen : AppColors.border,
                ),
              ),
              child: Icon(
                taken ? Icons.check : Icons.check,
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

class _EmptyPlanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
            color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline,
              color: AppColors.textTertiary, size: 20),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Text(
              'Noch keine Supplements im Stack.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Check-in Card ----

class _CheckinCard extends StatelessWidget {
  final bool hasCheckedIn;
  final CheckinEntry? todayEntry;
  final VoidCallback onTap;

  const _CheckinCard({
    required this.hasCheckedIn,
    required this.todayEntry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCheckedIn) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withOpacity(0.85),
                AppColors.primaryLight,
              ],
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wie geht es dir heute?',
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trage dein Befinden ein — dauert 30 Sekunden.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusM),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      );
    }

    // Check-in heute bereits erfolgt
    final entry = todayEntry!;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.evidenceGreen.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.evidenceGreen, size: 18),
              const SizedBox(width: AppConstants.spaceS),
              Text('Heute eingecheckt',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.evidenceGreen,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: onTap,
                child: Text('Bearbeiten',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            children: [
              _MetricBar(label: '⚡', value: entry.energy),
              const SizedBox(width: AppConstants.spaceS),
              _MetricBar(label: '😴', value: entry.sleep),
              const SizedBox(width: AppConstants.spaceS),
              _MetricBar(label: '🧠', value: entry.focus),
              const SizedBox(width: AppConstants.spaceS),
              _MetricBar(label: '😊', value: entry.mood),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final int value; // 1-5

  const _MetricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final fill = value / 5.0;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                _barColor(value),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text('$value/5',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Color _barColor(int v) {
    if (v >= 4) return AppColors.evidenceGreen;
    if (v >= 3) return AppColors.evidenceYellow;
    return AppColors.evidenceRed;
  }
}

// ---- Progress Card ----

class _ProgressCard extends StatelessWidget {
  final XpLevel xpLevel;
  final int streak;
  final VoidCallback onTap;

  const _ProgressCard({
    required this.xpLevel,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Level Badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: Center(
                child: Text(
                  '${xpLevel.level}',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(xpLevel.levelName,
                          style: AppTextStyles.labelLarge
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        xpLevel.isMaxLevel
                            ? 'Max!'
                            : '${xpLevel.xpRemaining} XP bis Level ${xpLevel.level + 1}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpLevel.progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.xpGold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 13, color: AppColors.xpGold),
                      const SizedBox(width: 3),
                      Text('$streak Tage Streak',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                      const SizedBox(width: AppConstants.spaceM),
                      const Icon(Icons.star_outline,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text('${xpLevel.totalXp} XP',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceS),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---- Insights Snippet ----

class _InsightSnippetCard extends StatelessWidget {
  final InsightsData insights;

  const _InsightSnippetCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    // Beste positive Korrelation zeigen
    final positives = insights.correlations
        .where((c) => c.isPositive && c.isSignificant)
        .toList()
      ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));

    if (positives.isEmpty) {
      // Nur negatives / keine signifikante
      return const SizedBox.shrink();
    }

    final best = positives.first;
    // dimension-Keys sind Deutsch: 'Energie', 'Schlaf', 'Fokus', 'Stimmung', 'Gesamt'
    final dimLabel = switch (best.dimension) {
      'Energie' => 'Energie ⚡',
      'Schlaf' => 'Schlaf 😴',
      'Fokus' => 'Fokus 🧠',
      'Stimmung' => 'Stimmung 😊',
      _ => best.dimension,
    };
    final changeStr =
        '${best.changePercent >= 0 ? '+' : ''}${best.changePercent.toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.evidenceGreenLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
            color: AppColors.evidenceGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.evidenceGreen.withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusM),
            ),
            child: const Center(
              child: Text('📈', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${best.supplementName} wirkt',
                  style: AppTextStyles.labelLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dimLabel hat sich seit Einnahme um $changeStr verbessert.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
