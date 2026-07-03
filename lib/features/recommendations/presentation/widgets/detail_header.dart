import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/supplement.dart';

// ---------------------------------------------------------------------------
// Farb-Mapping (identisch zu EvidenceCard — public für detail_screen Zugriff)
// ---------------------------------------------------------------------------

class EvidenceColors {
  final Color background;
  final Color border;
  final Color badge;
  final Color textColor;

  const EvidenceColors({
    required this.background,
    required this.border,
    required this.badge,
    required this.textColor,
  });
}

EvidenceColors evidenceColors(EvidenceLevel level) => switch (level) {
      EvidenceLevel.green => const EvidenceColors(
          background: AppColors.evidenceGreenLight,
          border: AppColors.evidenceGreen,
          badge: AppColors.evidenceGreenBadge,
          textColor: AppColors.evidenceGreen,
        ),
      EvidenceLevel.yellow => const EvidenceColors(
          background: AppColors.evidenceYellowLight,
          border: AppColors.evidenceYellow,
          badge: AppColors.evidenceYellowBadge,
          textColor: AppColors.evidenceYellow,
        ),
      EvidenceLevel.red => const EvidenceColors(
          background: AppColors.evidenceRedLight,
          border: AppColors.evidenceRed,
          badge: AppColors.evidenceRedBadge,
          textColor: AppColors.evidenceRed,
        ),
    };

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class DetailHeader extends StatelessWidget {
  final Supplement supplement;
  final EvidenceColors colors;
  final VoidCallback onBack;

  const DetailHeader({
    super.key,
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
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spaceS,
                top: AppConstants.spaceS,
                right: AppConstants.screenPaddingH,
              ),
              child: Row(
                children: [
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
