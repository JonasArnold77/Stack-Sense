import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../data/insights_provider.dart';
import '../../data/wearable_health_provider.dart';
import '../../domain/models/insight_data.dart';
import '../../../checkin/data/checkin_provider.dart';
import '../../../checkin/data/problem_checkin_provider.dart';
import '../../../checkin/domain/models/problem_checkin.dart';
import '../../../stack/data/stack_provider.dart';
import '../widgets/correlation_card.dart';
import '../widgets/insights_empty_state.dart';
import '../widgets/problem_checkin_trend_section.dart';
import '../widgets/score_chart_card.dart';
import '../widgets/wearable_connect_sheet.dart';

// ---------------------------------------------------------------------------
// Dimension enum — nur für Score-Chart (Energie/Schlaf/Fokus/Stimmung)
// ---------------------------------------------------------------------------

enum InsightsDim {
  all('Gesamt', 'average', Color(0xFF1565C0)),
  energy('Energie', 'energy', Color(0xFFE65100)),
  sleep('Schlaf', 'sleep', Color(0xFF4527A0)),
  focus('Fokus', 'focus', Color(0xFF1B5E20)),
  mood('Stimmung', 'mood', Color(0xFFAD1457));

  final String label;
  final String key;
  final Color color;
  const InsightsDim(this.label, this.key, this.color);
}

// ---------------------------------------------------------------------------
// Helper: Problemfeld → InsightsDim (nur für Score-Chart-Färbung)
// ---------------------------------------------------------------------------

InsightsDim _problemFieldToDim(String fieldId) => switch (fieldId) {
  'Schlaf'   => InsightsDim.sleep,
  'Energie'  => InsightsDim.energy,
  'Sport'    => InsightsDim.energy,
  'Fokus'    => InsightsDim.focus,
  'Stimmung' => InsightsDim.mood,
  _          => InsightsDim.all,
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  /// null = "Alle Felder". Sonst: die ausgewählte Problemfeld-ID.
  String? _selectedFieldId;
  bool _simLoading = false;

  Future<void> _runSimulation() async {
    final stack = ref.read(stackProvider);
    final rng = math.Random(stack.length);
    final boosts = <String, double>{};
    for (final dim in ['energy', 'sleep', 'focus', 'mood']) {
      boosts[dim] = rng.nextDouble() * 0.8 + 0.4;
    }

    setState(() => _simLoading = true);
    await ref.read(stackProvider.notifier).backdateForSimulation();
    await ref.read(checkinProvider.notifier).simulateHistory(goalBoosts: boosts);

    final stackNames = stack.map((e) => e.name).toList();
    await ref.read(checkinProvider.notifier).syncAllToBackend(stackNames);

    if (mounted) {
      setState(() => _simLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${stackNames.length} Supplement(s) synchronisiert — Empfehlungen neu laden'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _resetSimulation() async {
    await ref.read(checkinProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(insightsProvider);
    final activeFields = ref.watch(activeProblemFieldsProvider);

    // Falls gewähltes Feld aus Stack entfernt wurde → auf "Alle" zurückfallen
    final effectiveFieldId = activeFields.contains(_selectedFieldId)
        ? _selectedFieldId
        : null;

    // Chart-Dim: aus gewähltem Feld ableiten (nur für Farbe)
    final chartDim = effectiveFieldId == null
        ? InsightsDim.all
        : _problemFieldToDim(effectiveFieldId);

    // Chart-Punkte und Label:
    // • "Alle": allgemeiner Score-Verlauf (inkl. Simulation) → scoreHistory['average']
    // • Dim-mapped (Schlaf/Energie/Fokus/Stimmung): eigene Dim-Daten aus Simulation
    //   → scoreHistory[dim.key] (already unique per dim, no cross-contamination)
    // • Unmapped (Herzgesundheit, Haut, …): NUR echte Problem-Check-ins —
    //   sonst würden alle ungemappten Felder denselben 'average'-Graph zeigen
    final List<ChartPoint> chartPoints;
    final String chartLabel;
    if (effectiveFieldId != null && chartDim == InsightsDim.all) {
      // Unmapped field: only real problem check-ins, no generic sim data
      final history = ref.watch(
        problemCheckinHistoryProvider((fieldId: effectiveFieldId, days: 90)),
      );
      chartPoints = history.entries
          .map((e) => ChartPoint(date: e.key, score: e.value))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      chartLabel = kProblemFieldLabel[effectiveFieldId] ?? effectiveFieldId;
    } else {
      // "Alle" or dim-mapped field: use scoreHistory (sim + synthetic problem points)
      chartPoints = data.scoreHistory[chartDim.key] ?? [];
      chartLabel = effectiveFieldId != null
          ? (kProblemFieldLabel[effectiveFieldId] ?? chartDim.label)
          : chartDim.label;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Insights',
            subtitle: 'Dein Fortschritt auf einen Blick',
            actions: [
              IconButton(
                icon: const Icon(Icons.watch_outlined, color: Colors.white, size: 22),
                tooltip: 'Smartwatch-Daten',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.12),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
                // Nach einer erfolgreichen Verbindung direkt zum Datenscreen
                // springen, statt jedes Mal erneut die Auswahl zu zeigen —
                // der Auswahl-Dialog bleibt über den Datenscreen selbst
                // erreichbar (z.B. zum erneuten Verbinden nach einem Fehler).
                onPressed: () {
                  final connected = ref.read(wearableHealthProvider).status ==
                      WearableConnectionStatus.connected;
                  if (connected) {
                    context.push(AppRoutes.wearableData);
                  } else {
                    WearableConnectSheet.show(context);
                  }
                },
              ),
              const SizedBox(width: 8),
              if (_simLoading)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              else
                _SimPopupMenu(
                  onSimulate: _runSimulation,
                  onReset: _resetSimulation,
                ),
            ],
            bottomPadding: 0,
            // Chips: "Alle" + je ein Chip pro aktivem Problemfeld
            bottom: activeFields.isEmpty
                ? const SizedBox(height: 8)
                : _FieldFilterBar(
                    fields: activeFields,
                    selected: effectiveFieldId,
                    onChanged: (f) => setState(() => _selectedFieldId = f),
                  ),
          ),
          Expanded(
            child: data.hasData
                ? _InsightsBody(
                    data: data,
                    dim: chartDim,
                    filterFieldId: effectiveFieldId,
                    chartPoints: chartPoints,
                    chartLabel: chartLabel,
                  )
                : InsightsEmptyState(
                    onSimulate: _runSimulation,
                    loading: _simLoading,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Problemfeld-Filter-Chips (direkt aus activeProblemFieldsProvider)
// ---------------------------------------------------------------------------

class _FieldFilterBar extends StatelessWidget {
  /// Liste aller aktiven Problemfeld-IDs.
  final List<String> fields;

  /// null = "Alle" ausgewählt. Sonst: Problemfeld-ID des gewählten Chips.
  final String? selected;

  /// null = "Alle" gewählt. Sonst: Feld-ID des angeklickten Chips.
  final ValueChanged<String?> onChanged;

  const _FieldFilterBar({
    required this.fields,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // "Alle"-Chip immer zuerst, danach je ein Chip pro Problemfeld
    final chips = <({String? fieldId, String label})>[
      (fieldId: null, label: 'Alle'),
      ...fields.map((f) => (
            fieldId: f,
            label: kProblemFieldLabel[f] ?? f,
          )),
    ];

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: chips.map((chip) {
          final isSelected = chip.fieldId == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(chip.fieldId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.22)
                      : Colors.white.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.7)
                        : Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  chip.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
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

// ---------------------------------------------------------------------------
// Simulation popup menu
// ---------------------------------------------------------------------------

class _SimPopupMenu extends StatelessWidget {
  final VoidCallback onSimulate;
  final VoidCallback onReset;

  const _SimPopupMenu({required this.onSimulate, required this.onReset});

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
      onSelected: (v) {
        if (v == 'simulate') onSimulate();
        if (v == 'reset') onReset();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'simulate',
          child: Row(children: [
            Icon(Icons.play_arrow_outlined, size: 18),
            SizedBox(width: 10),
            Text('Verlauf simulieren (21 Tage)'),
          ]),
        ),
        PopupMenuItem(
          value: 'reset',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Simulationsdaten löschen',
                style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Insights Body (composes extracted widgets)
// ---------------------------------------------------------------------------

class _InsightsBody extends StatelessWidget {
  final InsightsData data;

  /// Nur für Chart-Farbe verwendet.
  final InsightsDim dim;

  /// null = alle Felder anzeigen. Sonst: nur dieses eine Feld.
  final String? filterFieldId;

  /// Vorberechnete Chart-Punkte (parent entscheidet ob Sim-Daten oder nur
  /// Problem-Check-ins — verhindert Datenmix bei feldspezifischer Ansicht).
  final List<ChartPoint> chartPoints;

  /// Anzeigetitel des Charts (Feldname oder Dim-Label).
  final String chartLabel;

  const _InsightsBody({
    required this.data,
    required this.dim,
    this.filterFieldId,
    required this.chartPoints,
    required this.chartLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Korrelationen filtern: bei spezifischem Feld nur passende Dim anzeigen
    final filteredCorrelations = filterFieldId == null
        ? data.correlations
        : data.correlations
            .where((c) => c.dimension == dim.label || c.dimension == 'Gesamt')
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats
        _InsightsStatsRow(data: data),
        const SizedBox(height: 16),

        // Chart
        if (chartPoints.isNotEmpty) ...[
          InsightsChartCard(
            points: chartPoints,
            markers: data.markers,
            lineColor: dim.color,
            dimLabel: chartLabel,
          ),
          const SizedBox(height: 20),
        ],

        // Marker legend
        if (data.markers.isNotEmpty) ...[
          _sectionTitle('Supplement-Verlauf'),
          const SizedBox(height: 8),
          ...data.markers.map((m) =>
              MarkerLegendRow(marker: m, color: dim.color)),
          const SizedBox(height: 20),
        ],

        // Problemfeld-Verlauf (direkt nach Feld-ID filtern)
        ProblemCheckinTrendSection(
          filterFieldIds: filterFieldId == null ? null : [filterFieldId!],
        ),
        const SizedBox(height: 20),

        // Correlations
        if (data.hasCorrelations && filteredCorrelations.isNotEmpty) ...[
          _sectionTitle('Erkenntnisse'),
          const SizedBox(height: 4),
          Text(
            'Basierend auf deinen Check-ins — reine Beobachtung, keine medizinische Aussage.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...filteredCorrelations
              .take(6)
              .map((c) => InsightsCorrelationCard(insight: c)),
        ] else ...[
          InsightTip(totalCheckins: data.totalCheckins),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  static Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _InsightsStatsRow extends StatelessWidget {
  final InsightsData data;
  const _InsightsStatsRow({required this.data});

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
                  fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
