import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/supplement.dart';

/// Die Kern-Komponente der App — zeigt ein Supplement mit Evidenz-Ampel.
///
/// Verwendung:
/// ```dart
/// EvidenceCard(supplement: supplement, onAddToStack: () { ... })
/// ```
class EvidenceCard extends StatelessWidget {
  final Supplement supplement;
  final bool isInStack;
  final VoidCallback? onAddToStack;
  final VoidCallback? onRemoveFromStack;
  final VoidCallback? onTapProduct;

  const EvidenceCard({
    super.key,
    required this.supplement,
    this.isInStack = false,
    this.onAddToStack,
    this.onRemoveFromStack,
    this.onTapProduct,
  });

  @override
  Widget build(BuildContext context) {
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
                      Text(supplement.name,
                          style: AppTextStyles.headlineSmall),
                      if (supplement.substanceName != null)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: AppConstants.spaceXS),
                          child: Text(
                            supplement.substanceName!,
                            style: AppTextStyles.bodySmall,
                          ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.cardPadding,
            ),
            child: Text(
              supplement.evidenceReason,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textColor,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spaceM),

          // --- Einnahme-Infos ---
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.cardPadding),
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.scale_outlined,
                  label: 'Dosierung',
                  value: supplement.dosage,
                ),
                const SizedBox(height: AppConstants.spaceS),
                _InfoRow(
                  icon: Icons.access_time_outlined,
                  label: 'Einnahme',
                  value: supplement.intakeTime,
                ),
                if (supplement.intakeHint != null) ...[
                  const SizedBox(height: AppConstants.spaceS),
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'Hinweis',
                    value: supplement.intakeHint!,
                  ),
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

          const SizedBox(height: AppConstants.spaceM),

          // --- Actions ---
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.cardPadding,
              0,
              AppConstants.cardPadding,
              AppConstants.cardPadding,
            ),
            child: Row(
              children: [
                // Zum Stack hinzufügen / entfernen
                Expanded(
                  child: isInStack
                      ? OutlinedButton.icon(
                          onPressed: onRemoveFromStack,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Im Stack'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.evidenceGreen,
                            side: const BorderSide(
                                color: AppColors.evidenceGreen),
                            minimumSize: const Size(0, 44),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: onAddToStack,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Zum Stack'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                ),

                // Produkt kaufen (nur wenn URL vorhanden)
                if (supplement.productUrl != null) ...[
                  const SizedBox(width: AppConstants.spaceS),
                  IconButton.outlined(
                    onPressed: onTapProduct,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    tooltip: 'Produkt ansehen',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
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

  String _label(EvidenceLevel level) {
    return switch (level) {
      EvidenceLevel.green => AppConstants.evidenceGreenLabel,
      EvidenceLevel.yellow => AppConstants.evidenceYellowLabel,
      EvidenceLevel.red => AppConstants.evidenceRedLabel,
    };
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

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
                TextSpan(
                  text: '$label: ',
                  style: AppTextStyles.caption,
                ),
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

_EvidenceColors _evidenceColors(EvidenceLevel level) {
  return switch (level) {
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
}
