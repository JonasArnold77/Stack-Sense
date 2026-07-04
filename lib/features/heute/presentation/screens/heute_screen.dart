import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../gamification/data/xp_provider.dart';
import '../../../insights/data/insights_provider.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/data/taken_provider.dart';
import '../widgets/checkin_summary_card.dart';
import '../widgets/daily_insights_panel.dart';
import '../widgets/goal_progress_panel.dart';
import '../widgets/insight_snippet_card.dart';
import '../widgets/plan_card.dart';
import '../widgets/profile_recommendations_banner.dart';
import '../widgets/progress_card.dart';
import '../widgets/quick_stat_chip.dart';
import '../widgets/section_title.dart';

/// Heute-Screen — täglicher Einstiegspunkt der App.
class HeuteScreen extends ConsumerWidget {
  const HeuteScreen({super.key});

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _greeting(int hour) {
    if (hour >= 5 && hour < 12) return 'Guten Morgen! 👋';
    if (hour >= 12 && hour < 17) return 'Guten Tag! ☀️';
    if (hour >= 17 && hour < 22) return 'Guten Abend! 🌙';
    return 'Gute Nacht! ✨';
  }

  static String _formatDate(DateTime d) {
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const months = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return '${weekdays[d.weekday - 1]}, ${d.day}. ${months[d.month]} ${d.year}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack        = ref.watch(stackProvider);
    final xpLevel      = ref.watch(xpLevelProvider);
    final insights     = ref.watch(insightsProvider);
    final checkinNotifier = ref.read(checkinProvider.notifier);

    ref.watch(checkinProvider); // rebuild on new check-in
    ref.watch(takenProvider);   // rebuild on intake toggle

    final today       = DateTime.now();
    final streak      = checkinNotifier.currentStreak;
    final hasCheckedIn = checkinNotifier.hasCheckedInToday;
    final todayEntry  = checkinNotifier.todayEntry;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ----------------------------------------------------------------
          // Greeting header
          // ----------------------------------------------------------------
          SliverToBoxAdapter(
            child: _GreetingHeader(
              greeting: _greeting(today.hour),
              dateStr: _formatDate(today),
              streak: streak,
              xpLevelLabel: 'Level ${xpLevel.level} · ${xpLevel.levelName}',
            ),
          ),

          // ----------------------------------------------------------------
          // Daily insights horizontal scroll
          // ----------------------------------------------------------------
          const SliverToBoxAdapter(child: DailyInsightsPanel()),

          // ----------------------------------------------------------------
          // Main content
          // ----------------------------------------------------------------
          SliverPadding(
            padding: const EdgeInsets.all(AppConstants.screenPaddingH),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Heutiger Einnahmeplan
                SectionTitle(
                  title: 'Heutiger Plan',
                  action: stack.isNotEmpty
                      ? TextButton(
                          onPressed: () => context.go(AppRoutes.stack),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Alle anzeigen →',
                            style: AppTextStyles.labelSmall
                                .copyWith(color: AppColors.accent),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppConstants.spaceS),
                PlanCard(stack: stack, today: today),

                // Profil-Empfehlungen Banner (nur bei leerem Stack)
                if (stack.isEmpty) ...[
                  const SizedBox(height: AppConstants.spaceL),
                  const ProfileRecommendationsBanner(),
                ],

                // Meine Ziele — Prominentes Panel
                const SizedBox(height: AppConstants.spaceL),
                const GoalProgressPanel(),

                const SizedBox(height: AppConstants.spaceL),

                // Tages-Check-in
                const SectionTitle(title: 'Tages-Check-in'),
                const SizedBox(height: AppConstants.spaceS),
                CheckinSummaryCard(
                  hasCheckedIn: hasCheckedIn,
                  todayEntry: todayEntry,
                  onTap: () => context.go(AppRoutes.checkin),
                ),

                const SizedBox(height: AppConstants.spaceL),

                // Fortschritt / XP / Level
                const SectionTitle(title: 'Mein Fortschritt'),
                const SizedBox(height: AppConstants.spaceS),
                ProgressCard(
                  xpLevel: xpLevel,
                  streak: streak,
                  onTap: () => context.go(AppRoutes.profile),
                ),

                // Insights Snippet (nur wenn Korrelations-Daten vorhanden)
                if (insights.hasCorrelations) ...[
                  const SizedBox(height: AppConstants.spaceL),
                  SectionTitle(
                    title: 'Dein Körper sagt',
                    action: TextButton(
                      onPressed: () => context.go(AppRoutes.insights),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Alle Insights →',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  InsightSnippetCard(insights: insights),
                ],

                // Bottom padding
                SizedBox(
                  height: AppConstants.spaceXXL +
                      MediaQuery.of(context).padding.bottom,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting header — screen-specific, not reused elsewhere
// ---------------------------------------------------------------------------

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String dateStr;
  final int streak;
  final String xpLevelLabel;

  const _GreetingHeader({
    required this.greeting,
    required this.dateStr,
    required this.streak,
    required this.xpLevelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D60CE), Color(0xFF0A2060)],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppConstants.spaceL,
        left: AppConstants.screenPaddingH,
        right: AppConstants.screenPaddingH,
        bottom: AppConstants.spaceXL + 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // StackSense logo row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.science_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'StackSense',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            dateStr,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.60),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            greeting,
            style: AppTextStyles.displayMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            children: [
              QuickStatChip(
                icon: Icons.local_fire_department,
                label: '$streak Tage Streak',
                color: AppColors.xpGold,
              ),
              const SizedBox(width: AppConstants.spaceS),
              QuickStatChip(
                icon: Icons.star_outline,
                label: xpLevelLabel,
                color: Colors.white.withOpacity(0.85),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
