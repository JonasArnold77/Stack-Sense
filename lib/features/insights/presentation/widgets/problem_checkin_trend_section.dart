/// Insights: "Mein Verlauf" — Trendlinien pro Problemfeld.
///
/// Zeigt für jedes aktive Problemfeld eine Karte mit 4 Mini-Sparklines
/// (eine pro Check-in-Frage, 14 Tage, Y-Achse 1–5).
/// Bei Trend-Änderung > 0.5 in 7 Tagen erscheint ein farbiger Alert-Chip.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../checkin/data/problem_checkin_provider.dart';
import '../../../checkin/data/problem_checkin_questions.dart';
import '../../../checkin/domain/models/problem_checkin.dart';

class ProblemCheckinTrendSection extends ConsumerWidget {
  /// Wenn gesetzt, werden nur diese Problemfelder angezeigt.
  /// null = alle aktiven Felder anzeigen.
  final List<String>? filterFieldIds;

  const ProblemCheckinTrendSection({super.key, this.filterFieldIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFields = ref.watch(activeProblemFieldsProvider);

    // Wenn filterFieldIds gesetzt: Schnittmenge aus aktiv + Filter
    final fieldsToShow = filterFieldIds != null
        ? activeFields.where((f) => filterFieldIds!.contains(f)).toList()
        : activeFields;

    if (fieldsToShow.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mein Verlauf',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Deine Selbsteinschätzung der letzten 14 Tage pro Zielbereich.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        ...fieldsToShow.map(
          (fieldId) => _ProblemFieldTrendCard(fieldId: fieldId),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Karte pro Problemfeld mit 4 Mini-Sparklines
// ---------------------------------------------------------------------------

class _ProblemFieldTrendCard extends ConsumerWidget {
  final String fieldId;

  const _ProblemFieldTrendCard({required this.fieldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const days = 14;
    final history = ref.watch(
      problemCheckinPerQuestionProvider((fieldId: fieldId, days: days)),
    );

    final questions = getQuestionsForField(fieldId);
    final label = kProblemFieldLabel[fieldId] ?? fieldId;

    // Trend-Alert: Durchschnitt letzte 7 Tage vs. vorherige 7 Tage
    final avgHistory = ref.watch(
      problemCheckinHistoryProvider((fieldId: fieldId, days: days)),
    );
    final trendAlert = _computeTrendAlert(avgHistory);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trendAlert != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trendAlert.isPositive
                        ? AppColors.evidenceGreen.withOpacity(0.15)
                        : AppColors.evidenceRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendAlert.isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: trendAlert.isPositive
                            ? AppColors.evidenceGreen
                            : AppColors.evidenceRed,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trendAlert.isPositive ? 'Trend ↑' : 'Trend ↓',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: trendAlert.isPositive
                              ? AppColors.evidenceGreen
                              : AppColors.evidenceRed,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Keine Daten
          if (history.isEmpty || history.values.every((l) => l.isEmpty)) ...[
            const SizedBox(height: AppConstants.spaceM),
            const Text(
              'Noch keine Check-in Daten. Checke täglich ein um deinen Verlauf zu sehen.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textTertiary, height: 1.4),
            ),
          ] else ...[
            const SizedBox(height: AppConstants.spaceM),

            // 2×2 Grid der Mini-Sparklines
            ...List.generate((questions.length / 2).ceil(), (rowIdx) {
              final q1 = rowIdx * 2 < questions.length
                  ? questions[rowIdx * 2]
                  : null;
              final q2 = rowIdx * 2 + 1 < questions.length
                  ? questions[rowIdx * 2 + 1]
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
                child: Row(
                  children: [
                    if (q1 != null)
                      Expanded(
                        child: _MiniSparkline(
                          label: q1.questionText,
                          points: history[q1.id] ?? const [],
                        ),
                      ),
                    if (q1 != null && q2 != null)
                      const SizedBox(width: AppConstants.spaceS),
                    if (q2 != null)
                      Expanded(
                        child: _MiniSparkline(
                          label: q2.questionText,
                          points: history[q2.id] ?? const [],
                        ),
                      ),
                    // Platzhalter wenn ungerade Anzahl
                    if (q2 == null) const Expanded(child: SizedBox()),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  _TrendAlert? _computeTrendAlert(Map<DateTime, double> avgHistory) {
    if (avgHistory.length < 4) return null;
    final sorted = avgHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final half = sorted.length ~/ 2;
    final first = sorted.take(half).map((e) => e.value);
    final second = sorted.skip(half).map((e) => e.value);

    final avgFirst = first.reduce((a, b) => a + b) / first.length;
    final avgSecond = second.reduce((a, b) => a + b) / second.length;
    final delta = avgSecond - avgFirst;

    if (delta.abs() < 0.5) return null;
    return _TrendAlert(isPositive: delta > 0);
  }
}

class _TrendAlert {
  final bool isPositive;
  const _TrendAlert({required this.isPositive});
}

// ---------------------------------------------------------------------------
// Mini-Sparkline für eine einzelne Frage (14 Tage, Y=1–5)
// ---------------------------------------------------------------------------

class _MiniSparkline extends StatelessWidget {
  final String label;
  final List<({DateTime date, int score})> points;

  const _MiniSparkline({required this.label, required this.points});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (points.isEmpty)
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: const Center(
              child: Text(
                'Keine Daten',
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
              ),
            ),
          )
        else
          SizedBox(
            height: 36,
            child: CustomPaint(
              painter: _SparklinePainter(points: points),
              size: const Size(double.infinity, 36),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter für einfache Sparkline
// ---------------------------------------------------------------------------

class _SparklinePainter extends CustomPainter {
  final List<({DateTime date, int score})> points;

  const _SparklinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      // Einzelner Punkt: rechte Kante = heute
      if (points.length == 1) {
        final y = size.height - (points[0].score - 1) / 4 * size.height;
        // Äußerer Ring
        canvas.drawCircle(
          Offset(size.width - 3, y),
          5,
          Paint()
            ..color = AppColors.primary.withOpacity(0.2)
            ..style = PaintingStyle.fill,
        );
        // Kern
        canvas.drawCircle(
          Offset(size.width - 3, y),
          3,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.fill,
        );
      }
      return;
    }

    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));

    // Fläche unter der Linie (fill)
    final fillPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    // Linie
    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < sorted.length; i++) {
      final x = size.width * i / (sorted.length - 1);
      final y = size.height - ((sorted[i].score - 1) / 4) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.points != points;
}
