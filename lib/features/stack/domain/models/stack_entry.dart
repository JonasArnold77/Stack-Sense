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
  final SubstanceCategory? substanceCategory;
  final String dosage;
  final String intakeTime; // Lesbarer Text: "Morgens", "Abends vor dem Schlafen"
  final IntakeSlot intakeSlot; // Kalender-Slot (automatisch abgeleitet)
  final String? intakeHint;
  final String? drugInteraction;
  final InteractionSeverity interactionSeverity;
  final SupplementType supplementType;
  final List<String> enthalteneWirkstoffe; // Nur bei Kombipräparaten befüllt
  final List<String> categories;           // Themen-Tags z.B. ["Schlaf", "Entspannung"]
  final List<String> goalIds;              // Explizit verknüpfte Ziele (für Mehrfachziel-Feature)

  /// Alle Problemfelder / Phasenziele aus denen dieses Supplement hinzugefügt wurde.
  /// Wird beim Hinzufügen gesetzt und kann nachträglich erweitert werden.
  /// Beispiele: ["Schlaf"], ["Schlaf", "Energie"], ["Marathon-Vorbereitung"]
  final List<String> addedFromGoals;

  final bool hasDuplicateWarning; // Orange Warnung wenn Wirkstoff doppelt im Stack

  /// Wenn gesetzt: dieses Supplement gehört zu einem Phasenziel und ist temporär.
  final String? phaseGoalId;

  /// Automatisches Enddatum: nach diesem Datum wird das Supplement aus dem Stack entfernt.
  final DateTime? phaseEndDate;

  final DateTime addedAt;

  const StackEntry({
    required this.id,
    required this.name,
    this.substanceName,
    required this.evidenceLevel,
    this.substanceCategory,
    required this.dosage,
    required this.intakeTime,
    required this.intakeSlot,
    this.intakeHint,
    this.drugInteraction,
    this.interactionSeverity = InteractionSeverity.none,
    this.supplementType = SupplementType.single,
    this.enthalteneWirkstoffe = const [],
    this.categories = const [],
    this.goalIds = const [],
    this.addedFromGoals = const [],
    this.hasDuplicateWarning = false,
    this.phaseGoalId,
    this.phaseEndDate,
    required this.addedAt,
  });

  /// Ob dieses Supplement temporär (für ein Phasenziel) ist.
  bool get isTemporary => phaseGoalId != null;

  /// Kopiert diesen Eintrag mit optionalen Änderungen.
  StackEntry copyWith({
    bool? hasDuplicateWarning,
    InteractionSeverity? interactionSeverity,
    String? drugInteraction,
    DateTime? addedAt,
    List<String>? goalIds,
    List<String>? addedFromGoals,
  }) =>
      StackEntry(
        id: id,
        name: name,
        substanceName: substanceName,
        evidenceLevel: evidenceLevel,
        substanceCategory: substanceCategory,
        dosage: dosage,
        intakeTime: intakeTime,
        intakeSlot: intakeSlot,
        intakeHint: intakeHint,
        drugInteraction: drugInteraction ?? this.drugInteraction,
        interactionSeverity: interactionSeverity ?? this.interactionSeverity,
        supplementType: supplementType,
        enthalteneWirkstoffe: enthalteneWirkstoffe,
        categories: categories,
        goalIds: goalIds ?? this.goalIds,
        addedFromGoals: addedFromGoals ?? this.addedFromGoals,
        hasDuplicateWarning: hasDuplicateWarning ?? this.hasDuplicateWarning,
        phaseGoalId: phaseGoalId,
        phaseEndDate: phaseEndDate,
        addedAt: addedAt ?? this.addedAt,
      );

  /// Supplement → StackEntry konvertieren
  factory StackEntry.fromSupplement(Supplement s) => StackEntry(
        id: s.id,
        name: s.name,
        substanceName: s.substanceName,
        evidenceLevel: s.evidenceLevel,
        substanceCategory: s.substanceCategory,
        dosage: s.dosage,
        intakeTime: s.intakeTime,
        intakeSlot: _deriveSlot(s.intakeTime),
        intakeHint: s.intakeHint,
        drugInteraction: s.drugInteraction,
        interactionSeverity: s.interactionSeverity,
        supplementType: s.supplementType,
        enthalteneWirkstoffe: s.enthalteneWirkstoffe,
        categories: s.categories,
        // phaseGoalId + phaseEndDate werden via StackNotifier.addForPhaseGoal() gesetzt
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
        'substanceCategory': substanceCategory?.name,
        'dosage': dosage,
        'intakeTime': intakeTime,
        'intakeSlot': intakeSlot.name,
        'intakeHint': intakeHint,
        'drugInteraction': drugInteraction,
        'interactionSeverity': interactionSeverity.name,
        'supplementType': supplementType.name,
        'enthalteneWirkstoffe': enthalteneWirkstoffe,
        'categories': categories,
        'goalIds': goalIds,
        'addedFromGoals': addedFromGoals,
        'hasDuplicateWarning': hasDuplicateWarning,
        'phaseGoalId': phaseGoalId,
        'phaseEndDate': phaseEndDate?.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory StackEntry.fromJson(Map<String, dynamic> json) {
    final severityRaw = json['interactionSeverity'] as String?;
    final typeRaw = json['supplementType'] as String?;
    final rawWirkstoffe = json['enthalteneWirkstoffe'] as List<dynamic>? ?? [];

    // Rückwärtskompatibilität: alter String-Wert "addedFrom" → Liste
    final List<String> addedFromGoals;
    final goalsRaw = json['addedFromGoals'] as List<dynamic>?;
    if (goalsRaw != null) {
      addedFromGoals = goalsRaw.map((e) => e as String).toList();
    } else {
      final legacyFrom = json['addedFrom'] as String?;
      addedFromGoals = legacyFrom != null ? [legacyFrom] : [];
    }

    return StackEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      substanceName: json['substanceName'] as String?,
      evidenceLevel: EvidenceLevel.values.byName(json['evidenceLevel'] as String),
      substanceCategory: _parseSubstanceCategoryName(json['substanceCategory'] as String?),
      dosage: json['dosage'] as String,
      intakeTime: json['intakeTime'] as String,
      intakeSlot: IntakeSlot.values.byName(json['intakeSlot'] as String),
      intakeHint: json['intakeHint'] as String?,
      drugInteraction: json['drugInteraction'] as String?,
      interactionSeverity: severityRaw != null
          ? InteractionSeverity.values.byName(severityRaw)
          : InteractionSeverity.none,
      supplementType: typeRaw != null
          ? SupplementType.values.byName(typeRaw)
          : SupplementType.single,
      enthalteneWirkstoffe: rawWirkstoffe.map((e) => e as String).toList(),
      categories: List<String>.from(json['categories'] ?? []),
      goalIds: List<String>.from(json['goalIds'] ?? []),
      addedFromGoals: addedFromGoals,
      hasDuplicateWarning: json['hasDuplicateWarning'] as bool? ?? false,
      phaseGoalId: json['phaseGoalId'] as String?,
      phaseEndDate: json['phaseEndDate'] != null
          ? DateTime.parse(json['phaseEndDate'] as String)
          : null,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

/// Sicheres Parsen des enum-Namens aus SharedPreferences — ältere gespeicherte
/// Stack-Einträge haben dieses Feld noch nicht (null statt Fehler).
SubstanceCategory? _parseSubstanceCategoryName(String? raw) {
  if (raw == null) return null;
  for (final c in SubstanceCategory.values) {
    if (c.name == raw) return c;
  }
  return null;
}
