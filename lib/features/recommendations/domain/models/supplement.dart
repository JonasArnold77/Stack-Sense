/// Evidenzlevel — entspricht der Grün/Gelb/Rot-Ampel
enum EvidenceLevel { green, yellow, red }

/// Ein Supplement mit allen relevanten Informationen für die Card-Anzeige.
class Supplement {
  final String id;
  final String name;
  final String? substanceName; // z.B. "Magnesium Bisglycinat" bei "Magnesium"
  final EvidenceLevel evidenceLevel;
  final String evidenceReason; // Kurzbegründung, max ~120 Zeichen
  final String dosage; // z.B. "400mg täglich"
  final String intakeTime; // z.B. "Abends vor dem Schlafen"
  final String? intakeHint; // z.B. "Mit einer fetthaltigen Mahlzeit"
  final String? drugInteraction; // Wechselwirkungshinweis
  final String? productUrl; // Affiliate-Link

  const Supplement({
    required this.id,
    required this.name,
    this.substanceName,
    required this.evidenceLevel,
    required this.evidenceReason,
    required this.dosage,
    required this.intakeTime,
    this.intakeHint,
    this.drugInteraction,
    this.productUrl,
  });

  factory Supplement.fromJson(Map<String, dynamic> json) => Supplement(
        id: json['id'] as String,
        name: json['name'] as String,
        substanceName: json['substanceName'] as String?,
        evidenceLevel: EvidenceLevel.values.byName(json['evidenceLevel'] as String),
        evidenceReason: json['evidenceReason'] as String,
        dosage: json['dosage'] as String,
        intakeTime: json['intakeTime'] as String,
        intakeHint: json['intakeHint'] as String?,
        drugInteraction: json['drugInteraction'] as String?,
        productUrl: json['productUrl'] as String?,
      );
}
