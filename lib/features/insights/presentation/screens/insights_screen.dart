import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../data/insights_provider.dart';
import '../../domain/models/insight_data.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../stack/data/stack_provider.dart';

/// Anzeige-Dimensionen für den Filter
enum _Dim {
  all('Gesamt', 'average', Color(0xFF1565C0)),
  energy('Energie', 'energy', Color(0xFFE65100)),
  sleep('Schlaf', 'sleep', Color(0xFF4527A0)),
  focus('Fokus', 'focus', Color(0xFF1B5E20)),
  mood('Stimmung', 'mood', Color(0xFFAD1457));

  final String label;
  final String key;
  final Color color;
  const _Dim(this.label, this.key, this.color);
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  _Dim _selectedDim = _Dim.all;
  bool _simLoading = false;

  Future<void> _runSimulation() async {
    final stack = ref.read(stackProvider);

    // Welche Problemfelder sollen besonders verbessert werden?
    // Wenn Supplements im Stack: zufällige Auswahl für Boost
    final rng = math.Random(stack.length);
    final boosts = <String, double>{};
    for (final dim in ['energy', 'sleep', 'focus', 'mood']) {
      boosts[dim] = rng.nextDouble() * 0.8 + 0.4; // 0.4–1.2 Boost
    }

    setState(() => _simLoading = true);

    // 1. Stack-Einträge auf Tag 14 datieren damit Korrelation sichtbar wird
    await ref.read(stackProvider.notifier).backdateForSimulation();

    // 2. Check-in-Verlauf über 21 Tage simulieren
    await ref.read(checkinProvider.notifier).simulateHistory(goalBoosts: boosts);

    if (mounted) setState(() => _simLoading = false);
  }

  Future<void> _resetSimulation() async {
    await ref.read(checkinProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(insightsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Insights',
            subtitle: 'Dein Fortschritt auf einen Blick',
            actions: [
              if (_simLoading)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                _GradientPopupMenu(
                  onSimulate: _runSimulation,
                  onReset: _resetSimulation,
                ),
            ],
            bottomPadding: 0,
            bottom: _DimFilter(
              selected: _selectedDim,
              onChanged: (d) => setState(() => _selectedDim = d),
              onDark: true,
            ),
          ),
          Expanded(
            child: data.hasData
                ? _InsightsBody(data: data, dim: _selectedDim)
                : _EmptyState(onSimulate: _runSimulation, loading: _simLoading),
          ),
        ],
      ),
    );
  }
}

// ─── Gradient Popup Menu ─────────────────────────────────────────────────────

/// Demo-Menü im Gradient-Header (weiße Icons)
class _GradientPopupMenu extends StatelessWidget {
  final VoidCallback onSimulate;
  final VoidCallback onReset;

  const _GradientPopupMenu({required this.onSimulate, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.science_outlined, color: Colors.white, size: 22),
      tooltip: 'Demo',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.12),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(8),
      ),
      onSelected: (v) async {
        if (v == 'simulate') onSimulate();
        if (v == 'reset') onReset();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'simulate',
          child: Row(
            children: [
              Icon(Icons.play_arrow_outlined, size: 18),
              SizedBox(width: 10),
              Text('Verlauf simulieren (21 Tage)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Simulationsdaten löschen',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Dimension Filter ────────────────────────────────────────────────────────

class _DimFilter extends StatelessWidget {
  final _Dim selected;
  final ValueChanged<_Dim> onChanged;
  final bool onDark;

  const _DimFilter({
    required this.selected,
    required this.onChanged,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: _Dim.values.map((d) {
          final isSelected = d == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (onDark ? Colors.white.withOpacity(0.22) : d.color)
                      : (onDark ? Colors.white.withOpacity(0.09) : Colors.transparent),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (onDark ? Colors.white.withOpacity(0.7) : d.color)
                        : (onDark ? Colors.white.withOpacity(0.2) : AppColors.border),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (onDark
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

class _InsightsBody extends StatelessWidget {
  final InsightsData data;
  final _Dim dim;

  const _InsightsBody({required this.data, required this.dim});

  @override
  Widget build(BuildContext context) {
    final points = data.scoreHistory[dim.key] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat-Zeile
        _StatsRow(data: data),
        const SizedBox(height: 16),

        // Chart-Card
        if (points.isNotEmpty) ...[
          _ChartCard(
            points: points,
            markers: data.markers,
            dim: dim,
          ),
          const SizedBox(height: 20),
        ],

        // Supplement-Marker Legende
        if (data.markers.isNotEmpty) ...[
          _SectionTitle('Supplement-Verlauf'),
          const SizedBox(height: 8),
          ...data.markers.map((m) => _MarkerLegendRow(marker: m, color: dim.color)),
          const SizedBox(height: 20),
        ],

        // Korrelations-Insights
        if (data.hasCorrelations) ...[
          _SectionTitle('Erkenntnisse'),
          const SizedBox(height: 4),
          Text(
            'Basierend auf deinen Check-ins — reine Beobachtung, keine medizinische Aussage.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...data.correlations
              .where((c) => dim == _Dim.all ? c.dimension == 'Gesamt' : c.dimension == dim.label)
              .take(6)
              .map((c) => _CorrelationCard(insight: c)),
        ] else ...[
          _InsightTip(totalCheckins: data.totalCheckins),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Stats Row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final InsightsData data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.check_circle_outline,
          value: '${data.totalCheckins}',
          label: 'Check-ins',
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.local_fire_department_outlined,
          value: '${data.streak}',
          label: 'Streak',
          color: const Color(0xFFE65100),
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.layers_outlined,
          value: '${data.markers.length}',
          label: 'Supplements',
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chart Card ──────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final List<ChartPoint> points;
  final List<SupplementMarker> markers;
  final _Dim dim;

  const _ChartCard({
    required this.points,
    required this.markers,
    required this.dim,
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
              '${dim.label}-Verlauf',
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
                painter: _ScoreChartPainter(
                  points: points,
                  markers: markers,
                  lineColor: dim.color,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Y-Achsen-Legende
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('schlecht', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text('sehr gut', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chart Painter ───────────────────────────────────────────────────────────

class _ScoreChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final List<SupplementMarker> markers;
  final Color lineColor;

  _ScoreChartPainter({
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

    // Grid-Linien und Y-Achsen-Labels (1–5)
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey[500]);

    for (int y = 1; y <= 5; y++) {
      final dy = chartH - ((y - 1) / 4) * chartH;
      canvas.drawLine(Offset(leftPad, dy), Offset(size.width, dy), gridPaint);
      final span = TextSpan(text: '$y', style: labelStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, dy - tp.height / 2));
    }

    // Zeitbereich
    final dates = points.map((p) => p.date).toList();
    final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = maxDate.difference(minDate).inDays;
    if (totalDays == 0) return;

    double xOf(DateTime d) =>
        leftPad + (d.difference(minDate).inDays / totalDays) * chartW;
    double yOf(double score) =>
        chartH - ((score - 1) / 4) * chartH;

    // Supplement-Marker: gestrichelte vertikale Linien
    final markerPaint = Paint()
      ..color = Colors.orange.withOpacity(0.6)
      ..strokeWidth = 1.5;

    for (final marker in markers) {
      if (marker.addedAt.isBefore(minDate) || marker.addedAt.isAfter(maxDate)) continue;
      final mx = xOf(marker.addedAt);
      // Gestrichelte Linie
      double y = 0;
      while (y < chartH) {
        canvas.drawLine(Offset(mx, y), Offset(mx, math.min(y + 4, chartH)), markerPaint);
        y += 8;
      }
    }

    // Glättung: 3-Punkt gleitender Durchschnitt
    List<ChartPoint> smoothed = [];
    for (int i = 0; i < points.length; i++) {
      final start = math.max(0, i - 1);
      final end = math.min(points.length - 1, i + 1);
      final avg = points.sublist(start, end + 1).map((p) => p.score).reduce((a, b) => a + b) /
          (end - start + 1);
      smoothed.add(ChartPoint(date: points[i].date, score: avg));
    }

    // Gefüllter Bereich unter der Linie
    final fillPath = Path();
    final firstX = xOf(smoothed.first.date);
    final firstY = yOf(smoothed.first.score);
    fillPath.moveTo(firstX, chartH);
    fillPath.lineTo(firstX, firstY);
    for (int i = 1; i < smoothed.length; i++) {
      fillPath.lineTo(xOf(smoothed[i].date), yOf(smoothed[i].score));
    }
    fillPath.lineTo(xOf(smoothed.last.date), chartH);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // Linie
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    linePath.moveTo(xOf(smoothed.first.date), yOf(smoothed.first.score));
    for (int i = 1; i < smoothed.length; i++) {
      linePath.lineTo(xOf(smoothed[i].date), yOf(smoothed[i].score));
    }
    canvas.drawPath(linePath, linePaint);

    // Datenpunkte (kleine Kreise)
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final p in points) {
      final px = xOf(p.date);
      final py = yOf(p.score);
      canvas.drawCircle(Offset(px, py), 4, dotBorderPaint);
      canvas.drawCircle(Offset(px, py), 3, dotPaint);
    }

    // X-Achsen: Datumsmarken (nur erste und letzte + ggf. Mitte)
    final dateLabelStyle = TextStyle(fontSize: 9, color: Colors.grey[500]);
    void drawDateLabel(DateTime d) {
      final label = '${d.day}.${d.month}';
      final span = TextSpan(text: label, style: dateLabelStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(xOf(d) - tp.width / 2, chartH + 4));
    }

    drawDateLabel(minDate);
    if (totalDays > 3) drawDateLabel(maxDate);
    if (totalDays > 7) {
      drawDateLabel(minDate.add(Duration(days: totalDays ~/ 2)));
    }
  }

  @override
  bool shouldRepaint(_ScoreChartPainter old) =>
      old.points != points || old.markers != markers || old.lineColor != lineColor;
}

// ─── Marker Legende ──────────────────────────────────────────────────────────

class _MarkerLegendRow extends StatelessWidget {
  final SupplementMarker marker;
  final Color color;

  const _MarkerLegendRow({required this.marker, required this.color});

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

// ─── Korrelations-Card ───────────────────────────────────────────────────────

class _CorrelationCard extends StatelessWidget {
  final CorrelationInsight insight;

  const _CorrelationCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isPositive = insight.isPositive;
    final change = insight.changePercent;
    final absChange = change.abs().toStringAsFixed(0);

    final bgColor = isPositive
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final borderColor = isPositive
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFFFCC80);
    final textColor = isPositive
        ? const Color(0xFF2E7D32)
        : const Color(0xFFE65100);
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.dimension == 'Gesamt'
                      ? 'Seit du ${insight.supplementName} nimmst...'
                      : '${insight.dimension} · ${insight.supplementName}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPositive
                      ? '${insight.dimension} verbesserte sich um $absChange% '
                          '(${insight.scoreBefore} → ${insight.scoreAfter})'
                      : '${insight.dimension} sank um $absChange% '
                          '(${insight.scoreBefore} → ${insight.scoreAfter})',
                  style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                ),
                if (insight.daysAfter < 7)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Noch ${insight.daysAfter} Tag${insight.daysAfter == 1 ? '' : 'e'} Daten — Ergebnis wird präziser',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ─── Insight Tip (bei wenig Daten) ───────────────────────────────────────────

class _InsightTip extends StatelessWidget {
  final int totalCheckins;
  const _InsightTip({required this.totalCheckins});

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0, 3 - totalCheckins);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining > 0
                  ? 'Noch $remaining Check-in${remaining == 1 ? '' : 's'} bis zu deinen ersten Insights. '
                      'Mach täglich deinen Check-in — nach ein paar Tagen siehst du hier Muster.'
                  : 'Füge Supplements zu deinem Stack hinzu und mach weiter Check-ins — '
                      'dann erkenne ich Zusammenhänge zwischen deinen Supplements und deinem Wohlbefinden.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1565C0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onSimulate;
  final bool loading;

  const _EmptyState({required this.onSimulate, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Icon
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights_outlined,
                size: 44, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Noch keine Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Insights zeigen dir wie deine Supplements mit deinem Wohlbefinden zusammenhängen — '
            'basierend auf deinen täglichen Check-ins.',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // So funktioniert es
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'So bekommst du deine ersten Insights:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 12),
                _InsightStep(
                  number: '1',
                  text: 'Füge min. 1 Supplement zu deinem Stack hinzu',
                  icon: Icons.layers_outlined,
                ),
                const SizedBox(height: 8),
                _InsightStep(
                  number: '2',
                  text: 'Mach mindestens 3 tägliche Check-ins (Energie, Schlaf, Fokus, Stimmung)',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 8),
                _InsightStep(
                  number: '3',
                  text: 'Insights erscheinen automatisch und werden täglich präziser',
                  icon: Icons.auto_graph_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Demo-Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onSimulate,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined, size: 18),
              label: Text(loading ? 'Wird simuliert…' : 'Demo: 21 Tage simulieren'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zeigt dir wie Insights mit echten Daten aussehen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _InsightStep extends StatelessWidget {
  final String number;
  final String text;
  final IconData icon;
  const _InsightStep(
      {required this.number, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                  height: 1.4)),
        ),
      ],
    );
  }
}
