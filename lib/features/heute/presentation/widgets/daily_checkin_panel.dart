/// Tages-Check-in Panel für den Home Screen.
///
/// Zeigt alle aktiven Problemfelder mit ihrem heutigen Check-in-Status.
/// Ausstehende Felder haben einen „Einchecken"-Button, abgeschlossene
/// zeigen den durchschnittlichen Score als Sterne-Anzeige.
///
/// Nur sichtbar wenn mindestens ein aktives Problemfeld vorhanden ist.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/wearable_compatible_fields.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/wearable_badge.dart';
import '../../../checkin/data/problem_checkin_provider.dart';
import '../../../checkin/domain/models/problem_checkin.dart';

class DailyProblemCheckinPanel extends ConsumerWidget {
  const DailyProblemCheckinPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Direkte Abhängigkeit auf aktive Felder — stellt sicher dass das Panel
    // sofort neugebaut wird wenn ein neues Supplement mit Ziel hinzugefügt wird,
    // unabhängig von der Propagations-Kette über dailyCheckinSummaryProvider.
    ref.watch(activeProblemFieldsProvider);
    final summaries = ref.watch(dailyCheckinSummaryProvider);

    if (summaries.isEmpty) return const SizedBox.shrink();

    final pending =
        summaries.where((s) => s.status == DailyCheckinStatus.pending).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header-Zeile
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tages-Check-in',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (pending > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                ),
                child: Text(
                  '$pending offen',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
          ],
        ),

        const SizedBox(height: AppConstants.spaceS),

        // Problemfeld-Zeilen
        ...summaries.map(
          (summary) => _ProblemFieldCheckinRow(
            summary: summary,
            onTap: () => context.push(
              '${AppRoutes.problemCheckin}/${summary.problemFieldId}',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Einzelne Zeile pro Problemfeld
// ---------------------------------------------------------------------------

class _ProblemFieldCheckinRow extends StatelessWidget {
  final ProblemFieldCheckinSummary summary;
  final VoidCallback onTap;

  const _ProblemFieldCheckinRow({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = summary.status == DailyCheckinStatus.completed;
    final label =
        kProblemFieldLabel[summary.problemFieldId] ?? summary.problemFieldId;
    final icon = _iconFor(summary.problemFieldId);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM, vertical: 12),
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.evidenceGreenLight
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: isDone
              ? AppColors.evidenceGreen.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.evidenceGreen.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(
              isDone ? Icons.check_circle_outline_rounded : icon,
              size: 18,
              color: isDone ? AppColors.evidenceGreen : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (kWearableCompatibleFields.contains(summary.problemFieldId)) ...[
                  const SizedBox(height: 2),
                  const WearableBadge(),
                ],
                if (isDone && summary.todayAvgScore != null)
                  Row(
                    children: [
                      _MiniStars(score: summary.todayAvgScore!),
                      const SizedBox(width: 4),
                      Text(
                        summary.todayAvgScore!.toStringAsFixed(1),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  )
                else
                  Text(
                    'Noch nicht eingecheckt',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),

          // CTA
          if (!isDone)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusRound),
                ),
                child: Text(
                  'Einchecken',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String fieldId) {
    return switch (fieldId) {
      'Schlaf'           => Icons.bedtime_outlined,
      'Energie'          => Icons.bolt_outlined,
      'Fokus'            => Icons.psychology_outlined,
      'Stimmung'         => Icons.mood_outlined,
      'Sport'            => Icons.fitness_center_outlined,
      'Immunsystem'      => Icons.shield_outlined,
      'Verdauung'        => Icons.restaurant_outlined,
      'Frauengesundheit' => Icons.female,
      'Herzgesundheit'   => Icons.favorite_border_outlined,
      'Haut'             => Icons.face_outlined,
      'Gewicht'          => Icons.monitor_weight_outlined,
      'Gelenke'          => Icons.accessibility_new_outlined,
      'Hormone'          => Icons.science_outlined,
      'Basis'            => Icons.stars_outlined,
      _                  => Icons.track_changes_outlined,
    };
  }
}

// ---------------------------------------------------------------------------
// Mini-Sterne (3 Sterne, max)
// ---------------------------------------------------------------------------

class _MiniStars extends StatelessWidget {
  final double score; // 1–5

  const _MiniStars({required this.score});

  @override
  Widget build(BuildContext context) {
    // Auf 3 Sterne skalieren
    final filled = (score / 5 * 3).round().clamp(0, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 12,
          color: const Color(0xFFF4B400),
        ),
      ),
    );
  }
}
