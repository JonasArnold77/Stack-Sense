import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';
import '../../../stack/data/stack_provider.dart';
import '../widgets/detail_header.dart';
import '../widgets/expandable_section.dart';
import '../widgets/interaction_card.dart';
import '../widgets/section_card.dart';
import '../widgets/sticky_stack_button.dart';
import '../widgets/supplement_detail_widgets.dart';

/// Öffnet den Supplement-Detail-Screen mit slide-from-bottom Transition.
/// [goalContext] – der Problemfeld-/Phasenziel-/Basissupplementierung-Kontext,
/// aus dem heraus geöffnet wurde (z.B. "Immunsystem") — ermöglicht den
/// "Auch hier zuordnen"-Button, wenn das Supplement bereits über einen
/// ANDEREN Kontext im Stack ist (siehe StickyStackButton).
void showSupplementDetail(BuildContext context, Supplement supplement, {String? goalContext}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SupplementDetailScreen(supplement: supplement, goalContext: goalContext),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        final fade = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: const Interval(0.0, 0.4)));

        return SlideTransition(
          position: animation.drive(slide),
          child: FadeTransition(
            opacity: animation.drive(fade),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

/// Vollständige Detailansicht eines Supplements.
class SupplementDetailScreen extends ConsumerStatefulWidget {
  final Supplement supplement;
  /// Siehe showSupplementDetail().
  final String? goalContext;

  const SupplementDetailScreen({super.key, required this.supplement, this.goalContext});

  @override
  ConsumerState<SupplementDetailScreen> createState() =>
      _SupplementDetailScreenState();
}

class _SupplementDetailScreenState
    extends ConsumerState<SupplementDetailScreen> {
  String? _explanation;
  bool _loadingExplanation = true;
  List<PubMedStudy>? _studies;
  bool _loadingStudies = false;
  List<FoodSource>? _foodSources;
  bool _loadingFoodSources = false;
  List<ProductLink>? _productLinks;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    try {
      final text = await ApiService.instance.explainSupplement(
        supplementName: widget.supplement.name,
        substanceName: widget.supplement.substanceName,
      );
      if (mounted) setState(() => _explanation = text);
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() => _explanation = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _explanation = 'Erklärung konnte nicht geladen werden.');
      }
    } finally {
      if (mounted) setState(() => _loadingExplanation = false);
    }
  }

  Future<void> _loadStudies() async {
    if (_studies != null || _loadingStudies) return;
    setState(() => _loadingStudies = true);
    try {
      final results = await ApiService.instance.getStudies(
        supplementName: widget.supplement.name,
        substanceName: widget.supplement.substanceName,
      );
      if (mounted) setState(() => _studies = results);
    } on AppFailure catch (_) {
      if (mounted) setState(() => _studies = []);
    } finally {
      if (mounted) setState(() => _loadingStudies = false);
    }
  }

  Future<void> _loadFoodSources() async {
    if (_foodSources != null || _loadingFoodSources) return;
    setState(() => _loadingFoodSources = true);
    try {
      final sources = await ApiService.instance.getFoodSources(
        supplementName: widget.supplement.name,
        substanceName: widget.supplement.substanceName,
      );
      if (mounted) setState(() => _foodSources = sources);
    } on AppFailure catch (_) {
      if (mounted) setState(() => _foodSources = []);
    } finally {
      if (mounted) setState(() => _loadingFoodSources = false);
    }
  }

  Future<void> _loadProducts() async {
    if (_productLinks != null || _loadingProducts) return;
    setState(() => _loadingProducts = true);
    try {
      final links = await ApiService.instance.getProductSuggestions(
        supplementName: widget.supplement.name,
        substanceName: widget.supplement.substanceName,
        categories: widget.supplement.categories,
      );
      if (mounted) setState(() => _productLinks = links);
    } on AppFailure catch (_) {
      if (mounted) setState(() => _productLinks = []);
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.supplement;
    final stack = ref.watch(stackProvider);
    final isInStack = stack.any((e) => e.id == s.id);
    final colors = evidenceColors(s.evidenceLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: DetailHeader(
                  supplement: s,
                  colors: colors,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.screenPaddingH,
                  AppConstants.spaceL,
                  AppConstants.screenPaddingH,
                  96,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Evidenz ──
                    SectionCard(
                      icon: Icons.science_outlined,
                      iconColor: colors.badge,
                      title: 'Evidenz',
                      child: Text(
                        s.evidenceReason,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textColor,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppConstants.spaceM),

                    // ── Einfach erklärt (auto-geladen) ──
                    SectionCard(
                      icon: Icons.lightbulb_outline,
                      iconColor: AppColors.accent,
                      title: 'Einfach erklärt',
                      child: _loadingExplanation
                          ? const DetailLoadingIndicator()
                          : Text(
                              _explanation ?? '',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(height: 1.5),
                            ),
                    ),

                    const SizedBox(height: AppConstants.spaceM),

                    // ── Studien (lazy) ──
                    ExpandableSection(
                      icon: Icons.biotech_outlined,
                      iconColor: const Color(0xFF5C6BC0),
                      title: 'Studien',
                      onExpand: _loadStudies,
                      child: _loadingStudies
                          ? const DetailLoadingIndicator()
                          : (_studies == null || _studies!.isEmpty)
                              ? Text(
                                  'Keine Studien gefunden.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : Column(
                                  children: _studies!
                                      .map((study) => StudyRow(
                                            study: study,
                                            onTap: () => _launch(study.url),
                                          ))
                                      .toList(),
                                ),
                    ),

                    const SizedBox(height: AppConstants.spaceM),

                    // ── Einnahme ──
                    SectionCard(
                      icon: Icons.schedule_outlined,
                      iconColor: AppColors.primary,
                      title: 'Einnahme',
                      child: Column(
                        children: [
                          DetailRow(
                            icon: Icons.scale_outlined,
                            label: 'Dosierung',
                            value: s.dosage,
                          ),
                          const SizedBox(height: AppConstants.spaceS),
                          DetailRow(
                            icon: Icons.access_time_outlined,
                            label: 'Zeitpunkt',
                            value: s.intakeTime,
                          ),
                          if (s.intakeHint != null) ...[
                            const SizedBox(height: AppConstants.spaceS),
                            DetailRow(
                              icon: Icons.info_outline,
                              label: 'Hinweis',
                              value: s.intakeHint!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Wechselwirkungen ──
                    if (s.drugInteraction != null) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      InteractionCard(supplement: s),
                    ],

                    // ── Enthaltene Wirkstoffe (Kombipräparate) ──
                    if (s.supplementType == SupplementType.group &&
                        s.enthalteneWirkstoffe.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      SectionCard(
                        icon: Icons.category_outlined,
                        iconColor: AppColors.primary,
                        title: 'Enthaltene Wirkstoffe',
                        child: Wrap(
                          spacing: AppConstants.spaceS,
                          runSpacing: AppConstants.spaceS,
                          children: s.enthalteneWirkstoffe
                              .map((w) => SupplementChip(label: w))
                              .toList(),
                        ),
                      ),
                    ],

                    // ── Kategorien ──
                    if (s.categories.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      SectionCard(
                        icon: Icons.label_outline,
                        iconColor: AppColors.textSecondary,
                        title: 'Kategorien',
                        child: Wrap(
                          spacing: AppConstants.spaceS,
                          runSpacing: AppConstants.spaceS,
                          children: s.categories
                              .map((c) => SupplementChip(label: c))
                              .toList(),
                        ),
                      ),
                    ],

                    // ── In Lebensmitteln (lazy) ──
                    const SizedBox(height: AppConstants.spaceM),
                    ExpandableSection(
                      icon: Icons.eco_outlined,
                      iconColor: const Color(0xFF388E3C),
                      title: 'In Lebensmitteln',
                      onExpand: _loadFoodSources,
                      child: _loadingFoodSources
                          ? const DetailLoadingIndicator()
                          : (_foodSources == null || _foodSources!.isEmpty)
                              ? Text(
                                  'Keine Daten verfügbar.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : Column(
                                  children: _foodSources!
                                      .map((f) => FoodRow(source: f))
                                      .toList(),
                                ),
                    ),

                    // ── Kaufoptionen (lazy) ──
                    const SizedBox(height: AppConstants.spaceM),
                    ExpandableSection(
                      icon: Icons.shopping_bag_outlined,
                      iconColor: AppColors.accent,
                      title: 'Kaufoptionen',
                      onExpand: _loadProducts,
                      child: _loadingProducts
                          ? const DetailLoadingIndicator()
                          : (_productLinks == null || _productLinks!.isEmpty)
                              ? Text(
                                  'Keine Produkte gefunden.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : Column(
                                  children: _productLinks!
                                      .map((p) => ProductRow(
                                            link: p,
                                            onTap: () => _launch(p.url),
                                          ))
                                      .toList(),
                                ),
                    ),
                  ]),
                ),
              ),
            ],
          ),

          // ── Sticky-Bottom-Button ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StickyStackButton(
              supplement: s,
              isInStack: isInStack,
              goalContext: widget.goalContext,
            ),
          ),
        ],
      ),
    );
  }
}
