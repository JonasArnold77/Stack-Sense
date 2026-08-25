import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/feature_gate.dart';
import '../../../settings/domain/models/feature_keys.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../checkin/domain/models/checkin_entry.dart';
import '../../../recommendations/domain/models/supplement.dart' show EvidenceLevel;
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class GoalProgressScreen extends ConsumerWidget {
  final String goalName;

  const GoalProgressScreen({super.key, required this.goalName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stack = ref.watch(stackProvider);
    final checkins = ref.watch(checkinProvider);

    final goalEntries = stack
        .where((e) => e.addedFromGoals.contains(goalName))
        .toList()
      ..sort((a, b) => a.addedAt.compareTo(b.addedAt));

    final color = goalColor(goalName);
    final stage = _calculateStage(goalEntries, checkins);
    final trend = _buildTrend(checkins);
    final improvement = _calcImprovement(goalEntries, checkins);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _GoalHeader(
              goalName: goalName,
              color: color,
              supplementCount: goalEntries.length,
              onBack: () => context.pop(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingH,
              vertical: AppConstants.spaceL,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 4-Stufen Fortschritt
                _StageProgress(stage: stage, color: color),

                const SizedBox(height: AppConstants.spaceL),

                // Verbesserungs-Insight
                if (improvement != null) ...[
                  _ImprovementBanner(improvement: improvement, color: color),
                  const SizedBox(height: AppConstants.spaceL),
                ],

                // Verlauf-Chart
                if (trend.length >= 3) ...[
                  _TrendCard(trend: trend, goalName: goalName, color: color),
                  const SizedBox(height: AppConstants.spaceL),
                ],

                // Supplements für dieses Ziel
                _SupplementsSection(entries: goalEntries),

                const SizedBox(height: AppConstants.spaceM),

                // Button: Weitere Supplements für dieses Ziel entdecken
                _AddMoreSupplementsButton(
                  goalName: goalName,
                  color: color,
                ),

                SizedBox(
                  height: AppConstants.spaceXXL +
                      MediaQuery.of(context).padding.bottom,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Berechnung ----

  int _calculateStage(List<StackEntry> entries, List<CheckinEntry> checkins) {
    if (entries.isEmpty) return 1;
    final firstAdded = entries
        .map((e) => e.addedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final weeksSince = DateTime.now().difference(firstAdded).inDays / 7.0;

    int stage;
    if (weeksSince < 1) {
      stage = 1;
    } else if (weeksSince < 3) {
      stage = 2;
    } else if (weeksSince < 6) {
      stage = 3;
    } else {
      stage = 4;
    }

    // Bonus-Stufe bei messbarer Verbesserung
    final imp = _calcImprovement(entries, checkins);
    if (imp != null && imp.improvementPercent >= 20 && stage < 4) {
      stage++;
    }

    return stage;
  }

  List<double> _buildTrend(List<CheckinEntry> checkins) {
    final sorted = [...checkins]
      ..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));
    final recent =
        sorted.length > 21 ? sorted.sublist(sorted.length - 21) : sorted;
    return recent.map((e) => _metricValue(goalName, e).toDouble()).toList();
  }

  _ImprovementData? _calcImprovement(
    List<StackEntry> entries,
    List<CheckinEntry> checkins,
  ) {
    if (entries.isEmpty || checkins.length < 4) return null;
    final firstAdded = entries
        .map((e) => e.addedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final firstDate =
        DateTime(firstAdded.year, firstAdded.month, firstAdded.day);

    final before =
        checkins.where((c) => c.dateOnly.isBefore(firstDate)).toList();
    final after =
        checkins.where((c) => !c.dateOnly.isBefore(firstDate)).toList();

    if (before.isEmpty || after.isEmpty) return null;

    final avgBefore =
        before.map((e) => _metricValue(goalName, e)).reduce((a, b) => a + b) /
            before.length;
    final avgAfter =
        after.map((e) => _metricValue(goalName, e)).reduce((a, b) => a + b) /
            after.length;

    if (avgBefore == 0) return null;
    final pct = ((avgAfter - avgBefore) / avgBefore * 100).round();

    return _ImprovementData(
      beforeAvg: avgBefore,
      afterAvg: avgAfter,
      improvementPercent: pct,
      metricName: _metricLabel(goalName),
    );
  }

  static int _metricValue(String goal, CheckinEntry e) {
    final g = goal.toLowerCase();
    if (g.contains('schlaf')) return e.sleep;
    if (g.contains('energie') ||
        g.contains('sport') ||
        g.contains('marathon') ||
        g.contains('training')) return e.energy;
    if (g.contains('fokus') || g.contains('konzentration')) return e.focus;
    if (g.contains('stress') || g.contains('stimmung')) return e.mood;
    return ((e.energy + e.sleep + e.focus + e.mood) / 4.0).round();
  }

  static String _metricLabel(String goal) {
    final g = goal.toLowerCase();
    if (g.contains('schlaf')) return 'Schlaf-Score';
    if (g.contains('energie') ||
        g.contains('sport') ||
        g.contains('marathon')) return 'Energie-Score';
    if (g.contains('fokus')) return 'Fokus-Score';
    if (g.contains('stress') || g.contains('stimmung')) return 'Stimmungs-Score';
    return 'Wohlbefinden';
  }
}

// ---------------------------------------------------------------------------
// goalColor — wird auch vom Panel genutzt
// ---------------------------------------------------------------------------

Color goalColor(String goal) {
  const map = <String, Color>{
    'Schlaf': Color(0xFF3F51B5),
    'Energie': Color(0xFFE65100),
    'Immunsystem': Color(0xFF2E7D32),
    'Fokus': Color(0xFF6A1B9A),
    'Sport': Color(0xFFD32F2F),
    'Stress': Color(0xFF0277BD),
    'Herzgesundheit': Color(0xFFAD1457),
    'Verdauung': Color(0xFF558B2F),
    'Knochen': Color(0xFF4E342E),
    'Haare & Haut': Color(0xFF00838F),
    'Basissupplementierung': Color(0xFF1565C0),
  };
  final gLower = goal.toLowerCase();
  for (final entry in map.entries) {
    if (gLower.contains(entry.key.toLowerCase()) ||
        entry.key.toLowerCase().contains(gLower)) {
      return entry.value;
    }
  }
  return map[goal] ?? const Color(0xFF546E7A);
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _ImprovementData {
  final double beforeAvg;
  final double afterAvg;
  final int improvementPercent;
  final String metricName;

  const _ImprovementData({
    required this.beforeAvg,
    required this.afterAvg,
    required this.improvementPercent,
    required this.metricName,
  });
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _GoalHeader extends StatelessWidget {
  final String goalName;
  final Color color;
  final int supplementCount;
  final VoidCallback onBack;

  const _GoalHeader({
    required this.goalName,
    required this.color,
    required this.supplementCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.35) ?? color],
        ),
      ),
      padding: EdgeInsets.only(
        top: topPadding + AppConstants.spaceM,
        left: AppConstants.screenPaddingH,
        right: AppConstants.screenPaddingH,
        bottom: AppConstants.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  'Zurück',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            goalName,
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$supplementCount Supplement${supplementCount == 1 ? '' : 's'} in deinem Stack',
            style: AppTextStyles.bodySmall
                .copyWith(color: Colors.white.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4-Stufen-Fortschritt
// ---------------------------------------------------------------------------

class _StageProgress extends StatelessWidget {
  final int stage; // 1–4
  final Color color;

  const _StageProgress({required this.stage, required this.color});

  static const _stages = [
    (label: 'Gestartet', icon: Icons.flag_outlined),
    (label: 'Aktiv', icon: Icons.local_fire_department_outlined),
    (label: 'Wirkung\nspürbar', icon: Icons.trending_up),
    (label: 'Ziel\nerreicht', icon: Icons.emoji_events_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fortschritt',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spaceM),

          // Kreise + Verbindungslinien
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stageIdx = i ~/ 2;
                final filled = stageIdx < stage - 1;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: filled ? color : AppColors.border,
                  ),
                );
              }
              final idx = i ~/ 2;
              final s = _stages[idx];
              final completed = idx < stage - 1;
              final current = idx == stage - 1;
              final circleColor =
                  completed || current ? color : AppColors.surfaceVariant;
              final iconColor = completed || current
                  ? Colors.white
                  : AppColors.textTertiary;

              return Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      border: current
                          ? Border.all(
                              color: color.withOpacity(0.35), width: 3)
                          : null,
                      boxShadow: current
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(s.icon, size: 20, color: iconColor),
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: AppConstants.spaceS),

          // Labels unter den Kreisen
          Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox());
              final idx = i ~/ 2;
              final s = _stages[idx];
              final active = idx == stage - 1;
              return SizedBox(
                width: 44,
                child: Text(
                  s.label,
                  style: AppTextStyles.caption.copyWith(
                    color: active ? color : AppColors.textTertiary,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 9.5,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),

          const SizedBox(height: AppConstants.spaceM),

          // Aktueller Status als Chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusRound),
              border: Border.all(color: color.withOpacity(0.30)),
            ),
            child: Text(
              'Stufe $stage von 4 · ${_stages[stage - 1].label.replaceAll('\n', ' ')}',
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verbesserungs-Banner
// ---------------------------------------------------------------------------

class _ImprovementBanner extends StatelessWidget {
  final _ImprovementData improvement;
  final Color color;

  const _ImprovementBanner({
    required this.improvement,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = improvement.improvementPercent > 0;
    final sign = isPositive ? '+' : '';
    final bannerColor =
        isPositive ? AppColors.evidenceGreen : AppColors.evidenceRed;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: bannerColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_flat,
            color: bannerColor,
            size: 30,
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sign${improvement.improvementPercent}% ${improvement.metricName}',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: bannerColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPositive
                      ? 'Messbare Verbesserung seit Beginn dieser Supplements'
                      : 'Noch keine messbare Veränderung — bleib dran',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Verlauf-Chart
// ---------------------------------------------------------------------------

class _TrendCard extends StatelessWidget {
  final List<double> trend;
  final String goalName;
  final Color color;

  const _TrendCard({
    required this.trend,
    required this.goalName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                'Verlauf · letzte ${trend.length} Tage',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(values: trend, color: color),
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'vor ${trend.length} Tagen',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
              Text(
                'heute',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs() < 0.01 ? 1.0 : maxVal - minVal;
    const vPad = 0.10;

    double px(int i) => i / (values.length - 1) * size.width;
    double py(double v) =>
        size.height * (1 - vPad) -
        (v - minVal) / range * size.height * (1 - vPad * 2);

    final linePath = Path();
    linePath.moveTo(px(0), py(values[0]));
    for (int i = 1; i < values.length; i++) {
      linePath.lineTo(px(i), py(values[i]));
    }

    // Fill
    final fillPath = Path.from(linePath);
    fillPath.lineTo(px(values.length - 1), size.height);
    fillPath.lineTo(px(0), size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.20), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Endpoint dot
    canvas.drawCircle(
      Offset(px(values.length - 1), py(values.last)),
      5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(px(values.length - 1), py(values.last)),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

// ---------------------------------------------------------------------------
// Supplements-Section
// ---------------------------------------------------------------------------

class _SupplementsSection extends StatelessWidget {
  final List<StackEntry> entries;

  const _SupplementsSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        child: Text(
          'Keine Supplements mehr für dieses Ziel im Stack.',
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplements in diesem Ziel',
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppConstants.spaceS),
        ...entries.map((e) => _SupplementRow(entry: e)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "Weitere Supplements" Button
// ---------------------------------------------------------------------------

class _AddMoreSupplementsButton extends StatelessWidget {
  final String goalName;
  final Color color;

  const _AddMoreSupplementsButton({
    required this.goalName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      featureKey: FeatureKeys.problemfelder,
      child: GestureDetector(
      onTap: () => context.go(AppRoutes.recommendations, extra: goalName),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: AppConstants.spaceM,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: color.withOpacity(0.30), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: color, size: 20),
            const SizedBox(width: AppConstants.spaceS),
            Text(
              'Weitere Supplements für "$goalName" entdecken',
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SupplementRow extends StatelessWidget {
  final StackEntry entry;

  const _SupplementRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (entry.evidenceLevel) {
      EvidenceLevel.green => AppColors.evidenceGreen,
      EvidenceLevel.yellow => AppColors.evidenceYellow,
      EvidenceLevel.red => AppColors.evidenceRed,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceM,
        vertical: AppConstants.spaceM,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: levelColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: AppTextStyles.labelMedium),
                if (entry.substanceName != null)
                  Text(
                    entry.substanceName!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          Text(
            entry.dosage,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
