/// Ein Datenpunkt für das Score-Verlaufs-Chart.
class ChartPoint {
  final DateTime date;
  final double score; // 1.0–5.0

  const ChartPoint({required this.date, required this.score});
}

/// Markierung im Chart für den Zeitpunkt, wann ein Supplement hinzugefügt wurde.
class SupplementMarker {
  final String supplementId;
  final String supplementName;
  final DateTime addedAt;

  const SupplementMarker({
    required this.supplementId,
    required this.supplementName,
    required this.addedAt,
  });
}

/// Korrelations-Insight für ein einzelnes Supplement:
/// Vergleich Durchschnittsscore 7 Tage vor vs. nach dem Hinzufügen.
class CorrelationInsight {
  final String supplementId;
  final String supplementName;
  final String dimension; // "Energie", "Schlaf", "Fokus", "Stimmung", "Gesamt"
  final double scoreBefore; // 1–5
  final double scoreAfter;  // 1–5
  final int daysAfter;      // Wie viele Tage Daten vorhanden

  const CorrelationInsight({
    required this.supplementId,
    required this.supplementName,
    required this.dimension,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.daysAfter,
  });

  /// Prozentuale Änderung (kann negativ sein)
  double get changePercent =>
      scoreBefore > 0 ? ((scoreAfter - scoreBefore) / scoreBefore) * 100 : 0;

  bool get isPositive => scoreAfter > scoreBefore;
  bool get isSignificant => (scoreAfter - scoreBefore).abs() >= 0.3;
}

/// Zusammenfassung aller Insights für den Insights-Screen.
class InsightsData {
  /// Alle Score-Punkte pro Dimension (chronologisch)
  final Map<String, List<ChartPoint>> scoreHistory; // Key: "energy", "sleep", "focus", "mood"

  /// Supplement-Marker für den Chart
  final List<SupplementMarker> markers;

  /// Berechnete Korrelationen (nur wenn genug Daten vorhanden)
  final List<CorrelationInsight> correlations;

  /// Gesamtanzahl Check-ins
  final int totalCheckins;

  /// Aktuelle Streak
  final int streak;

  const InsightsData({
    required this.scoreHistory,
    required this.markers,
    required this.correlations,
    required this.totalCheckins,
    required this.streak,
  });

  bool get hasData => totalCheckins > 0;
  bool get hasCorrelations => correlations.isNotEmpty;
}
