import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';
import '../screens/supplement_detail_screen.dart';
import '../../../community/domain/models/community_insight.dart';

/// Die Kern-Komponente der App — zeigt ein Supplement mit Evidenz-Ampel.
/// Tap → öffnet SupplementDetailScreen mit slide-from-bottom Transition.
/// Aufklappbar für "Einfach erklärt" (on-demand via API).
/// Shopping-Button öffnet Bottomsheet mit allen Kaufoptionen.
class EvidenceCard extends StatefulWidget {
  final Supplement supplement;
  final bool isInStack;
  final VoidCallback? onAddToStack;
  final VoidCallback? onRemoveFromStack;
  /// 1 = Gold, 2 = Silber, 3 = Bronze. null = kein Ranking-Badge.
  final int? rank;
  /// Optionaler Community-Insight — wird als Banner am Ende der Card angezeigt.
  final CommunityInsight? communityInsight;

  const EvidenceCard({
    super.key,
    required this.supplement,
    this.isInStack = false,
    this.onAddToStack,
    this.onRemoveFromStack,
    this.rank,
    this.communityInsight,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  String? _explanation;
  bool _loadingExplanation = false;

  bool _foodExpanded = false;
  List<FoodSource>? _foodSources; // null = noch nicht geladen
  bool _loadingFoodSources = false;

  // Produkt-Cache: null = noch nicht geladen, [] = geladen aber leer
  List<ProductLink>? _cachedLinks;

  // "Zum Stack" Bounce-Animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleAddToStack() {
    _bounceController.forward(from: 0.0);
    widget.onAddToStack?.call();
  }

  Future<void> _toggleExplanation() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);

    // Erklärung nur einmal laden — danach gecacht im State
    if (_explanation == null && !_loadingExplanation) {
      setState(() => _loadingExplanation = true);
      try {
        final text = await ApiService.instance.explainSupplement(
          supplementName: widget.supplement.name,
          substanceName: widget.supplement.substanceName,
        );
        if (mounted) setState(() => _explanation = text);
      } catch (_) {
        if (mounted) {
          setState(() => _explanation = 'Erklärung konnte nicht geladen werden.');
        }
      } finally {
        if (mounted) setState(() => _loadingExplanation = false);
      }
    }
  }

  Future<void> _toggleFoodSources() async {
    if (_foodExpanded) {
      setState(() => _foodExpanded = false);
      return;
    }
    setState(() => _foodExpanded = true);

    if (_foodSources == null && !_loadingFoodSources) {
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
  }

  void _openProductSheet() {
    // Vorgeladene Links aus dem Modell als Startwert nutzen
    final preloaded = widget.supplement.productLinks;
    final initialLinks = _cachedLinks ?? (preloaded.isNotEmpty ? preloaded : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(
        supplement: widget.supplement,
        initialLinks: initialLinks,
        onLinksLoaded: (links) {
          // Im State cachen damit Sheet beim nächsten Öffnen sofort zeigt
          if (mounted) setState(() => _cachedLinks = links);
        },
      ),
    );
  }

  // Hilfsmethode: Einnahme-Infos Block
  Widget _buildIntakeInfo(Supplement supplement) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.scale_outlined, label: 'Dosierung', value: supplement.dosage),
          const SizedBox(height: AppConstants.spaceS),
          _InfoRow(icon: Icons.access_time_outlined, label: 'Einnahme', value: supplement.intakeTime),
          if (supplement.intakeHint != null) ...[
            const SizedBox(height: AppConstants.spaceS),
            _InfoRow(icon: Icons.info_outline, label: 'Hinweis', value: supplement.intakeHint!),
          ],
          if (supplement.drugInteraction != null) ...[
            const SizedBox(height: AppConstants.spaceS),
            _InfoRow(
              icon: Icons.warning_amber_outlined,
              label: 'Wechselwirkung',
              value: supplement.drugInteraction!,
              valueColor: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }

  // Hilfsmethode: "Einfach erklärt" Sektion
  Widget _buildExplanationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleExplanation,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.cardPadding,
              vertical: AppConstants.spaceS,
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: AppConstants.spaceS),
                Text(
                  'Einfach erklärt',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AppConstants.animFast,
                  child: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding, 0, AppConstants.cardPadding, AppConstants.spaceS,
            ),
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: _loadingExplanation
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.spaceS),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🧒', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: AppConstants.spaceS),
                      Expanded(
                        child: Text(
                          _explanation ?? '',
                          style: AppTextStyles.bodySmall.copyWith(height: 1.5, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: AppConstants.animNormal,
        ),
      ],
    );
  }

  // Hilfsmethode: "In Lebensmitteln" Sektion
  Widget _buildFoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleFoodSources,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.cardPadding,
              vertical: AppConstants.spaceS,
            ),
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, size: 16, color: Color(0xFF388E3C)),
                const SizedBox(width: AppConstants.spaceS),
                Text(
                  'In Lebensmitteln',
                  style: AppTextStyles.labelMedium.copyWith(color: const Color(0xFF388E3C)),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _foodExpanded ? 0.5 : 0,
                  duration: AppConstants.animFast,
                  child: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF388E3C)),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding, 0, AppConstants.cardPadding, AppConstants.spaceS,
            ),
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: _loadingFoodSources
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.spaceS),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF388E3C)),
                      ),
                    ),
                  )
                : (_foodSources == null || _foodSources!.isEmpty)
                    ? Text(
                        'Keine Daten verfügbar.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _foodSources!.map((src) => _FoodSourceRow(source: src)).toList(),
                      ),
          ),
          crossFadeState: _foodExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: AppConstants.animNormal,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplement = widget.supplement;
    final colors = _evidenceColors(supplement.evidenceLevel);
    final rankStyle = widget.rank != null ? _rankStyle(widget.rank!) : null;

    final cardBoxShadow = rankStyle != null
        ? <BoxShadow>[
            BoxShadow(
              color: rankStyle.borderColor.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            ...AppColors.cardShadow,
          ]
        : AppColors.cardShadow;

    return GestureDetector(
      onTap: () => showSupplementDetail(context, supplement),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(
            color: rankStyle?.borderColor ?? colors.border,
            width: rankStyle != null ? 2 : 1.5,
          ),
          boxShadow: cardBoxShadow,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // --- Farbiger Akzent-Streifen oben (nur bei normalen Karten, nicht Top-3) ---
            if (rankStyle == null)
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: colors.accentStripe,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.radiusL - 1),
                    topRight: Radius.circular(AppConstants.radiusL - 1),
                  ),
                ),
              ),

            // --- Ranking-Streifen (nur Top 3) ---
            if (rankStyle != null)
              _RankStrip(rank: widget.rank!, style: rankStyle),

            // --- Header: Name + Badge ---
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.cardPadding,
                rankStyle != null ? AppConstants.spaceS : AppConstants.cardPadding,
                AppConstants.cardPadding,
                AppConstants.spaceS,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + Badge in einer Zeile
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(supplement.name, style: AppTextStyles.headlineSmall),
                            ),
                            const SizedBox(width: AppConstants.spaceS),
                            Hero(
                              tag: 'evidence_badge_${supplement.id}',
                              child: _EvidenceBadge(level: supplement.evidenceLevel, colors: colors),
                            ),
                          ],
                        ),
                        if (supplement.substanceName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppConstants.spaceXS),
                            child: Text(
                              supplement.substanceName!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Ring wird als Positioned über die Karte gelegt
                ],
              ),
            ),

            // --- Relevanz-Balken ---
            _RelevanceBar(score: supplement.relevanceScore),

            // --- Kategorie-Tags ---
            if (supplement.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.cardPadding, 0, AppConstants.cardPadding, AppConstants.spaceS,
                ),
                child: Wrap(
                  spacing: AppConstants.spaceXS,
                  runSpacing: AppConstants.spaceXS,
                  children: supplement.categories
                      .map((cat) => _CategoryTag(
                            label: cat,
                            evidenceLevel: supplement.evidenceLevel,
                            reason: supplement.evidenceReason,
                          ))
                      .toList(),
                ),
              ),

            // --- Begründung ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.spaceM),
                decoration: BoxDecoration(
                  color: colors.reasonBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: Text(
                  supplement.evidenceReason,
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textColor, height: 1.4),
                ),
              ),
            ),

            // --- Sekundärer Nutzen ---
            if (supplement.secondaryBenefit != null) ...[
              const SizedBox(height: AppConstants.spaceS),
              _SecondaryBenefitBlock(benefit: supplement.secondaryBenefit!),
            ],

            const SizedBox(height: AppConstants.spaceM),

            // --- Einnahme-Infos ---
            _buildIntakeInfo(supplement),

            // --- Aufklappbare Sektionen ---
            const SizedBox(height: AppConstants.spaceS),
            _buildExplanationSection(),
            _buildFoodSection(),

            const SizedBox(height: AppConstants.spaceS),

            // --- Ernährungs-Score ---
            _FoodCoverageBar(score: supplement.foodCoverageScore),

            const SizedBox(height: AppConstants.spaceXS),

            // --- Community Insight Banner ---
            if (widget.communityInsight != null)
              _CommunityInsightBanner(insight: widget.communityInsight!),

            // --- Actions ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.cardPadding, 0, AppConstants.cardPadding, AppConstants.cardPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: widget.isInStack
                        ? OutlinedButton.icon(
                            onPressed: widget.onRemoveFromStack,
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Im Stack'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.evidenceGreen,
                              side: const BorderSide(color: AppColors.evidenceGreen),
                              minimumSize: const Size(0, 44),
                              backgroundColor: AppColors.evidenceGreenLight,
                            ),
                          )
                        : ScaleTransition(
                            scale: _bounceAnim,
                            child: FilledButton.icon(
                              onPressed: _handleAddToStack,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Zum Stack'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppConstants.spaceS),
                  IconButton.outlined(
                    onPressed: _openProductSheet,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    tooltip: 'Kaufoptionen laden',
                    style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                  ),
                ],
              ),
            ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

// --- Ranking-Farben und Dekorations-Daten ---

class _RankStyleData {
  final Color borderColor;
  final List<Color> gradientColors;
  final String emoji;
  final String label;
  final List<String> sparkles;

  const _RankStyleData({
    required this.borderColor,
    required this.gradientColors,
    required this.emoji,
    required this.label,
    required this.sparkles,
  });
}

_RankStyleData _rankStyle(int rank) {
  switch (rank) {
    case 1:
      return const _RankStyleData(
        borderColor: Color(0xFFFFB300),
        gradientColors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
        emoji: '🥇',
        label: 'Beste Wahl',
        sparkles: ['✦', '✦', '✦'],
      );
    case 2:
      return const _RankStyleData(
        borderColor: Color(0xFF90A4AE),
        gradientColors: [Color(0xFFB0BEC5), Color(0xFF607D8B)],
        emoji: '🥈',
        label: '2. Wahl',
        sparkles: ['✦', '✦'],
      );
    case 3:
      return const _RankStyleData(
        borderColor: Color(0xFFBF8C50),
        gradientColors: [Color(0xFFCD9B60), Color(0xFF8D5524)],
        emoji: '🥉',
        label: '3. Wahl',
        sparkles: ['✦'],
      );
    default:
      return const _RankStyleData(
        borderColor: Colors.transparent,
        gradientColors: [Colors.transparent, Colors.transparent],
        emoji: '',
        label: '',
        sparkles: [],
      );
  }
}

// --- Dekorativer Ranking-Streifen oben in der Karte ---

class _RankStrip extends StatelessWidget {
  final int rank;
  final _RankStyleData style;

  const _RankStrip({required this.rank, required this.style});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppConstants.radiusL - 2),
        topRight: Radius.circular(AppConstants.radiusL - 2),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: style.gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Text(style.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              style.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            // Sternchen-Verzierungen
            for (final s in style.sparkles)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  s,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Bottomsheet mit lazy-geladenen Kaufoptionen ---

class _ProductSheet extends StatefulWidget {
  final Supplement supplement;
  final List<ProductLink>? initialLinks; // null = noch nicht geladen
  final ValueChanged<List<ProductLink>> onLinksLoaded;

  const _ProductSheet({
    required this.supplement,
    required this.initialLinks,
    required this.onLinksLoaded,
  });

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  List<ProductLink>? _links;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialLinks != null) {
      _links = widget.initialLinks;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final links = await ApiService.instance.getProductSuggestions(
        supplementName: widget.supplement.name,
        substanceName: widget.supplement.substanceName,
        categories: widget.supplement.categories,
      );
      if (mounted) {
        setState(() { _links = links; _loading = false; });
        widget.onLinksLoaded(links);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Produkte konnten nicht geladen werden.';
          _loading = false;
        });
      }
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spaceM),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              AppConstants.spaceM,
              AppConstants.cardPadding,
              AppConstants.spaceS,
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: AppConstants.spaceS),
                Expanded(
                  child: Text(
                    widget.supplement.name,
                    style: AppTextStyles.headlineSmall,
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Inhalt
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: Column(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    'KI sucht passende Produkte…',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 32),
                  const SizedBox(height: AppConstants.spaceS),
                  Text(_error!, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppConstants.spaceM),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            )
          else if (_links == null || _links!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: Text(
                'Keine Produkte gefunden.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spaceS),
              itemCount: _links!.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final link = _links![index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.cardPadding,
                    vertical: AppConstants.spaceXS,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: const Icon(Icons.storefront_outlined,
                        size: 20, color: AppColors.primary),
                  ),
                  title: Text(
                    link.label,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: link.note != null
                      ? Text(link.note!, style: AppTextStyles.caption)
                      : Text(link.shop, style: AppTextStyles.caption),
                  trailing: const Icon(Icons.open_in_new,
                      size: 16, color: AppColors.textTertiary),
                  onTap: () => _launch(link.url),
                );
              },
            ),

          SizedBox(
            height:
                MediaQuery.of(context).padding.bottom + AppConstants.spaceM,
          ),
        ],
      ),
    );
  }
}

// --- Sub-Widgets ---

class _FoodSourceRow extends StatelessWidget {
  final FoodSource source;
  const _FoodSourceRow({required this.source});

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
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
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

class _EvidenceBadge extends StatelessWidget {
  final EvidenceLevel level;
  final _EvidenceColors colors;

  const _EvidenceBadge({required this.level, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.badge,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Text(
        _label(level),
        style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
      ),
    );
  }

  String _label(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppConstants.evidenceGreenLabel,
        EvidenceLevel.yellow => AppConstants.evidenceYellowLabel,
        EvidenceLevel.red => AppConstants.evidenceRedLabel,
      };
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: AppConstants.spaceS),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$label: ', style: AppTextStyles.caption),
                TextSpan(
                  text: value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
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

// --- Sekundärer Nutzen Block ---

class _SecondaryBenefitBlock extends StatelessWidget {
  final SecondaryBenefit benefit;
  const _SecondaryBenefitBlock({required this.benefit});

  @override
  Widget build(BuildContext context) {
    // Dezente teal/indigo Farbe — klar von der Evidenz-Ampelfarbe der Card getrennt
    const bgColor = Color(0xFFE8EAF6);       // indigo-50
    const borderColor = Color(0xFF9FA8DA);   // indigo-300
    const accentColor = Color(0xFF3949AB);   // indigo-700

    final badgeColor = switch (benefit.evidenceLevel) {
      EvidenceLevel.green  => AppColors.evidenceGreenBadge,
      EvidenceLevel.yellow => AppColors.evidenceYellowBadge,
      EvidenceLevel.red    => AppColors.evidenceRedBadge,
    };
    final badgeLabel = switch (benefit.evidenceLevel) {
      EvidenceLevel.green  => AppConstants.evidenceGreenLabel,
      EvidenceLevel.yellow => AppConstants.evidenceYellowLabel,
      EvidenceLevel.red    => AppConstants.evidenceRedLabel,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Überschrift — immer volle Breite, nie gequetscht
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                'Auch relevant für dich',
                style: AppTextStyles.labelSmall.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Chips in eigener Zeile unter der Überschrift
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                ),
                child: Text(
                  benefit.condition,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: accentColor,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                ),
                child: Text(
                  badgeLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Text
          Text(
            benefit.text,
            style: AppTextStyles.bodySmall.copyWith(
              color: accentColor.withOpacity(0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Kategorie-Tag mit Sprechblasen-Tooltip ---

/// Kurze Erklärungen pro Kategorie-Schlüsselwort (lowercase-Matching).
const _kCategoryExplanations = <String, String>{
  'schlaf': 'Fördert das Einschlafen und die Schlafqualität durch Einfluss auf Melatonin und das Nervensystem.',
  'entspannung': 'Unterstützt das parasympathische Nervensystem und hilft, körperliche Anspannung zu lösen.',
  'regeneration': 'Hilft dem Körper, sich nach körperlicher Belastung schneller zu erholen.',
  'sport': 'Unterstützt Muskelaufbau, Ausdauer oder die Erholung bei regelmäßigem Training.',
  'energie': 'Beteiligt an der zellulären Energieproduktion (ATP) in den Mitochondrien.',
  'fokus': 'Kann kognitive Leistung, Konzentration und mentale Klarheit verbessern.',
  'konzentration': 'Unterstützt die Aufmerksamkeit und kognitive Ausdauer über längere Zeiträume.',
  'immunsystem': 'Stärkt die körpereigene Abwehr und kann die Häufigkeit von Infekten senken.',
  'abwehr': 'Aktiviert Immunzellen und unterstützt die erste Abwehrlinie des Körpers.',
  'verdauung': 'Verbessert die Darmflora und fördert eine gesunde Verdauungsfunktion.',
  'darm': 'Unterstützt die Balance der Darmbakterien und die Darmschleimhaut.',
  'gelenke': 'Schützt Gelenkknorpel und kann Entzündungsprozesse im Bewegungsapparat dämpfen.',
  'knochen': 'Wichtig für die Mineralisation und den Erhalt der Knochendichte.',
  'stress': 'Moduliert die Stressreaktion (HPA-Achse) und kann Cortisolspiegel senken.',
  'stimmung': 'Beeinflusst Neurotransmitter wie Serotonin oder Dopamin, die die Stimmung regulieren.',
  'schilddrüse': 'Essenziell für die Produktion der Schilddrüsenhormone T3 und T4.',
  'hormon': 'Beteiligt an der Synthese oder Regulation körpereigener Hormone.',
  'antioxidantien': 'Neutralisiert freie Radikale und schützt Zellen vor oxidativem Stress.',
  'kreislauf': 'Unterstützt die Herzgesundheit und einen gesunden Blutdruck.',
  'gehirn': 'Fördert die zerebrale Durchblutung und den Neurotransmitter-Stoffwechsel.',
  'muskel': 'Unterstützt Muskelproteinsynthese und vermindert trainingsbedingten Muskelabbau.',
  'entzündung': 'Hemmt entzündliche Signalwege (z.B. NF-kB) im Körper.',
  'basis': 'Deckt grundlegende Mikronährstoffbedarfe ab, die über die Ernährung oft nicht erreicht werden.',
  'vitamin': 'Wichtiger Mikronährstoff der an zahlreichen Stoffwechselprozessen beteiligt ist.',
  'mineral': 'Essenzieller Mineralstoff der als Cofaktor in vielen enzymatischen Reaktionen wirkt.',
};

String _bubbleText(String label) {
  final key = _kCategoryExplanations.keys.firstWhere(
    (k) => label.toLowerCase().contains(k),
    orElse: () => '',
  );
  if (key.isEmpty) {
    return 'Dieses Supplement kann bei "$label" unterstützen — '
        'basierend auf der aktuellen Studienlage.';
  }
  return _kCategoryExplanations[key]!;
}

class _CategoryTag extends StatefulWidget {
  final String label;
  final EvidenceLevel evidenceLevel;
  final String reason;

  const _CategoryTag({
    required this.label,
    required this.evidenceLevel,
    required this.reason,
  });

  @override
  State<_CategoryTag> createState() => _CategoryTagState();
}

class _CategoryTagState extends State<_CategoryTag>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  // LayerLink verknüpft Tag und Bubble — Bubble folgt dem Tag beim Scrollen
  final _layerLink = LayerLink();
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    _hideBubble();
    super.dispose();
  }

  void _showBubble() {
    _overlay = OverlayEntry(
      builder: (ctx) => _TagBubbleOverlay(
        layerLink: _layerLink,
        label: widget.label,
        explanation: _bubbleText(widget.label),
        evidenceLevel: widget.evidenceLevel,
        scaleAnim: _scaleAnim,
        fadeAnim: _fadeAnim,
        onDismiss: _hideBubble,
      ),
    );
    Overlay.of(context).insert(_overlay!);
    _animController.forward(from: 0);
  }

  void _hideBubble() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _overlay == null ? _showBubble : _hideBubble,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          border: Border.all(color: AppColors.primary.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.info_outline, size: 9, color: AppColors.primary.withAlpha(140)),
          ],
        ),
      ),
    ),   // GestureDetector
  );     // CompositedTransformTarget
  }
}

class _TagBubbleOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final String label;
  final String explanation;
  final EvidenceLevel evidenceLevel;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onDismiss;

  const _TagBubbleOverlay({
    required this.layerLink,
    required this.label,
    required this.explanation,
    required this.evidenceLevel,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.onDismiss,
  });

  Color get _evidenceColor => switch (evidenceLevel) {
        EvidenceLevel.green => AppColors.evidenceGreen,
        EvidenceLevel.yellow => AppColors.evidenceYellow,
        EvidenceLevel.red => AppColors.evidenceRed,
      };

  String get _evidenceLabel => switch (evidenceLevel) {
        EvidenceLevel.green => 'Evidenzbasiert',
        EvidenceLevel.yellow => 'Hinweise vorhanden',
        EvidenceLevel.red => 'Nicht belegt',
      };

  @override
  Widget build(BuildContext context) {
    const bubbleW = 240.0;
    const pointerH = 9.0;
    const pointerW = 14.0;
    // Pfeil mittig unter der Bubble
    const pointerX = (bubbleW - pointerW) / 2;

    return Stack(
      children: [
        // Transparenter Tap-Catcher zum Schließen
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        // CompositedTransformFollower folgt dem Tag live beim Scrollen
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,       // versteckt wenn Tag außerhalb des Screens
          targetAnchor: Alignment.bottomCenter,  // Anhängepunkt: Mitte-Unten des Tags
          followerAnchor: Alignment.topCenter,   // Bubble startet oben-mittig
          offset: const Offset(0, 4),            // 4px Abstand unter dem Tag
          child: FadeTransition(
            opacity: fadeAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pfeil zeigt nach oben — zum Tag hin
                  Padding(
                    padding: const EdgeInsets.only(left: pointerX),
                    child: CustomPaint(
                      size: const Size(pointerW, pointerH),
                      painter: _BubblePointerPainter(color: AppColors.primaryDark),
                    ),
                  ),
                  Material(
                    elevation: 12,
                    shadowColor: Colors.black.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    color: Colors.transparent,
                    child: Container(
                      width: bubbleW,
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppConstants.spaceS),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _evidenceColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                                  border: Border.all(color: _evidenceColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  _evidenceLabel,
                                  style: AppTextStyles.caption.copyWith(
                                    color: _evidenceColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spaceS),
                          Text(
                            explanation,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.82),
                              height: 1.45,
                              fontSize: 11,
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
        ),
      ],
    );
  }
}

class _BubblePointerPainter extends CustomPainter {
  final Color color;
  const _BubblePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Aufwärts-Pfeil: Spitze oben, breite Basis unten
    final path = Path()
      ..moveTo(size.width / 2, 0)       // Spitze oben (zeigt zum Tag)
      ..lineTo(size.width, size.height)  // unten rechts
      ..lineTo(0, size.height)           // unten links
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePointerPainter old) => old.color != color;
}

// --- Farb-Mapping ---

class _EvidenceColors {
  final Color background;
  final Color border;
  final Color badge;
  final Color textColor;
  final Color accentStripe;
  final Color reasonBg;

  const _EvidenceColors({
    required this.background,
    required this.border,
    required this.badge,
    required this.textColor,
    required this.accentStripe,
    required this.reasonBg,
  });
}

_EvidenceColors _evidenceColors(EvidenceLevel level) {
  return switch (level) {
    EvidenceLevel.green => const _EvidenceColors(
          background: AppColors.evidenceGreenLight,
          border: AppColors.evidenceGreen,
          badge: AppColors.evidenceGreenBadge,
          textColor: AppColors.evidenceGreen,
          accentStripe: AppColors.evidenceGreenBadge,
          reasonBg: AppColors.evidenceGreenLight,
        ),
    EvidenceLevel.yellow => const _EvidenceColors(
          background: AppColors.evidenceYellowLight,
          border: AppColors.evidenceYellow,
          badge: AppColors.evidenceYellowBadge,
          textColor: AppColors.evidenceYellow,
          accentStripe: AppColors.evidenceYellowBadge,
          reasonBg: AppColors.evidenceYellowLight,
        ),
    EvidenceLevel.red => const _EvidenceColors(
          background: AppColors.evidenceRedLight,
          border: AppColors.evidenceRed,
          badge: AppColors.evidenceRedBadge,
          textColor: AppColors.evidenceRed,
          accentStripe: AppColors.evidenceRedBadge,
          reasonBg: AppColors.evidenceRedLight,
        ),
  };
}

// ---------------------------------------------------------------------------
// Community Insight Banner
// ---------------------------------------------------------------------------

/// Zeigt aggregierte Community-Daten am unteren Ende einer EvidenceCard:
/// "👥 Bei 23 Nutzern hat sich der Schlaf durch Melatonin deutlich verbessert"
class _CommunityInsightBanner extends StatelessWidget {
  final CommunityInsight insight;
  const _CommunityInsightBanner({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.cardPadding, 0, AppConstants.cardPadding, 0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceS + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.star_outline_rounded,
              size: 15,
              color: AppColors.primary.withOpacity(0.8),
            ),
            const SizedBox(width: AppConstants.spaceS),
            Expanded(
              child: Text(
                insight.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spaceS),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              ),
              child: Text(
                '${insight.improvementPercent}%',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ─── Relevanz-Balken ──────────────────────────────────────────────────────────

class _RelevanceBar extends StatelessWidget {
  final int score; // 0–100

  const _RelevanceBar({required this.score});

  Color _color() {
    if (score >= 75) return AppColors.evidenceGreen;
    if (score >= 50) return AppColors.evidenceYellow;
    return AppColors.evidenceRed;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.cardPadding, 0, AppConstants.cardPadding, AppConstants.spaceS,
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Balken
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 34,
              backgroundColor: color.withOpacity(0.13),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // Score innerhalb des Balkens
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$score %',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: color.withOpacity(0.5), blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Ernährungs-Abdeckungs-Balken ────────────────────────────────────────────

class _FoodCoverageBar extends StatelessWidget {
  final int score; // 1–10

  const _FoodCoverageBar({required this.score});

  Color _barColor() {
    if (score <= 3) return const Color(0xFFE53935);
    if (score <= 6) return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }

  String _label() {
    if (score <= 3) return 'Kaum durch Ernährung abdeckbar';
    if (score <= 6) return 'Bedingt durch Ernährung abdeckbar';
    return 'Gut durch Ernährung abdeckbar';
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.cardPadding, 0, AppConstants.cardPadding, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco_outlined, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                'Ernährungsabdeckung',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '${score}/10',
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            child: LinearProgressIndicator(
              value: score / 10,
              minHeight: 5,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _label(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
