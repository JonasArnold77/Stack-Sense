import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Vordefinierte Phasenziele
// ---------------------------------------------------------------------------

/// Statische Definition eines Phasenziels (unveränderlich, app-seitig fest).
class PhaseGoalDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color accentColor;

  /// Vorschlag für die Dauer in Tagen (kann vom Nutzer angepasst werden).
  final int defaultDurationDays;

  const PhaseGoalDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.defaultDurationDays,
  });
}

/// Die fünf vordefinierten Phasenziele der ersten Version.
const List<PhaseGoalDefinition> kPhaseGoalDefinitions = [
  PhaseGoalDefinition(
    id: 'marathon',
    name: 'Marathon-Vorbereitung',
    description:
        'Intensive Trainingsphase mit erhöhtem Nährstoff- und Regenerationsbedarf.',
    icon: Icons.directions_run,
    accentColor: Color(0xFFE64A19), // Deep Orange
    defaultDurationDays: 84, // 12 Wochen
  ),
  PhaseGoalDefinition(
    id: 'exam',
    name: 'Prüfungsphase',
    description:
        'Fokus, Konzentration und Stressresistenz für intensive Lernphasen stärken.',
    icon: Icons.school_outlined,
    accentColor: Color(0xFF5C35CC), // Violett
    defaultDurationDays: 21, // 3 Wochen
  ),
  PhaseGoalDefinition(
    id: 'travel',
    name: 'Reise & Jetlag',
    description:
        'Zeitzonenwechsel abfedern und das Immunsystem für die Reise vorbereiten.',
    icon: Icons.flight_outlined,
    accentColor: Color(0xFF00897B), // Teal
    defaultDurationDays: 14, // 2 Wochen
  ),
  PhaseGoalDefinition(
    id: 'cold_season',
    name: 'Erkältungssaison',
    description:
        'Immunabwehr gezielt für die kalte Jahreszeit aufbauen und stärken.',
    icon: Icons.health_and_safety_outlined,
    accentColor: Color(0xFFF57F17), // Amber
    defaultDurationDays: 60, // 2 Monate
  ),
  PhaseGoalDefinition(
    id: 'work_stress',
    name: 'Stressige Arbeitsphase',
    description:
        'Nervensystem, Energie und Schlaf bei hohem beruflichem Druck unterstützen.',
    icon: Icons.work_outline,
    accentColor: Color(0xFF1565C0), // Dark Blue
    defaultDurationDays: 30, // 1 Monat
  ),
];

/// Lookup-Helper: gibt die Definition für eine ID zurück.
PhaseGoalDefinition? findDefinition(String id) {
  try {
    return kPhaseGoalDefinitions.firstWhere((d) => d.id == id);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Aktives Phasenziel (Nutzer-Instanz, persistiert)
// ---------------------------------------------------------------------------

/// Eine vom Nutzer aktivierte Instanz eines Phasenziels.
class ActivePhaseGoal {
  /// Eindeutige Instanz-ID (damit dasselbe Ziel mehrfach aktiviert werden kann).
  final String id;

  /// Referenz auf [PhaseGoalDefinition.id].
  final String definitionId;

  final DateTime startDate;
  final DateTime endDate;

  /// IDs der StackEntries die für dieses Ziel hinzugefügt wurden.
  final List<String> supplementIds;

  const ActivePhaseGoal({
    required this.id,
    required this.definitionId,
    required this.startDate,
    required this.endDate,
    this.supplementIds = const [],
  });

  // --- Computed Properties ---

  int get totalDays => endDate.difference(startDate).inDays.clamp(1, 9999);

  int get elapsedDays {
    final now = DateTime.now();
    final d = now.difference(startDate).inDays;
    return d.clamp(0, totalDays);
  }

  int get remainingDays => (totalDays - elapsedDays).clamp(0, totalDays);

  double get progress =>
      totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;

  bool get isExpired {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end =
        DateTime(endDate.year, endDate.month, endDate.day);
    return today.isAfter(end);
  }

  /// Gibt die passende [PhaseGoalDefinition] zurück, oder null wenn nicht gefunden.
  PhaseGoalDefinition? get definition => findDefinition(definitionId);

  // --- Serialisierung ---

  Map<String, dynamic> toJson() => {
        'id': id,
        'definitionId': definitionId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'supplementIds': supplementIds,
      };

  factory ActivePhaseGoal.fromJson(Map<String, dynamic> json) {
    final rawIds = json['supplementIds'] as List<dynamic>? ?? [];
    return ActivePhaseGoal(
      id: json['id'] as String,
      definitionId: json['definitionId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      supplementIds: rawIds.map((e) => e as String).toList(),
    );
  }

  /// Gibt eine Kopie mit geänderten supplementIds zurück.
  ActivePhaseGoal withSupplementIds(List<String> ids) => ActivePhaseGoal(
        id: id,
        definitionId: definitionId,
        startDate: startDate,
        endDate: endDate,
        supplementIds: ids,
      );
}
