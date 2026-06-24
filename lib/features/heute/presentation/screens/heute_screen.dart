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
import '../../../phase_goals/data/phase_goals_provider.dart';
import '../../../phase_goals/presentation/widgets/phase_goals_home_panel.dart';

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

          // ---- Daily Insights (horizontal scrollbar) ----
          const SliverToBoxAdapter(
            child: _DailyInsightsPanel(),
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

                // --- Profil-Empfehlungen Banner (nur bei leerem Stack) ---
                if (stack.isEmpty) ...[
                  const SizedBox(height: AppConstants.spaceL),
                  _ProfileRecommendationsBanner(),
                ],

                // --- Aktive Phasenziele Panel ---
                const SizedBox(height: AppConstants.spaceL),
                const PhaseGoalsHomePanel(),

                const SizedBox(height: AppConstants.spaceS),

                // --- Phasenziele Einstieg ---
                _PhaseGoalsCard(onTap: () => context.push(AppRoutes.phaseGoals)),

                const SizedBox(height: AppConstants.spaceL),

                // --- Entdecken Schnellzugang ---
                _DiscoverCard(onTap: () => context.go(AppRoutes.recommendations)),

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
                if (entry.isTemporary && entry.phaseEndDate != null) ...[
                  const SizedBox(height: 3),
                  _TemporaryBadgeSmall(endDate: entry.phaseEndDate!),
                ],
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

// ---------------------------------------------------------------------------
// Temporär-Badge (kompakt, für die Plan-Zeilen)
// ---------------------------------------------------------------------------

class _TemporaryBadgeSmall extends StatelessWidget {
  final DateTime endDate;
  const _TemporaryBadgeSmall({required this.endDate});

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
// Phasenziele Einstieg
// ---------------------------------------------------------------------------

class _PhaseGoalsCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _PhaseGoalsCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGoals = ref.watch(phaseGoalsProvider);
    final hasActive = activeGoals.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primaryLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Dekorative Kreise im Hintergrund
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              right: 60,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(AppConstants.radiusM),
                        ),
                        child: const Icon(Icons.flag_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const Spacer(),
                      if (hasActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                          ),
                          child: Text(
                            '${activeGoals.length} aktiv',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    'Phasenziele',
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Temporäre Supplement-Stacks für besondere Lebensphasen',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.80),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  // Beispiel-Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _PhaseChip(label: '🏃 Marathon'),
                      _PhaseChip(label: '📚 Prüfungsphase'),
                      _PhaseChip(label: '✈️ Reise'),
                      _PhaseChip(label: '💪 Muskelaufbau'),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Row(
                    children: [
                      Text(
                        hasActive
                            ? 'Ziele verwalten'
                            : 'Erstes Ziel starten',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final String label;
  const _PhaseChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entdecken Hero-Panel
// ---------------------------------------------------------------------------

class _DiscoverCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DiscoverCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Farbiger Header-Bereich
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent,
                    AppColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.radiusL),
                  topRight: Radius.circular(AppConstants.radiusL),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                          ),
                          child: Text(
                            'KI-gestützt',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Supplements\nentdecken',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Wähle ein Ziel — Claude analysiert\ndie Studienlage für dich',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceM),
                  // Großes Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    ),
                    child: const Icon(Icons.explore_rounded,
                        color: Colors.white, size: 34),
                  ),
                ],
              ),
            ),
            // Evidenz-Legende im unteren Teil
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jedes Supplement bewertet nach Studienlage:',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _EvidenceChip(
                        color: const Color(0xFF2E7D32),
                        bg: const Color(0xFFE8F5E9),
                        label: '● Belegt',
                      ),
                      const SizedBox(width: 8),
                      _EvidenceChip(
                        color: const Color(0xFFF57F17),
                        bg: const Color(0xFFFFF8E1),
                        label: '● Hinweise',
                      ),
                      const SizedBox(width: 8),
                      _EvidenceChip(
                        color: const Color(0xFFC62828),
                        bg: const Color(0xFFFFEBEE),
                        label: '● Unbelegt',
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_rounded,
                          color: AppColors.accent, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  final Color color;
  final Color bg;
  final String label;
  const _EvidenceChip({required this.color, required this.bg, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profil-Empfehlungen Banner (nur bei leerem Stack)
// ---------------------------------------------------------------------------

class _ProfileRecommendationsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.profileRecommendations),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.09),
              AppColors.accent.withOpacity(0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Passende Supplements für dich',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Personalisierte Empfehlungen basierend auf deinem Profil entdecken →',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
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

// ---------------------------------------------------------------------------
// Daily Insights Panel — horizontal scrollable, rotates daily
// ---------------------------------------------------------------------------

class _InsightCardData {
  final String category;
  final IconData icon;
  final String title;
  final String text;
  final List<Color> gradient;

  const _InsightCardData({
    required this.category,
    required this.icon,
    required this.title,
    required this.text,
    required this.gradient,
  });
}

class _DailyInsightsPanel extends StatelessWidget {
  const _DailyInsightsPanel();

  // Index rotiert täglich
  static int get _dayIndex {
    final now = DateTime.now();
    return now.difference(DateTime(now.year)).inDays;
  }

  static const List<_InsightCardData> _supplements = [
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Magnesium Bisglycinat',
      text: 'Die am besten bioverfügbare Magnesiumform. Unterstützt Muskelentspannung, Schlafqualität und Stressresistenz – ideal abends einzunehmen.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Vitamin D3 + K2',
      text: 'D3 reguliert Kalziumaufnahme und stärkt das Immunsystem. K2 sorgt dafür, dass Kalzium in die Knochen gelangt – nicht in Arterien.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Omega-3 (EPA/DHA)',
      text: 'Starke Evidenz für Herz-Kreislauf-Gesundheit, Entzündungshemmung und kognitive Funktion. Am besten mit einer fetthaltigen Mahlzeit.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Ashwagandha (KSM-66)',
      text: 'Adaptogen mit solider Studienlage: reduziert Cortisol messbar, verbessert Stressresilienz und unterstützt erholsamen Schlaf.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Zink Bisglycinat',
      text: 'Essenziell für Immunfunktion, Hormonbalance und Wundheilung. Bioverfügbarkeit von Bisglycinat deutlich höher als Zinkoxid.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Kreatin Monohydrat',
      text: 'Das am besten erforschte Supplement im Sport. Steigert Kraft, Ausdauer und kognitive Leistung – auch ohne Training sinnvoll.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Coenzym Q10',
      text: 'Kraftwerk der Mitochondrien. Besonders relevant ab 40 und bei Statin-Einnahme, da diese CoQ10 im Körper reduzieren.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Vitamin B12 (Methylcobalamin)',
      text: 'Lebensnotwendig für Nerven und Blutbildung. Methylcobalamin wird direkt verwertet – ideal für Veganer und ältere Erwachsene.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'L-Theanin',
      text: 'Aminosäure aus grünem Tee. Fördert entspannte Wachheit, reduziert Koffein-Nervosität und verbessert Fokus ohne Sedierung.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
    _InsightCardData(
      category: 'Supplement des Tages',
      icon: Icons.science_outlined,
      title: 'Selen',
      text: 'Antioxidans und Schilddrüsenhormon-Kofaktor. Für Hashimoto-Patienten besonders relevant – senkt TPO-Antikörper nachweislich.',
      gradient: [AppColors.primaryDark, AppColors.primary],
    ),
  ];

  static const List<_InsightCardData> _trends = [
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'Berberine als Metformin-Alternative',
      text: 'Pflanzlicher Wirkstoff zeigt in Studien ähnliche Effekte auf Blutzucker und Insulinsensitivität wie das verschreibungspflichtige Metformin.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'Magnesium Threonate für Gehirn',
      text: 'Als einzige Magnesiumform passiert Threonate die Blut-Hirn-Schranke effizient. Erste Studien zeigen positive Effekte auf Gedächtnis.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'NMN & Longevity-Forschung',
      text: 'NAD+-Vorläufer wie NMN rücken in den Fokus der Alterungsforschung. Erste Humanstudien laufen – bisher nur Tierdaten mit starken Effekten.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'Zyklussynchrones Supplementieren',
      text: 'Frauen passen ihren Stack an Zyklusphasen an: Eisen + B6 in der Follikelphase, Magnesium + Zink in der Lutealphase für optimale Wirkung.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'Rhodiola Rosea gegen Burnout',
      text: 'Adaptogen mit wachsender Evidenz bei mentaler Erschöpfung. Europäische Zulassung (EMA) bereits vorhanden – erhöht Stresstoleranz messbar.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'Spermidine & Autophagie',
      text: 'Natürlich in Weizenkeimen und Käse. Aktiviert Autophagie – den Selbstreinigungsprozess der Zellen. Vielversprechend für Longevity.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
    _InsightCardData(
      category: 'Trend des Monats',
      icon: Icons.trending_up_outlined,
      title: 'Kollagen-Peptide für Gelenke',
      text: 'Hydrolysiertes Kollagen zeigt in kontrollierten Studien Reduktion von Gelenkschmerzen bei Sportlern nach 12 Wochen regelmäßiger Einnahme.',
      gradient: [AppColors.accent, AppColors.primaryLight],
    ),
  ];

  static const List<_InsightCardData> _superfoods = [
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Blaubeeren',
      text: 'Höchste Antioxidantienkonzentration unter allen Früchten. Flavonoide schützen Nervenzellen und verbessern Gedächtnisleistung nachweislich.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Lachs & Hering',
      text: 'Beste natürliche Omega-3-Quelle. 100g Hering liefern 2g EPA/DHA – die Menge vieler Supplement-Kapseln. Zudem reich an Vitamin D.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Spinat & Mangold',
      text: 'Reich an Magnesium, Folat und Nitrat. Nitrat verbessert die Sauerstoffeffizienz in Muskeln – messbar in Ausdauerleistung.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Eier',
      text: 'Vollständiges Aminosäureprofil, Cholin für Gehirngesundheit, Lutein für Augen. Eines der nährstoffdichtesten Lebensmittel überhaupt.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Kurkuma + Pfeffer',
      text: 'Curcumin allein wird kaum aufgenommen. Piperin aus schwarzem Pfeffer erhöht die Bioverfügbarkeit um bis zu 2000% – immer gemeinsam verwenden.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Nüsse & Samen',
      text: 'Walnüsse liefern pflanzliche Omega-3 (ALA), Kürbiskerne sind reich an Zink, Paranüsse bieten die höste natürliche Selendosis.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Fermentierte Lebensmittel',
      text: 'Joghurt, Kefir und Kimchi liefern lebende Bakterienkulturen. Regelmäßiger Konsum erhöht die Mikrobiom-Diversität messbar.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
    _InsightCardData(
      category: 'Superfood',
      icon: Icons.eco_outlined,
      title: 'Brokkoli & Kreuzblütler',
      text: 'Sulforaphan aktiviert körpereigene Entgiftungsenzyme und hat starke antikarzinogene Eigenschaften – am wirksamsten roh oder leicht gedämpft.',
      gradient: [Color(0xFF065F46), AppColors.evidenceGreen],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _dayIndex;
    final cards = [
      _supplements[idx % _supplements.length],
      _trends[idx % _trends.length],
      _superfoods[idx % _superfoods.length],
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.78;

    return SizedBox(
      height: 178,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: AppConstants.screenPaddingH,
          right: AppConstants.screenPaddingH,
          top: AppConstants.spaceM,
          bottom: AppConstants.spaceM,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.only(
              right: i < cards.length - 1 ? AppConstants.spaceM : 0),
          child: _InsightCard(data: cards[i], width: cardWidth),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _InsightCardData data;
  final double width;

  const _InsightCard({required this.data, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradient,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: [
          BoxShadow(
            color: data.gradient.first.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        child: Stack(
          children: [
            // Dekorativer Kreis
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kategorie-Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(data.icon,
                          size: 13, color: Colors.white.withOpacity(0.80)),
                      const SizedBox(width: 5),
                      Text(
                        data.category,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withOpacity(0.80),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Großer Titel
                  Text(
                    data.title,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Beschreibung
                  Expanded(
                    child: Text(
                      data.text,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.82),
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
