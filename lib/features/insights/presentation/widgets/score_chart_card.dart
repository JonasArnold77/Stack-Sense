import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/insight_data.dart';

// ---------------------------------------------------------------------------
// Chart Card
// ---------------------------------------------------------------------------

class InsightsChartCard extends StatelessWidget {
  final List<ChartPoint> points;
  final List<SupplementMarker> markers;
  final Color lineColor;
  final String dimLabel;

  const InsightsChartCard({
    super.key,
    required this.points,
    required this.markers,
    required this.lineColor,
    required this.dimLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '$dimLabel-Verlauf',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: CustomPaint(
                painter: ScoreChartPainter(
                  points: points,
                  markers: markers,
                  lineColor: lineColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('schlecht',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text('sehr gut',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class ScoreChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final List<SupplementMarker> markers;
  final Color lineColor;

  const ScoreChartPainter({
    required this.points,
    required this.markers,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const double leftPad = 32;
    const double bottomPad = 24;
    final double chartW = size.width - leftPad;
    final double chartH = size.height - bottomPad;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey[500]);

    for (int y = 1; y <= 5; y++) {
      final dy = chartH - ((y - 1) / 4) * chartH;
      canvas.drawLine(Offset(leftPad, dy), Offset(size.width, dy), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$y', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, dy - tp.height / 2));
    }

    final dates = points.map((p) => p.date).toList();
    final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = maxDate.difference(minDate).inDays;
    if (totalDays == 0) return;

    double xOf(DateTime d) =>
        leftPad + (d.difference(minDate).inDays / totalDays) * chartW;
    double yOf(double score) => chartH - ((score - 1) / 4) * chartH;

    // Supplement marker lines (dashed vertical)
    final markerPaint = Paint()
      ..color = Colors.orange.withOpacity(0.6)
      ..strokeWidth = 1.5;
    for (final m in markers) {
      if (m.addedAt.isBefore(minDate) || m.addedAt.isAfter(maxDate)) continue;
      final mx = xOf(m.addedAt);
      double y = 0;
      while (y < chartH) {
        canvas.drawLine(Offset(mx, y), Offset(mx, math.min(y + 4, chartH)), markerPaint);
        y += 8;
      }
    }

    // 3-point moving average
    final smoothed = <ChartPoint>[];
    for (int i = 0; i < points.length; i++) {
      final start = math.max(0, i - 1);
      final end = math.min(points.length - 1, i + 1);
      final avg = points
              .sublist(start, end + 1)
              .map((p) => p.score)
              .reduce((a, b) => a + b) /
          (end - start + 1);
      smoothed.add(ChartPoint(date: points[i].date, score: avg));
    }

    // Fill under line
    final fillPath = Path()
      ..moveTo(xOf(smoothed.first.date), chartH)
      ..lineTo(xOf(smoothed.first.date), yOf(smoothed.first.score));
    for (int i = 1; i < smoothed.length; i++) {
      fillPath.lineTo(xOf(smoothed[i].date), yOf(smoothed[i].score));
    }
    fillPath
      ..lineTo(xOf(smoothed.last.date), chartH)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );

    // Line
    final linePath = Path()
      ..moveTo(xOf(smoothed.first.date), yOf(smoothed.first.score));
    for (int i = 1; i < smoothed.length; i++) {
      linePath.lineTo(xOf(smoothed[i].date), yOf(smoothed[i].score));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Data point dots
    final dotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(Offset(xOf(p.date), yOf(p.score)), 4, dotBorder);
      canvas.drawCircle(Offset(xOf(p.date), yOf(p.score)), 3, dot);
    }

    // X-axis date labels
    final dateLabelStyle = TextStyle(fontSize: 9, color: Colors.grey[500]);
    void drawDateLabel(DateTime d) {
      final tp = TextPainter(
        text: TextSpan(text: '${d.day}.${d.month}', style: dateLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xOf(d) - tp.width / 2, chartH + 4));
    }

    drawDateLabel(minDate);
    if (totalDays > 3) drawDateLabel(maxDate);
    if (totalDays > 7) drawDateLabel(minDate.add(Duration(days: totalDays ~/ 2)));
  }

  @override
  bool shouldRepaint(ScoreChartPainter old) =>
      old.points != points || old.markers != markers || old.lineColor != lineColor;
}

// ---------------------------------------------------------------------------
// Supplement-Marker Legende
// ---------------------------------------------------------------------------

class MarkerLegendRow extends StatelessWidget {
  final SupplementMarker marker;
  final Color color;

  const MarkerLegendRow({super.key, required this.marker, required this.color});

  @override
  Widget build(BuildContext context) {
    final d = marker.addedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 20,
            color: Colors.orange,
            margin: const EdgeInsets.only(right: 10),
          ),
          Expanded(
            child: Text(
              marker.supplementName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            'seit ${d.day}.${d.month}.${d.year}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
