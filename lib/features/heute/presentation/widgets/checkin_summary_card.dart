import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/domain/models/checkin_entry.dart';

// ---------------------------------------------------------------------------
// Metrik-Balken (Energie / Schlaf / Fokus / Stimmung)
// ---------------------------------------------------------------------------

class MetricBar extends StatelessWidget {
  final String label;
  final int value; // 1-5

  const MetricBar({super.key, required this.label, required this.value});

  Color _barColor(int v) {
    if (v >= 4) return AppColors.evidenceGreen;
    if (v >= 3) return AppColors.evidenceYellow;
    return AppColors.evidenceRed;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 5.0,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor(value)),
            ),
          ),
          const SizedBox(height: 2),
          Text('$value/5',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Check-in Card
// ---------------------------------------------------------------------------

class CheckinSummaryCard extends StatelessWidget {
  final bool hasCheckedIn;
  final CheckinEntry? todayEntry;
  final VoidCallback onTap;

  const CheckinSummaryCard({
    super.key,
    required this.hasCheckedIn,
    required this.todayEntry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCheckedIn) return _buildCallToAction();
    return _buildDoneState(todayEntry!);
  }

  Widget _buildCallToAction() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withOpacity(0.85),
              AppColors.primaryLight,
            ],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wie geht es dir heute?',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trage dein Befinden ein — dauert 30 Sekunden.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spaceM),
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneState(CheckinEntry entry) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppColors.panelTintMoss,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.evidenceGreen.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.evidenceGreen, size: 18),
              const SizedBox(width: AppConstants.spaceS),
              Text('Heute eingecheckt',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.evidenceGreen, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: onTap,
                child: Text('Bearbeiten',
                    style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            children: [
              MetricBar(label: '⚡', value: entry.energy),
              const SizedBox(width: AppConstants.spaceS),
              MetricBar(label: '😴', value: entry.sleep),
              const SizedBox(width: AppConstants.spaceS),
              MetricBar(label: '🧠', value: entry.focus),
              const SizedBox(width: AppConstants.spaceS),
              MetricBar(label: '😊', value: entry.mood),
            ],
          ),
        ],
      ),
    );
  }
}
