import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/supplement.dart' show SupplementSynergy, EvidenceLevel;

/// Zeigt eine Supplement-Synergie an — zwei oder mehr Wirkstoffe die sich
/// nachweislich gegenseitig verstärken.
///
/// Visuelle Unterschiede zur EvidenceCard:
/// - Lila/Indigo Akzentfarbe statt grün/gelb/rot
/// - Wirkstoffe als Chips in der Titelzeile (kein einzelner Name)
/// - Score-Balken statt einfachem Badge
/// - Erklärungs-Text immer sichtbar (nicht aufklappbar)
class SynergyCard extends StatelessWidget {
  final SupplementSynergy synergy;

  const SynergyCard({super.key, required this.synergy});

  @override
  Widget build(BuildContext context) {
    final evidenceColor = _evidenceColor(synergy.evidenceLevel);
    final evidenceLabel = _evidenceLabel(synergy.evidenceLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Synergie-Icon + Titel-Label ──
          _SynergyHeader(synergy: synergy),

          // ── Wirkstoff-Chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH, 0,
              AppConstants.screenPaddingH, AppConstants.spaceS,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (int i = 0; i < synergy.substances.length; i++) ...[
                  _SubstanceChip(label: synergy.substances[i]),
                  if (i < synergy.substances.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // ── Score + Evidenz-Badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH, AppConstants.spaceM,
              AppConstants.screenPaddingH, AppConstants.spaceS,
            ),
            child: Row(
              children: [
                // Score-Balken
                Expanded(child: _ScoreBar(score: synergy.synergyScore)),
                const SizedBox(width: AppConstants.spaceM),
                // Evidenz-Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: evidenceColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                    border: Border.all(color: evidenceColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: evidenceColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        evidenceLabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: evidenceColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Erklärungstext ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.screenPaddingH, AppConstants.spaceS,
              AppConstants.screenPaddingH, AppConstants.spaceM,
            ),
            child: Text(
              synergy.synergyExplanation,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),

          // ── Einnahmehinweis (optional) ──
          if (synergy.dosageHint != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppConstants.screenPaddingH, 0,
                AppConstants.screenPaddingH, AppConstants.spaceM,
              ),
              padding: const EdgeInsets.all(AppConstants.spaceS),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withOpacity(0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      synergy.dosageHint!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: const Color(0xFF5B21B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _evidenceColor(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => AppColors.evidenceGreen,
        EvidenceLevel.yellow => AppColors.evidenceYellow,
        EvidenceLevel.red => AppColors.evidenceRed,
      };

  String _evidenceLabel(EvidenceLevel level) => switch (level) {
        EvidenceLevel.green => 'Evidenzbasiert',
        EvidenceLevel.yellow => 'Erste Studien',
        EvidenceLevel.red => 'Kaum Evidenz',
      };
}


/// Lila Header-Leiste mit "Synergie"-Label und dem kombinierten Namen.
class _SynergyHeader extends StatelessWidget {
  final SupplementSynergy synergy;

  const _SynergyHeader({required this.synergy});

  @override
  Widget build(BuildContext context) {
    final comboName = synergy.substances.join(' + ');

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingH, AppConstants.spaceM,
        AppConstants.screenPaddingH, AppConstants.spaceS,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Synergie',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  comboName,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Einzelner Wirkstoff-Chip in lila Farbe.
class _SubstanceChip extends StatelessWidget {
  final String label;

  const _SubstanceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: const Color(0xFF5B21B6),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


/// Horizontaler Score-Balken mit Beschriftung "Passend für dein Ziel".
class _ScoreBar extends StatelessWidget {
  final int score; // 0–100

  const _ScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Passend für dein Ziel',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              '$score%',
              style: AppTextStyles.labelSmall.copyWith(
                color: const Color(0xFF7C3AED),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFF7C3AED).withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
          ),
        ),
      ],
    );
  }
}
