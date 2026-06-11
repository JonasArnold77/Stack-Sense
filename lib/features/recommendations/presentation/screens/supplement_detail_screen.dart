import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';

/// Öffnet den Supplement-Detail-Screen mit slide-from-bottom Transition.
/// Kein go_router nötig — wird via Navigator.push mit PageRouteBuilder aufgerufen.
void showSupplementDetail(BuildContext context, Supplement supplement) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SupplementDetailScreen(supplement: supplement),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide von unten + dezentes Fade
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
/// Wird via [showSupplementDetail] über einen slide-from-bottom Push geöffnet.
class SupplementDetailScreen extends ConsumerStatefulWidget {
  final Supplement supplement;

  const SupplementDetailScreen({super.key, required this.supplement});

  @override
  ConsumerState<SupplementDetailScreen> createState() =>
      _SupplementDetailScreenState();
}

class _SupplementDetailScreenState
    extends ConsumerState<SupplementDetailScreen> {
  // Lazy-geladene Inhalte
  String? _explanation;
  bool _loadingExplanation = true; // Sofort beim Öffnen laden
  List<FoodSource>? _foodSources;
  bool _loadingFoodSources = false;
  List<ProductLink>? _productLinks;
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    // Erklärung sofort beim Öffnen laden — kein extra Tap nötig
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    try {
      final text = await ApiService.instance.explainSupplement(
        supplementName: widget.supplement.name,
        substanceName: widget.supplement.substanceName,
      );
      if (mounted) setState(() => _explanation = text);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _explanation = 'Erklärung konnte nicht geladen werden.');
      }
    } finally {
      if (mounted) setState(() => _loadingExplanation = false);
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
    } catch (_) {
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
    } catch (_) {
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
    final colors = _evidenceColors(s.evidenceLevel);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollbarer Inhalt ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: _DetailHeader(
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
                  // Extra Platz für den sticky Button
                  96,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Evidenz ──
                    _SectionCard(
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
                    _SectionCard(
                      icon: Icons.lightbulb_outline,
                      iconColor: AppColors.accent,
                      title: 'Einfach erklärt',
                      child: _loadingExplanation
                          ? const _LoadingIndicator()
                          : Text(
                              _explanation ?? '',
                              style: AppTextStyles.bodyMedium
                                  .copyWith(height: 1.5),
                            ),
                    ),

                    const SizedBox(height: AppConstants.spaceM),

                    // ── Einnahme ──
                    _SectionCard(
                      icon: Icons.schedule_outlined,
                      iconColor: AppColors.primary,
                      title: 'Einnahme',
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.scale_outlined,
                            label: 'Dosierung',
                            value: s.dosage,
                          ),
                          const SizedBox(height: AppConstants.spaceS),
                          _DetailRow(
                            icon: Icons.access_time_outlined,
                            label: 'Zeitpunkt',
                            value: s.intakeTime,
                          ),
                          if (s.intakeHint != null) ...[
                            const SizedBox(height: AppConstants.spaceS),
                            _DetailRow(
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
                      _InteractionCard(supplement: s),
                    ],

                    // ── Enthaltene Wirkstoffe (Kombipräparate) ──
                    if (s.supplementType == SupplementType.group &&
                        s.enthalteneWirkstoffe.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      _SectionCard(
                        icon: Icons.category_outlined,
                        iconColor: AppColors.primary,
                        title: 'Enthaltene Wirkstoffe',
                        child: Wrap(
                          spacing: AppConstants.spaceS,
                          runSpacing: AppConstants.spaceS,
                          children: s.enthalteneWirkstoffe
                              .map((w) => _Chip(label: w))
                              .toList(),
                        ),
                      ),
                    ],

                    // ── Kategorien ──
                    if (s.categories.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      _SectionCard(
                        icon: Icons.label_outline,
                        iconColor: AppColors.textSecondary,
                        title: 'Kategorien',
                        child: Wrap(
                          spacing: AppConstants.spaceS,
                          runSpacing: AppConstants.spaceS,
                          children: s.categories
                              .map((c) => _Chip(label: c))
                              .toList(),
                        ),
                      ),
                    ],

                    // ── In Lebensmitteln (lazy) ──
                    const SizedBox(height: AppConstants.spaceM),
                    _ExpandableSection(
                      icon: Icons.eco_outlined,
                      iconColor: const Color(0xFF388E3C),
                      title: 'In Lebensmitteln',
                      onExpand: _loadFoodSources,
                      child: _loadingFoodSources
                          ? const _LoadingIndicator()
                          : (_foodSources == null || _foodSources!.isEmpty)
                              ? Text(
                                  'Keine Daten verfügbar.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : Column(
                                  children: _foodSources!
                                      .map((f) => _FoodRow(source: f))
                                      .toList(),
                                ),
                    ),

                    // ── Kaufoptionen (lazy) ──
                    const SizedBox(height: AppConstants.spaceM),
                    _ExpandableSection(
                      icon: Icons.shopping_bag_outlined,
                      iconColor: AppColors.accent,
                      title: 'Kaufoptionen',
                      onExpand: _loadProducts,
                      child: _loadingProducts
                          ? const _LoadingIndicator()
                          : (_productLinks == null || _productLinks!.isEmpty)
                              ? Text(
                                  'Keine Produkte gefunden.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : Column(
                                  children: _productLinks!
                                      .map((p) => _ProductRow(
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
            child: _StickyStackButton(
              supplement: s,
              isInStack: isInStack,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Header
// ═══════════════════════════════════════════

class _DetailHeader extends StatelessWidget {
  final Supplement supplement;
  final _EvidenceColors colors;
  final VoidCallback onBack;

  const _DetailHeader({
    required this.supplement,
    required this.colors,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back-Button Zeile
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spaceS,
                top: AppConstants.spaceS,
                right: AppConstants.screenPaddingH,
              ),
              child: Row(
                children: [
                  // Zurück-Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onBack,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusRound),
                      child: const Padding(
                        padding: EdgeInsets.all(AppConstants.spaceM),
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Evidence-Badge (Hero für spätere Animation-Erweiterung)
                  Hero(
                    tag: 'evidence_badge_${supplement.id}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.badge,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusRound),
                      ),
                      child: Text(
                        _badgeLabel(supplement.evidenceLevel),
                        style: AppTextStyles.labelSmall
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Name + Substanz
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.screenPaddingH,
                AppConstants.spaceS,
                AppConstants.screenPaddingH,
                AppConstants.spaceXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplement.name,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (supplement.substanceName != null) ...[
                    const SizedBox(height: AppConstants.spaceXS),
                    Text(
                      supplement.substanceName!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppConstants.spaceM),
                  // Kategorie-Chips im Header
                  if (supplement.categories.isNotEmpty)
                    Wrap(
                      spacing: AppConstants.spaceS,
                      runSpacing: AppConstants.spaceXS,
                      children: supplement.categories
                          .map((c) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusRound),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Text(
                                  c,
                                  style: AppTextStyles.caption.copyWith(
                                      color: Colors.white.withOpacity(0.85)),
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _badgeLabel(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppConstants.evidenceGreenLabel,
        EvidenceLevel.yellow => AppConstants.evidenceYellowLabel,
        EvidenceLevel.red => AppConstants.evidenceRedLabel,
      };
}

// ═══════════════════════════════════════════
// Section Card (immer sichtbar)
// ═══════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titel-Zeile
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: AppConstants.spaceS),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Expandable Section (lazy-load)
// ═══════════════════════════════════════════

class _ExpandableSection extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final VoidCallback onExpand;

  const _ExpandableSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    required this.onExpand,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.animNormal,
      vsync: this,
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
      widget.onExpand();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header (immer sichtbar, tappbar)
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceL),
              child: Row(
                children: [
                  Icon(widget.icon, size: 16, color: widget.iconColor),
                  const SizedBox(width: AppConstants.spaceS),
                  Text(
                    widget.title.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppConstants.animFast,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Inhalt (animiert ein-/ausblenden)
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                const Divider(height: 1, color: AppColors.divider),
                Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceL),
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Wechselwirkungs-Karte
// ═══════════════════════════════════════════

class _InteractionCard extends StatelessWidget {
  final Supplement supplement;

  const _InteractionCard({required this.supplement});

  @override
  Widget build(BuildContext context) {
    final severity = supplement.interactionSeverity;
    final color = switch (severity) {
      InteractionSeverity.timing => AppColors.evidenceYellow,
      InteractionSeverity.moderate => const Color(0xFFEF6C00),
      InteractionSeverity.high => AppColors.evidenceRed,
      _ => AppColors.textSecondary,
    };
    final bg = switch (severity) {
      InteractionSeverity.timing => AppColors.evidenceYellowLight,
      InteractionSeverity.moderate => const Color(0xFFFFF3E0),
      InteractionSeverity.high => AppColors.evidenceRedLight,
      _ => AppColors.surfaceVariant,
    };
    final icon = switch (severity) {
      InteractionSeverity.timing => Icons.timer_outlined,
      InteractionSeverity.moderate => Icons.warning_amber_outlined,
      InteractionSeverity.high => Icons.dangerous_outlined,
      _ => Icons.info_outline,
    };

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppConstants.spaceS),
              Text(
                'WECHSELWIRKUNGEN'.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            supplement.drugInteraction!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Sticky Stack Button
// ═══════════════════════════════════════════

class _StickyStackButton extends ConsumerWidget {
  final Supplement supplement;
  final bool isInStack;

  const _StickyStackButton({
    required this.supplement,
    required this.isInStack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH,
        AppConstants.spaceM,
        AppConstants.screenPaddingH,
        AppConstants.spaceM + bottomPadding,
      ),
      child: AnimatedSwitcher(
        duration: AppConstants.animFast,
        child: isInStack
            ? OutlinedButton.icon(
                key: const ValueKey('in_stack'),
                onPressed: () {
                  ref.read(stackProvider.notifier).remove(supplement.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${supplement.name} aus Stack entfernt'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Im Stack — tippen zum Entfernen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.evidenceGreen,
                  side: const BorderSide(color: AppColors.evidenceGreen),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
              )
            : FilledButton.icon(
                key: const ValueKey('add_stack'),
                onPressed: () {
                  ref
                      .read(stackProvider.notifier)
                      .add(supplement);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${supplement.name} zum Stack hinzugefügt'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Zum Stack hinzufügen'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Kleine Hilfs-Widgets
// ═══════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textTertiary),
        const SizedBox(width: AppConstants.spaceS),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodSource source;
  const _FoodRow({required this.source});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🥦', style: TextStyle(fontSize: 14)),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: source.food,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (source.note.isNotEmpty)
                    TextSpan(
                      text: '  ${source.note}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductLink link;
  final VoidCallback onTap;

  const _ProductRow({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spaceM),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: const Icon(Icons.storefront_outlined,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.label,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (link.note != null)
                      Text(link.note!,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary))
                    else
                      Text(link.shop,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new,
                  size: 15, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.spaceM),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Farb-Mapping (lokal, identisch zu EvidenceCard)
// ═══════════════════════════════════════════

class _EvidenceColors {
  final Color background;
  final Color border;
  final Color badge;
  final Color textColor;

  const _EvidenceColors({
    required this.background,
    required this.border,
    required this.badge,
    required this.textColor,
  });
}

_EvidenceColors _evidenceColors(EvidenceLevel level) => switch (level) {
      EvidenceLevel.green => const _EvidenceColors(
          background: AppColors.evidenceGreenLight,
          border: AppColors.evidenceGreen,
          badge: AppColors.evidenceGreenBadge,
          textColor: AppColors.evidenceGreen,
        ),
      EvidenceLevel.yellow => const _EvidenceColors(
          background: AppColors.evidenceYellowLight,
          border: AppColors.evidenceYellow,
          badge: AppColors.evidenceYellowBadge,
          textColor: AppColors.evidenceYellow,
        ),
      EvidenceLevel.red => const _EvidenceColors(
          background: AppColors.evidenceRedLight,
          border: AppColors.evidenceRed,
          badge: AppColors.evidenceRedBadge,
          textColor: AppColors.evidenceRed,
        ),
    };
