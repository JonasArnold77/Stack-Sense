import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../checkin/data/checkin_provider.dart';
import '../../checkin/domain/models/checkin_entry.dart';
import '../../stack/data/stack_provider.dart';
import '../../stack/domain/models/stack_entry.dart';
import '../domain/models/insight_data.dart';

/// Berechnet Insights aus Check-in-Verlauf und Stack-Daten.
/// Wird aus checkinProvider + stackProvider abgeleitet — kein eigener State.
final insightsProvider = Provider<InsightsData>((ref) {
  final checkins = ref.watch(checkinProvider);
  final stack = ref.watch(stackProvider);
  return _compute(checkins, stack);
});

InsightsData _compute(
  List<CheckinEntry> checkins,
  List<StackEntry> stack,
) {
  if (checkins.isEmpty) {
    return InsightsData(
      scoreHistory: {},
      markers: [],
      correlations: [],
      totalCheckins: 0,
      streak: 0,
    );
  }

  // Checkins chronologisch sortieren
  final sorted = [...checkins]..sort((a, b) => a.dateOnly.compareTo(b.dateOnly));

  // Score-Verlauf pro Dimension
  final scoreHistory = <String, List<ChartPoint>>{
    'energy': [],
    'sleep': [],
    'focus': [],
    'mood': [],
    'average': [],
  };

  for (final entry in sorted) {
    scoreHistory['energy']!.add(ChartPoint(date: entry.dateOnly, score: entry.energy.toDouble()));
    scoreHistory['sleep']!.add(ChartPoint(date: entry.dateOnly, score: entry.sleep.toDouble()));
    scoreHistory['focus']!.add(ChartPoint(date: entry.dateOnly, score: entry.focus.toDouble()));
    scoreHistory['mood']!.add(ChartPoint(date: entry.dateOnly, score: entry.mood.toDouble()));
    scoreHistory['average']!.add(ChartPoint(date: entry.dateOnly, score: entry.average));
  }

  // Supplement-Marker (nur Einträge die im Check-in-Zeitraum liegen)
  final earliest = sorted.first.dateOnly;
  final markers = stack
      .where((e) => !e.addedAt.isBefore(earliest))
      .map((e) => SupplementMarker(
            supplementId: e.id,
            supplementName: e.name,
            addedAt: DateTime(e.addedAt.year, e.addedAt.month, e.addedAt.day),
          ))
      .toList()
    ..sort((a, b) => a.addedAt.compareTo(b.addedAt));

  // Korrelationen berechnen
  final correlations = <CorrelationInsight>[];

  for (final entry in stack) {
    final addDate = DateTime(entry.addedAt.year, entry.addedAt.month, entry.addedAt.day);

    // Vor-Periode: bis zu 7 Tage vor dem Hinzufügen
    final beforeEntries = sorted.where((c) {
      return c.dateOnly.isBefore(addDate);
    }).toList();

    // Nach-Periode: ab dem Tag des Hinzufügens
    final afterEntries = sorted.where((c) {
      return !c.dateOnly.isBefore(addDate);
    }).toList();

    // Mindestens 2 Einträge in jeder Periode erforderlich
    if (beforeEntries.length < 2 || afterEntries.length < 2) continue;

    // Letzte 7 Tage vor dem Supplement
    final recentBefore = beforeEntries.reversed.take(7).toList();
    // Erste 7 Tage nach dem Supplement (oder weniger wenn noch nicht so lange)
    final recentAfter = afterEntries.take(7).toList();

    final dims = {
      'Energie': (CheckinEntry e) => e.energy.toDouble(),
      'Schlaf': (CheckinEntry e) => e.sleep.toDouble(),
      'Fokus': (CheckinEntry e) => e.focus.toDouble(),
      'Stimmung': (CheckinEntry e) => e.mood.toDouble(),
      'Gesamt': (CheckinEntry e) => e.average,
    };

    for (final dim in dims.entries) {
      final avgBefore = recentBefore.map(dim.value).reduce((a, b) => a + b) / recentBefore.length;
      final avgAfter = recentAfter.map(dim.value).reduce((a, b) => a + b) / recentAfter.length;

      // Nur "Gesamt"-Korrelation anzeigen wenn der Unterschied nicht signifikant genug ist
      // für einzelne Dimensionen; immer alle Dimensionen berechnen aber nur signifikante zeigen
      correlations.add(CorrelationInsight(
        supplementId: entry.id,
        supplementName: entry.name,
        dimension: dim.key,
        scoreBefore: _round(avgBefore),
        scoreAfter: _round(avgAfter),
        daysAfter: afterEntries.length,
      ));
    }
  }

  // Nur signifikante Korrelationen behalten (Änderung >= 0.2)
  // und nach Signifikanz sortieren
  final significant = correlations
      .where((c) => (c.scoreAfter - c.scoreBefore).abs() >= 0.2)
      .toList()
    ..sort((a, b) =>
        (b.scoreAfter - b.scoreBefore).abs().compareTo((a.scoreAfter - a.scoreBefore).abs()));

  return InsightsData(
    scoreHistory: scoreHistory,
    markers: markers,
    correlations: significant,
    totalCheckins: checkins.length,
    streak: _computeStreak(sorted),
  );
}

double _round(double v) => (v * 10).round() / 10;

int _computeStreak(List<CheckinEntry> sorted) {
  if (sorted.isEmpty) return 0;
  final desc = sorted.reversed.toList();
  int streak = 0;
  DateTime expected = _today();
  for (final entry in desc) {
    if (entry.dateOnly == expected) {
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    } else if (entry.dateOnly.isBefore(expected)) {
      break;
    }
  }
  return streak;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
