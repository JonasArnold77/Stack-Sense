import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';
import '../screens/supplement_detail_screen.dart';

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

  const EvidenceCard({
    super.key,
    required this.supplement,
    this.isInStack = false,
    this.onAddToStack,
    this.onRemoveFromStack,
    this.rank,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Farbiger Akzent-Streifen oben (zeigt Evidenzstufe) ---
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
                        Text(supplement.name, style: AppTextStyles.headlineSmall),
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
                  const SizedBox(width: AppConstants.spaceS),
                  Hero(
                    tag: 'evidence_badge_${supplement.id}',
                    child: _EvidenceBadge(level: supplement.evidenceLevel, colors: colors),
                  ),
                ],
              ),
            ),

            // --- Kategorie-Tags ---
            if (supplement.categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.cardPadding, 0, AppConstants.cardPadding, AppConstants.spaceS,
                ),
                child: Wrap(
                  spacing: AppConstants.spaceXS,
                  runSpacing: AppConstants.spaceXS,
                  children: supplement.categories.map((cat) => _CategoryTag(label: cat)).toList(),
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

// --- Kategorie-Tag ---

class _CategoryTag extends StatelessWidget {
  final String label;

  const _CategoryTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontSize: 10,
        ),
      ),
    );
  }
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

_EvidenceColors _evidenceColors(EvidenceLevel level) => switch (level) {
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
