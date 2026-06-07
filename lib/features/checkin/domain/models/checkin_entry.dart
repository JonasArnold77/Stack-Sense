/// Ein täglicher Check-in — 4 Metriken je 1–5.
class CheckinEntry {
  final DateTime date; // nur Datum relevant, Zeit wird ignoriert
  final int energy;   // 1–5
  final int sleep;    // 1–5
  final int focus;    // 1–5
  final int mood;     // 1–5

  const CheckinEntry({
    required this.date,
    required this.energy,
    required this.sleep,
    required this.focus,
    required this.mood,
  });

  /// Durchschnittswert über alle 4 Metriken
  double get average => (energy + sleep + focus + mood) / 4.0;

  /// Nur Datum (ohne Uhrzeit) für Vergleiche
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'energy': energy,
        'sleep': sleep,
        'focus': focus,
        'mood': mood,
      };

  factory CheckinEntry.fromJson(Map<String, dynamic> json) => CheckinEntry(
        date: DateTime.parse(json['date'] as String),
        energy: json['energy'] as int,
        sleep: json['sleep'] as int,
        focus: json['focus'] as int,
        mood: json['mood'] as int,
      );
}
