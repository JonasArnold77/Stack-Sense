import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/supplement.dart';

/// Die Kern-Komponente der App — zeigt ein Supplement mit Evidenz-Ampel.
/// Aufklappbar für "Einfach erklärt" (on-demand via API).
/// Shopping-Button öffnet Bottomsheet mit allen Kaufoptionen.
class EvidenceCard extends StatefulWidget {
  final Supplement supplement;
  final bool isInStack;
  final VoidCallback? onAddToStack;
  final VoidCallback? onRemoveFromStack;

  const EvidenceCard({
    super.key,
    required this.supplement,
    this.isInStack = false,
    this.onAddToStack,
    this.onRemoveFromStack,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  bool _expanded = false;
  String? _explanation;
  bool _loadingExplanation = false;

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

  void _openProductSheet() {
    final links = widget.supplement.productLinks;
    if (links.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSheet(links: links),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplement = widget.supplement;
    final colors = _evidenceColors(supplement.evidenceLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: colors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: Name + Badge ---
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              AppConstants.cardPadding,
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
                          child: Text(supplement.substanceName!, style: AppTextStyles.bodySmall),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spaceS),
                _EvidenceBadge(level: supplement.evidenceLevel, colors: colors),
              ],
            ),
          ),

          // --- Begründung ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
            child: Text(
              supplement.evidenceReason,
              style: AppTextStyles.bodySmall.copyWith(color: colors.textColor, height: 1.4),
            ),
          ),

          const SizedBox(height: AppConstants.spaceM),

          // --- Einnahme-Infos ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.cardPadding),
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
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
          ),

          // --- "Einfach erklärt" aufklappbar ---
          const SizedBox(height: AppConstants.spaceS),
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
                          height: 20, width: 20,
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
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Im Stack'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.evidenceGreen,
                            side: const BorderSide(color: AppColors.evidenceGreen),
                            minimumSize: const Size(0, 44),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: widget.onAddToStack,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Zum Stack'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        ),
                ),
                if (supplement.productLinks.isNotEmpty) ...[
                  const SizedBox(width: AppConstants.spaceS),
                  IconButton.outlined(
                    onPressed: _openProductSheet,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    tooltip: 'Kaufoptionen anzeigen',
                    style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Bottomsheet mit Kaufoptionen ---

class _ProductSheet extends StatelessWidget {
  final List<ProductLink> links;

  const _ProductSheet({required this.links});

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              AppConstants.spaceM,
              AppConstants.cardPadding,
              AppConstants.spaceS,
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: AppConstants.spaceS),
                Text('Kaufoptionen', style: AppTextStyles.headlineSmall),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceS),
            itemCount: links.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (context, index) {
              final link = links[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.cardPadding,
                  vertical: AppConstants.spaceXS,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: const Icon(Icons.storefront_outlined, size: 20, color: AppColors.primary),
                ),
                title: Text(link.label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                subtitle: link.note != null
                    ? Text(link.note!, style: AppTextStyles.caption)
                    : Text(link.shop, style: AppTextStyles.caption),
                trailing: const Icon(Icons.open_in_new, size: 16, color: AppColors.textTertiary),
                onTap: () => _launch(link.url),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppConstants.spaceM),
        ],
      ),
    );
  }
}

// --- Sub-Widgets ---

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

// --- Farb-Mapping ---

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
