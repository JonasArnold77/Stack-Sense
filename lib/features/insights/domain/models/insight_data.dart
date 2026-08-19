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

/// Korrelations-Insight für eine Gruppe von Supplements (1 oder mehr).
///
/// Wenn mehrere Supplements ungefähr gleichzeitig für dieselbe Dimension
/// hinzugefügt wurden, werden sie als Gruppe ausgewertet — der Vergleich
/// Vorher/Nachher basiert auf dem Datum des frühesten Supplements.
class CorrelationInsight {
  /// Alle Supplement-IDs dieser Gruppe (≥ 1).
  final List<String> supplementIds;

  /// Alle Supplement-Namen dieser Gruppe (≥ 1).
  final List<String> supplementNames;

  final String dimension; // "Energie" | "Schlaf" | "Fokus" | "Stimmung" | "Gesamt"
  final double scoreBefore; // 1–5, Durchschnitt der letzten 7 Tage vor dem Supplement
  final double scoreAfter;  // 1–5, Durchschnitt der ersten 7 Tage nach dem Supplement
  final int daysAfter;      // Wie viele Tage Daten nach dem Supplement vorhanden

  const CorrelationInsight({
    required this.supplementIds,
    required this.supplementNames,
    required this.dimension,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.daysAfter,
  });

  // ---------------------------------------------------------------------------
  // Backward-compat getters (für Stellen die noch einzelnes Supplement erwarten)
  // ---------------------------------------------------------------------------

  /// Primäres Supplement-ID (erstes in der Gruppe).
  String get supplementId => supplementIds.isNotEmpty ? supplementIds.first : '';

  /// Lesbarer Kombinationsname aller Supplements in der Gruppe:
  /// "Magnesium" | "Melatonin und Magnesium" | "A, B und C"
  String get supplementName {
    if (supplementNames.isEmpty) return '';
    if (supplementNames.length == 1) return supplementNames.first;
    if (supplementNames.length == 2) {
      return '${supplementNames[0]} und ${supplementNames[1]}';
    }
    final allButLast = supplementNames.sublist(0, supplementNames.length - 1);
    return '${allButLast.join(', ')} und ${supplementNames.last}';
  }

  /// true wenn ≥ 2 Supplements zu dieser Gruppe kombiniert wurden.
  bool get isGrouped => supplementIds.length > 1;

  // ---------------------------------------------------------------------------
  // Berechnete Statistik
  // ---------------------------------------------------------------------------

  /// Prozentuale Veränderung (kann negativ sein).
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
