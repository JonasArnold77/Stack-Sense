import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../phase_goals/data/phase_goals_provider.dart';

// ---------------------------------------------------------------------------
// Farb-Konstanten
// ---------------------------------------------------------------------------

const _kGradientStart = Color(0xFF0D2580);
const _kGradientEnd   = Color(0xFF1967D2);
const _kChipBg        = Color(0xFFE8F0FE);
const _kChipText      = Color(0xFF1A56CC);
const _kArrow         = Color(0xFF1967D2);

// ---------------------------------------------------------------------------
// Goal-Chip
// ---------------------------------------------------------------------------

class GoalChip extends StatelessWidget {
  final String label;
  final Color? bg;
  final Color? fg;

  const GoalChip({super.key, required this.label, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg ?? AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PhaseGoalsCard
// ---------------------------------------------------------------------------

class PhaseGoalsCard extends ConsumerWidget {
  final VoidCallback onTap;

  const PhaseGoalsCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGoals = ref.watch(phaseGoalsProvider);
    final hasActive = activeGoals.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: const Color(0xFFBBD6F7)),
          boxShadow: [
            BoxShadow(
              color: _kGradientEnd.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(hasActive),
            _buildFooter(hasActive, activeGoals),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasActive) {
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
                    hasActive ? '🎯 Aktiv' : '🎯 Ziele',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Phasenziele',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasActive
                      ? 'Du verfolgst gerade ein Ziel'
                      : 'Zeitlich gebundene Ziele mit\npassenden Supplement-Empfehlungen',
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
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 34),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool hasActive, List activeGoals) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasActive ? 'Aktives Ziel:' : 'Beliebte Ziele:',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kChipBg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    activeGoals.first.definition?.name ?? '',
                    style: AppTextStyles.caption.copyWith(
                      color: _kChipText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                const GoalChip(label: '🏃 Marathon',     bg: _kChipBg, fg: _kChipText),
                const SizedBox(width: 8),
                const GoalChip(label: '🤧 Erkältung',    bg: _kChipBg, fg: _kChipText),
                const SizedBox(width: 8),
                const GoalChip(label: '📚 Prüfungsphase', bg: _kChipBg, fg: _kChipText),
              ],
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded, color: _kArrow, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
