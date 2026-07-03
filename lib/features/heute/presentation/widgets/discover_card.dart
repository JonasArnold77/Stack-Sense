import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// Farb-Konstanten
// ---------------------------------------------------------------------------

const _kGradientStart = Color(0xFF1477D4);
const _kGradientEnd   = Color(0xFF3B97F5);
const _kArrow         = Color(0xFF1477D4);

// ---------------------------------------------------------------------------
// Evidenz-Chip
// ---------------------------------------------------------------------------

class EvidenceChip extends StatelessWidget {
  final Color color;
  final Color bg;
  final String label;

  const EvidenceChip({
    super.key,
    required this.color,
    required this.bg,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DiscoverCard
// ---------------------------------------------------------------------------

class DiscoverCard extends StatelessWidget {
  final VoidCallback onTap;

  const DiscoverCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: const Color(0xFFB5D8F7)),
          boxShadow: [
            BoxShadow(
              color: _kGradientStart.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGradientStart, _kGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radiusL),
          topRight: Radius.circular(AppConstants.radiusL),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    'KI-gestützt',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Supplements\nentdecken',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Wähle ein Ziel — Claude analysiert\ndie Studienlage für dich',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
            ),
            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 34),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bewertung nach Studienlage — sofort sichtbar:',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              EvidenceChip(
                color: Color(0xFF2E7D32),
                bg: Color(0xFFE8F5E9),
                label: '● Belegt',
              ),
              SizedBox(width: 8),
              EvidenceChip(
                color: Color(0xFFF57F17),
                bg: Color(0xFFFFF8E1),
                label: '● Hinweise',
              ),
              SizedBox(width: 8),
              EvidenceChip(
                color: Color(0xFFC62828),
                bg: Color(0xFFFFEBEE),
                label: '● Unbelegt',
              ),
              Spacer(),
              Icon(Icons.arrow_forward_rounded, color: _kArrow, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
