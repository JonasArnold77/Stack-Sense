/// Ergebnis eines Kombinationschecks (POST /stack/combination-check) — prüft
/// den GESAMTEN aktuellen Stack auf Wechselwirkungen, Überdosierung durch
/// Summierung und doppelte Wirkstoffe. Ausgelöst über den "Kombination
/// checken lassen"-Hinweis ab einer gewissen Stack-Größe.
enum CombinationWarningCategory { interaction, overdose, duplicate }

CombinationWarningCategory _categoryFromJson(String raw) => switch (raw) {
      'interaction' => CombinationWarningCategory.interaction,
      'overdose' => CombinationWarningCategory.overdose,
      'duplicate' => CombinationWarningCategory.duplicate,
      _ => CombinationWarningCategory.interaction,
    };

/// Nur "moderate"/"high" werden vom Backend geliefert — für diesen Check
/// gibt es keine "harmlose" Stufe, sonst wäre der Punkt gar nicht erst dabei.
enum CombinationWarningSeverity { moderate, high }

CombinationWarningSeverity _severityFromJson(String raw) =>
    raw == 'high' ? CombinationWarningSeverity.high : CombinationWarningSeverity.moderate;

class CombinationWarningGroup {
  final CombinationWarningCategory category;
  final String title;
  final String explanation;
  final CombinationWarningSeverity severity;
  /// Exakt die Namen, wie sie in der Anfrage mitgeschickt wurden — damit sich
  /// jeder Eintrag 1:1 auf einen StackEntry (oder ein Medikament) zurückführen
  /// lässt, um ihn direkt von hier aus entfernen zu können.
  final List<String> supplementNames;

  const CombinationWarningGroup({
    required this.category,
    required this.title,
    required this.explanation,
    required this.severity,
    required this.supplementNames,
  });

  factory CombinationWarningGroup.fromJson(Map<String, dynamic> json) => CombinationWarningGroup(
        category: _categoryFromJson(json['category'] as String),
        title: json['title'] as String,
        explanation: json['explanation'] as String,
        severity: _severityFromJson(json['severity'] as String),
        supplementNames: List<String>.from(json['supplement_names'] as List? ?? const []),
      );
}

class CombinationCheckResult {
  final String summary;
  final List<CombinationWarningGroup> groups;

  const CombinationCheckResult({required this.summary, required this.groups});

  factory CombinationCheckResult.fromJson(Map<String, dynamic> json) => CombinationCheckResult(
        summary: json['summary'] as String? ?? '',
        groups: (json['groups'] as List? ?? const [])
            .map((e) => CombinationWarningGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
