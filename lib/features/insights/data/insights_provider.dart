import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../checkin/data/checkin_provider.dart';
import '../../checkin/data/problem_checkin_provider.dart';
import '../../checkin/domain/models/checkin_entry.dart';
import '../../checkin/domain/models/problem_checkin.dart';
import '../../stack/data/stack_provider.dart';
import '../../stack/domain/models/stack_entry.dart';
import '../domain/models/insight_data.dart';

/// Supplements die innerhalb dieses Zeitfensters (Tage) für dieselbe Dimension
/// hinzugefügt wurden, werden als Gruppe behandelt.
const _kGroupWindowDays = 3;

/// Mapping: Problemfeld-ID → Score-History-Key im Chart.
/// Felder ohne Mapping (Herzgesundheit, Haut, …) fließen in 'average' ein.
const _kFieldToChartKey = <String, String>{
  'Schlaf':   'sleep',
  'Energie':  'energy',
  'Sport':    'energy',
  'Fokus':    'focus',
  'Stimmung': 'mood',
};

/// Berechnet Insights aus Check-in-Verlauf und Stack-Daten.
/// Liest aus checkinProvider (alter allgemeiner Check-in) UND
/// problemCheckinProvider (neue Problemfeld-Check-ins).
final insightsProvider = Provider<InsightsData>((ref) {
  final checkins        = ref.watch(checkinProvider);
  final stack           = ref.watch(stackProvider);
  final problemCheckins = ref.watch(problemCheckinProvider);
  return _compute(checkins, stack, problemCheckins);
});

InsightsData _compute(
  List<CheckinEntry> checkins,
  List<StackEntry> stack,
  List<ProblemCheckinEntry> problemCheckins,
) {
  final scoreHistory = <String, List<ChartPoint>>{
    'energy': [],
    'sleep':  [],
    'focus':  [],
    'mood':   [],
    'average': [],
  };

  // ── Alter allgemeiner Check-in → Chart-Punkte ────────────────────────────────
  final sorted = [...checkins]..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));

  for (final entry in sorted) {
    scoreHistory['energy']! .add(ChartPoint(date: entry.dateOnly, score: entry.energy.toDouble()));
    scoreHistory['sleep']!  .add(ChartPoint(date: entry.dateOnly, score: entry.sleep.toDouble()));
    scoreHistory['focus']!  .add(ChartPoint(date: entry.dateOnly, score: entry.focus.toDouble()));
    scoreHistory['mood']!   .add(ChartPoint(date: entry.dateOnly, score: entry.mood.toDouble()));
    scoreHistory['average']!.add(ChartPoint(date: entry.dateOnly, score: entry.average));
  }

  // ── Neue Problemfeld-Check-ins → Chart-Punkte (pro Tag, pro Dimension) ───────
  //
  // Für Tage ohne alten Check-in werden synthetische Punkte aus den
  // Problemfeld-Scores erzeugt. Tage die bereits durch den alten Check-in
  // abgedeckt sind werden nicht überschrieben (alter Check-in hat Vorrang).
  if (problemCheckins.isNotEmpty) {
    // Bereits vorhandene Datumspunkte im Chart
    final coveredDates = scoreHistory['average']!.map((p) => p.date).toSet();

    // Problemfeld-Entries nach Datum gruppieren
    final byDate = <DateTime, Map<String, List<double>>>{};
    for (final e in problemCheckins) {
      if (e.avgScore <= 0) continue;
      final date = e.dateOnly;
      byDate.putIfAbsent(date, () => {});
      final chartKey = _kFieldToChartKey[e.problemFieldId];
      if (chartKey != null) {
        byDate[date]!.putIfAbsent(chartKey, () => []).add(e.avgScore);
      }
      // Immer in 'average' einfließen lassen
      byDate[date]!.putIfAbsent('average', () => []).add(e.avgScore);
    }

    // Synthetische Punkte nur für noch nicht abgedeckte Tage
    final newDates = byDate.keys.where((d) => !coveredDates.contains(d)).toList()
      ..sort();

    for (final date in newDates) {
      final dimMap = byDate[date]!;

      // Nur Dimensionen eintragen für die der Nutzer auch wirklich eingecheckt hat.
      // 'average' bekommt immer einen Punkt (Schnitt aller eingecheckten Felder).
      for (final key in ['energy', 'sleep', 'focus', 'mood']) {
        final scores = dimMap[key];
        if (scores != null && scores.isNotEmpty) {
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          scoreHistory[key]!.add(ChartPoint(date: date, score: _round(avg)));
        }
        // Kein Fallback auf average — nur echte Daten pro Dimension
      }

      // Gesamt-Durchschnitt aus allen eingecheckten Feldern dieses Tages
      final allScores = dimMap['average'];
      if (allScores != null && allScores.isNotEmpty) {
        final avg = allScores.reduce((a, b) => a + b) / allScores.length;
        scoreHistory['average']!.add(ChartPoint(date: date, score: _round(avg)));
      }
    }

    // Chart-Punkte pro Dimension chronologisch halten
    for (final list in scoreHistory.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
  }

  final totalCheckins = checkins.length + problemCheckins.length;

  if (totalCheckins == 0) {
    return InsightsData(
      scoreHistory: scoreHistory,
      markers: [],
      correlations: [],
      totalCheckins: 0,
      streak: 0,
    );
  }

  // ── Supplement-Marker (nur innerhalb des Check-in-Zeitraums) ────────────────
  // Frühestes Datum aus altem Check-in ODER Problem-Check-in
  final DateTime? oldEarliest = sorted.isEmpty ? null : sorted.first.dateOnly;
  final DateTime? probEarliest = problemCheckins.isEmpty
      ? null
      : (problemCheckins.map((e) => e.dateOnly).toList()..sort()).first;
  final DateTime earliest = [oldEarliest, probEarliest]
      .whereType<DateTime>()
      .reduce((a, b) => a.isBefore(b) ? a : b);

  final markers = stack
      .where((e) => !e.addedAt.isBefore(earliest))
      .map((e) => SupplementMarker(
            supplementId: e.id,
            supplementName: e.name,
            addedAt: DateTime(e.addedAt.year, e.addedAt.month, e.addedAt.day),
          ))
      .toList()
    ..sort((a, b) => a.addedAt.compareTo(b.addedAt));

  // ── Korrelationen: Supplements pro Dimension clustern ───────────────────────
  //
  // Für jede Dimension:
  //   1. Alle passenden Supplements ermitteln
  //   2. Nach Datum sortieren und in Zeitcluster gruppieren (≤ kGroupWindowDays)
  //   3. Für jeden Cluster: Vor-/Nachher-Score auf Basis des frühesten Datums
  //
  // → Supplements die gleichzeitig hinzugefügt wurden erscheinen als Gruppe,
  //   Supplements mit zeitlichem Abstand werden separat bewertet.

  final dimScorers = <String, double Function(CheckinEntry)>{
    'Energie':  (e) => e.energy.toDouble(),
    'Schlaf':   (e) => e.sleep.toDouble(),
    'Fokus':    (e) => e.focus.toDouble(),
    'Stimmung': (e) => e.mood.toDouble(),
    'Gesamt':   (e) => e.average,
  };

  final correlations = <CorrelationInsight>[];

  for (final dimEntry in dimScorers.entries) {
    final dimName = dimEntry.key;
    final scorer  = dimEntry.value;

    // Supplements die zu dieser Dimension passen, chronologisch
    final dimSupps = (dimName == 'Gesamt'
            ? [...stack]
            : stack.where((e) => _matchesDimension(e, dimName)).toList())
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt));

    if (dimSupps.isEmpty) continue;

    // In Zeitcluster aufteilen
    final clusters = _clusterByTime(dimSupps, _kGroupWindowDays);

    for (final cluster in clusters) {
      // Frühestes Datum im Cluster = Referenz-Schnitt
      final addDate = cluster
          .map((e) => DateTime(e.addedAt.year, e.addedAt.month, e.addedAt.day))
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final beforeEntries = sorted.where((c) => c.dateOnly.isBefore(addDate)).toList();
      final afterEntries  = sorted.where((c) => !c.dateOnly.isBefore(addDate)).toList();

      // Mindestens 2 Datenpunkte auf beiden Seiten
      if (beforeEntries.length < 2 || afterEntries.length < 2) continue;

      final recentBefore = beforeEntries.reversed.take(7).toList();
      final recentAfter  = afterEntries.take(7).toList();

      final avgBefore = recentBefore.map(scorer).reduce((a, b) => a + b) / recentBefore.length;
      final avgAfter  = recentAfter.map(scorer).reduce((a, b) => a + b) / recentAfter.length;

      correlations.add(CorrelationInsight(
        supplementIds:   cluster.map((e) => e.id).toList(),
        supplementNames: cluster.map((e) => e.name).toList(),
        dimension:   dimName,
        scoreBefore: _round(avgBefore),
        scoreAfter:  _round(avgAfter),
        daysAfter:   afterEntries.length,
      ));
    }
  }

  // Nur signifikante Korrelationen (Δ ≥ 0.2), nach Stärke sortiert
  final significant = correlations
      .where((c) => (c.scoreAfter - c.scoreBefore).abs() >= 0.2)
      .toList()
    ..sort((a, b) =>
        (b.scoreAfter - b.scoreBefore).abs()
            .compareTo((a.scoreAfter - a.scoreBefore).abs()));

  // Streak: Tage mit mindestens einem Check-in (alt oder Problem-Feld)
  final allCheckinDates = {
    ...sorted.map((e) => e.dateOnly),
    ...problemCheckins.map((e) => e.dateOnly),
  }.toList()..sort();

  return InsightsData(
    scoreHistory:  scoreHistory,
    markers:       markers,
    correlations:  significant,
    totalCheckins: totalCheckins,
    streak:        _computeStreakFromDates(allCheckinDates),
  );
}

// ---------------------------------------------------------------------------
// Clustering
// ---------------------------------------------------------------------------

/// Teilt eine zeitlich sortierte Liste von StackEntry-Objekten in Cluster auf.
/// Zwei aufeinanderfolgende Supplements gehören zum selben Cluster wenn ihr
/// Datumsabstand ≤ [windowDays] Tage ist.
List<List<StackEntry>> _clusterByTime(
  List<StackEntry> sortedEntries,
  int windowDays,
) {
  if (sortedEntries.isEmpty) return [];

  final clusters = <List<StackEntry>>[];
  var current = [sortedEntries.first];

  for (int i = 1; i < sortedEntries.length; i++) {
    final prev = sortedEntries[i - 1];
    final curr = sortedEntries[i];

    final prevDate = DateTime(prev.addedAt.year, prev.addedAt.month, prev.addedAt.day);
    final currDate = DateTime(curr.addedAt.year, curr.addedAt.month, curr.addedAt.day);

    if (currDate.difference(prevDate).inDays <= windowDays) {
      current.add(curr);
    } else {
      clusters.add(List.unmodifiable(current));
      current = [curr];
    }
  }
  clusters.add(List.unmodifiable(current));
  return clusters;
}

// ---------------------------------------------------------------------------
// Dimension ↔ Kategorie-Matching
// ---------------------------------------------------------------------------

const _dimensionKeywords = <String, List<String>>{
  'Energie': [
    'energie', 'ausdauer', 'fatigue', 'müdigkeit', 'vitalität',
    'energy', 'vitality', 'erschöpfung', 'kraft',
  ],
  'Schlaf': [
    'schlaf', 'entspannung', 'stress', 'ruhe', 'sleep',
    'relaxation', 'einschlafen', 'durchschlafen', 'melatonin',
  ],
  'Fokus': [
    'fokus', 'kognition', 'konzentration', 'gedächtnis', 'brain',
    'nerven', 'focus', 'cognitive', 'mental',
  ],
  'Stimmung': [
    'stimmung', 'wohlbefinden', 'psyche', 'hormon', 'mood',
    'wellbeing', 'depression', 'angst', 'emotion',
  ],
};

bool _matchesDimension(StackEntry entry, String dimension) {
  final keywords = _dimensionKeywords[dimension];
  if (keywords == null || keywords.isEmpty) return true;
  if (entry.categories.isEmpty) return true; // kein Tag = alle Dimensionen

  final catLower = entry.categories.map((c) => c.toLowerCase()).toList();
  return keywords.any(
    (kw) => catLower.any((cat) => cat.contains(kw)),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double _round(double v) => (v * 10).round() / 10;

int _computeStreak(List<CheckinEntry> sorted) {
  if (sorted.isEmpty) return 0;
  final dates = sorted.map((e) => e.dateOnly).toList()..sort();
  return _computeStreakFromDates(dates);
}

/// Berechnet den Streak aus einer sortierten Liste von Datumsangaben.
int _computeStreakFromDates(List<DateTime> sortedDates) {
  if (sortedDates.isEmpty) return 0;
  // Deduplizieren
  final unique = sortedDates.toSet().toList()..sort();
  final desc = unique.reversed.toList();
  int streak = 0;
  DateTime expected = _today();
  for (final date in desc) {
    if (date == expected) {
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    } else if (date.isBefore(expected)) {
      break;
    }
  }
  return streak;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
