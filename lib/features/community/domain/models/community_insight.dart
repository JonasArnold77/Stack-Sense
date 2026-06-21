/// Aggregierter Community-Insight für ein Supplement:
/// zeigt wie viele Nutzer eine Verbesserung in einer Dimension gemeldet haben.
class CommunityInsight {
  final String supplementName;
  final String dimension;       // "sleep" | "energy" | "focus" | "mood"
  final String dimensionLabel;  // "Schlaf" | "Energie" | "Fokus" | "Stimmung"
  final int improvementPercent; // 0–100
  final int userCount;
  /// Fertige deutsche Anzeigezeile z. B. "Bei 23 Nutzern hat sich schlaf durch … verbessert"
  final String label;

  const CommunityInsight({
    required this.supplementName,
    required this.dimension,
    required this.dimensionLabel,
    required this.improvementPercent,
    required this.userCount,
    required this.label,
  });

  factory CommunityInsight.fromJson(Map<String, dynamic> json) => CommunityInsight(
        supplementName:    json['supplement_name']    as String,
        dimension:         json['dimension']           as String,
        dimensionLabel:    json['dimension_label']     as String,
        improvementPercent: json['improvement_percent'] as int,
        userCount:         json['user_count']          as int,
        label:             json['label']               as String,
      );
}
