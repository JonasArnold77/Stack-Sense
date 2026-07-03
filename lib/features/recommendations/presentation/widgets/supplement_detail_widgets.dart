import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/supplement.dart';

// ---------------------------------------------------------------------------
// Einnahme-Zeile (Label + Wert mit Icon)
// ---------------------------------------------------------------------------

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailRow({
    super.key,
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

// ---------------------------------------------------------------------------
// Lebensmittelquelle-Zeile
// ---------------------------------------------------------------------------

class FoodRow extends StatelessWidget {
  final FoodSource source;
  const FoodRow({super.key, required this.source});

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

// ---------------------------------------------------------------------------
// Produkt-Kauf-Zeile
// ---------------------------------------------------------------------------

class ProductRow extends StatelessWidget {
  final ProductLink link;
  final VoidCallback onTap;

  const ProductRow({super.key, required this.link, required this.onTap});

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

// ---------------------------------------------------------------------------
// PubMed-Studie-Zeile
// ---------------------------------------------------------------------------

class StudyRow extends StatelessWidget {
  final PubMedStudy study;
  final VoidCallback onTap;

  const StudyRow({super.key, required this.study, required this.onTap});

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
            color: const Color(0xFFF3F4FF),
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
            border: Border.all(
                color: const Color(0xFF5C6BC0).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.article_outlined,
                      size: 15, color: Color(0xFF5C6BC0)),
                  const SizedBox(width: AppConstants.spaceS),
                  Expanded(
                    child: Text(
                      study.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (study.year.isNotEmpty) ...[
                    const SizedBox(width: AppConstants.spaceS),
                    Text(
                      study.year,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
              if (study.abstract.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spaceS),
                Text(
                  study.abstract.length > 200
                      ? '${study.abstract.substring(0, 200)}…'
                      : study.abstract,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: AppConstants.spaceS),
              const Row(
                children: [
                  Icon(Icons.open_in_new,
                      size: 12, color: Color(0xFF5C6BC0)),
                  SizedBox(width: 4),
                  Text(
                    'PubMed ansehen',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5C6BC0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kategorie / Wirkstoff-Chip
// ---------------------------------------------------------------------------

class SupplementChip extends StatelessWidget {
  final String label;
  const SupplementChip({super.key, required this.label});

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

// ---------------------------------------------------------------------------
// Kleiner Lade-Indikator für lazy-geladene Sektionen
// ---------------------------------------------------------------------------

class DetailLoadingIndicator extends StatelessWidget {
  const DetailLoadingIndicator({super.key});

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
