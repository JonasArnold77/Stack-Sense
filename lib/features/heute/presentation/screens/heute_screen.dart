import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/recommendation_local_cache.dart';
import '../../../../core/widgets/feature_gate.dart';
import '../../../settings/domain/models/feature_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../gamification/data/xp_provider.dart';
import '../../../insights/data/insights_provider.dart';
import '../../../onboarding/data/onboarding_provider.dart';
import '../../../settings/data/recommendation_mode_provider.dart';
import '../../../settings/domain/models/recommendation_mode.dart';
import '../../../settings/data/recommendation_source_mode_provider.dart';
import '../../../settings/domain/models/recommendation_source_mode.dart';
import '../../../settings/data/cache_mode_provider.dart';
import '../../../settings/domain/models/cache_mode.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/data/taken_provider.dart';
import '../widgets/calendar_quick_access_card.dart';
import '../widgets/checkin_summary_card.dart';
import '../widgets/doctor_consultation_banner.dart';
import '../widgets/foundation_optimization_levels.dart';
import '../widgets/daily_insights_panel.dart';
import '../widgets/goal_progress_panel.dart';
import '../widgets/insight_snippet_card.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/plan_card.dart';
import '../widgets/profile_recommendations_banner.dart';
import '../widgets/progress_card.dart';
import '../widgets/quick_stat_chip.dart';
import '../widgets/daily_checkin_panel.dart';
import '../widgets/section_title.dart';
import '../widgets/supplement_search_bar.dart';

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
      body: Stack(
        children: [
          CustomScrollView(
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
          // Supplement-Suche
          // ----------------------------------------------------------------
          const SliverToBoxAdapter(child: SupplementSearchBar()),

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
                // Ärztliche Rücksprache nötig — auffällig, ganz oben, bevor
                // irgendwas anderes den Blick ablenkt.
                const DoctorConsultationBanner(),

                const FoundationOptimizationLevels(),
                const SizedBox(height: AppConstants.spaceL),

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

                if (stack.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spaceM),
                  const CalendarQuickAccessCard(),
                ],

                // Profil-Empfehlungen Banner (nur bei leerem Stack)
                if (stack.isEmpty) ...[
                  const SizedBox(height: AppConstants.spaceL),
                  const ProfileRecommendationsBanner(),
                ],

                // Meine Ziele — Prominentes Panel
                const SizedBox(height: AppConstants.spaceL),
                const GoalProgressPanel(),

                const SizedBox(height: AppConstants.spaceL),

                // Problemfeld-Check-ins (immer zuerst, wenn aktive Felder vorhanden)
                // KEIN const — Panel muss neu bauen wenn Felder sich ändern
                DailyProblemCheckinPanel(),

                // Allgemeiner Tages-Check-in
                const SizedBox(height: AppConstants.spaceL),
                const SectionTitle(title: 'Allgemeiner Check-in'),
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

                // Multi-Insights (ein Eintrag pro aktivem Zielbereich)
                if (insights.hasCorrelations) ...[
                  const SizedBox(height: AppConstants.spaceL),
                  SectionTitle(
                    title: 'Dein Körper sagt',
                    action: FeatureGate(
                      featureKey: FeatureKeys.insights,
                      child: TextButton(
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
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  MultiInsightSnippets(insights: insights),
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
          const LevelUpOverlay(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting header — screen-specific, not reused elsewhere
// ---------------------------------------------------------------------------

class _GreetingHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
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
          // LifeLab logo row + Empfehlungs-Modus-Switch
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
                'LifeLab',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              const _RecommendationModeToggle(),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),
          const Align(
            alignment: Alignment.centerRight,
            child: _RecommendationSourceModeToggle(),
          ),
          const SizedBox(height: AppConstants.spaceS),
          const Align(
            alignment: Alignment.centerRight,
            child: _CacheModeToggle(),
          ),
          const SizedBox(height: AppConstants.spaceXS),
          const Align(
            alignment: Alignment.centerRight,
            child: _ResetSavedListsButton(),
          ),
          const SizedBox(height: AppConstants.spaceXS),
          const Align(
            alignment: Alignment.centerRight,
            child: _ResetProfileButton(),
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

// ---------------------------------------------------------------------------
// Empfehlungs-Modus-Switch — "Nur Datenbank (RAG)" vs. "KI" (LLM + RAG-Kontext)
// ---------------------------------------------------------------------------

class _RecommendationModeToggle extends ConsumerWidget {
  const _RecommendationModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(recommendationModeProvider);
    final notifier = ref.read(recommendationModeProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSegment(
            label: 'Datenbank',
            icon: Icons.storage_rounded,
            selected: mode == RecommendationMode.ragOnly,
            onTap: () => notifier.setMode(RecommendationMode.ragOnly),
          ),
          _ModeSegment(
            label: 'KI',
            icon: Icons.auto_awesome,
            selected: mode == RecommendationMode.llm,
            onTap: () => notifier.setMode(RecommendationMode.llm),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSourceModeToggle extends ConsumerWidget {
  const _RecommendationSourceModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(recommendationSourceModeProvider);
    final notifier = ref.read(recommendationSourceModeProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSegment(
            label: 'Vorberechnet',
            icon: Icons.bolt_rounded,
            selected: mode == RecommendationSourceMode.precomputed,
            onTap: () => notifier.setMode(RecommendationSourceMode.precomputed),
          ),
          _ModeSegment(
            label: 'Live',
            icon: Icons.sync_rounded,
            selected: mode == RecommendationSourceMode.live,
            onTap: () => notifier.setMode(RecommendationSourceMode.live),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reset-Button — löscht alle lokal gespeicherten Empfehlungslisten
// (RecommendationLocalCache), damit sie beim nächsten Öffnen neu generiert
// werden. Einmalige Aktion, kein Umschalter wie die Toggles oben.
// ---------------------------------------------------------------------------

class _ResetSavedListsButton extends StatelessWidget {
  const _ResetSavedListsButton();

  Future<void> _confirmAndReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gespeicherte Listen löschen?'),
        content: const Text(
          'Alle lokal gespeicherten Supplement-Listen (Live-Modus) werden '
          'gelöscht. Beim nächsten Öffnen wird für jedes Themenfeld neu '
          'generiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await RecommendationLocalCache.instance.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gespeicherte Listen gelöscht.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _confirmAndReset(context),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withOpacity(0.65),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.refresh_rounded, size: 14),
      label: Text(
        'Gespeicherte Listen zurücksetzen',
        style: AppTextStyles.caption.copyWith(
          color: Colors.white.withOpacity(0.65),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reset-Button — löscht das gespeicherte Profil (Alter, Geschlecht,
// Erkrankungen, Ziele, ...) und schickt zurück zum Onboarding-Start, damit
// der Nutzer die Angaben bewusst neu einstellen kann.
// ---------------------------------------------------------------------------

class _ResetProfileButton extends ConsumerWidget {
  const _ResetProfileButton();

  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profil zurücksetzen?'),
        content: const Text(
          'Alter, Geschlecht, Erkrankungen, Ziele und weitere Angaben werden '
          'gelöscht. Du durchläufst danach das Onboarding erneut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(onboardingProvider.notifier).resetProfile();
    if (context.mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => _confirmAndReset(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withOpacity(0.65),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.person_off_outlined, size: 14),
      label: Text(
        'Profil zurücksetzen',
        style: AppTextStyles.caption.copyWith(
          color: Colors.white.withOpacity(0.65),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cache-Testmodus-Switch — 6h-Backend-Cache für Live-Empfehlungen an/aus
// ---------------------------------------------------------------------------

class _CacheModeToggle extends ConsumerWidget {
  const _CacheModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(cacheModeProvider);
    final notifier = ref.read(cacheModeProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSegment(
            label: 'Ohne Cache',
            icon: Icons.block_rounded,
            selected: mode == CacheMode.noCache,
            onTap: () => notifier.setMode(CacheMode.noCache),
          ),
          _ModeSegment(
            label: 'Cache',
            icon: Icons.save_rounded,
            selected: mode == CacheMode.cached,
            onTap: () => notifier.setMode(CacheMode.cached),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? AppColors.primary : Colors.white.withOpacity(0.75),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.primary : Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
