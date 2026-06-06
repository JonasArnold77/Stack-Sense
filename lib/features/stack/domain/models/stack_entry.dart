import '../../../recommendations/domain/models/supplement.dart';

/// Zeitslot für die Einnahme — bestimmt in welcher Spalte der Kalender das Supplement zeigt.
enum IntakeSlot { morning, noon, evening, night }

extension IntakeSlotLabel on IntakeSlot {
  String get label => switch (this) {
        IntakeSlot.morning => 'Morgen',
        IntakeSlot.noon => 'Mittag',
        IntakeSlot.evening => 'Abend',
        IntakeSlot.night => 'Nacht',
      };

  String get emoji => switch (this) {
        IntakeSlot.morning => '☀️',
        IntakeSlot.noon => '🌤️',
        IntakeSlot.evening => '🌆',
        IntakeSlot.night => '🌙',
      };
}

/// Ein Supplement im Stack des Nutzers.
/// Enthält alle Supplement-Daten plus Metadaten (wann hinzugefügt, welcher Slot).
class StackEntry {
  final String id;
  final String name;
  final String? substanceName;
  final EvidenceLevel evidenceLevel;
  final String dosage;
  final String intakeTime; // Lesbarer Text: "Morgens", "Abends vor dem Schlafen"
  final IntakeSlot intakeSlot; // Kalender-Slot (automatisch abgeleitet)
  final String? intakeHint;
  final String? drugInteraction;
  final DateTime addedAt;

  const StackEntry({
    required this.id,
    required this.name,
    this.substanceName,
    required this.evidenceLevel,
    required this.dosage,
    required this.intakeTime,
    required this.intakeSlot,
    this.intakeHint,
    this.drugInteraction,
    required this.addedAt,
  });

  /// Supplement → StackEntry konvertieren
  factory StackEntry.fromSupplement(Supplement s) => StackEntry(
        id: s.id,
        name: s.name,
        substanceName: s.substanceName,
        evidenceLevel: s.evidenceLevel,
        dosage: s.dosage,
        intakeTime: s.intakeTime,
        intakeSlot: _deriveSlot(s.intakeTime),
        intakeHint: s.intakeHint,
        drugInteraction: s.drugInteraction,
        addedAt: DateTime.now(),
      );

  /// Intakezeit-Text → Kalender-Slot ableiten
  static IntakeSlot _deriveSlot(String intakeTime) {
    final lower = intakeTime.toLowerCase();
    if (lower.contains('morgen') ||
        lower.contains('früh') ||
        lower.contains('nüchtern')) {
      return IntakeSlot.morning;
    }
    if (lower.contains('mittag')) return IntakeSlot.noon;
    if (lower.contains('abend') ||
        lower.contains('schlaf') ||
        lower.contains('nacht')) {
      return IntakeSlot.evening;
    }
    return IntakeSlot.morning; // Default
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'substanceName': substanceName,
        'evidenceLevel': evidenceLevel.name,
        'dosage': dosage,
        'intakeTime': intakeTime,
        'intakeSlot': intakeSlot.name,
        'intakeHint': intakeHint,
        'drugInteraction': drugInteraction,
        'addedAt': addedAt.toIso8601String(),
      };

  factory StackEntry.fromJson(Map<String, dynamic> json) => StackEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        substanceName: json['substanceName'] as String?,
        evidenceLevel:
            EvidenceLevel.values.byName(json['evidenceLevel'] as String),
        dosage: json['dosage'] as String,
        intakeTime: json['intakeTime'] as String,
        intakeSlot: IntakeSlot.values.byName(json['intakeSlot'] as String),
        intakeHint: json['intakeHint'] as String?,
        drugInteraction: json['drugInteraction'] as String?,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}
