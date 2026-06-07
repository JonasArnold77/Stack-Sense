/// Evidenzlevel — entspricht der Grün/Gelb/Rot-Ampel
enum EvidenceLevel { green, yellow, red }

/// Eine einzelne Kaufoption für ein Supplement.
class ProductLink {
  final String label;
  final String shop;
  final String url;
  final String? note;

  const ProductLink({
    required this.label,
    required this.shop,
    required this.url,
    this.note,
  });

  factory ProductLink.fromJson(Map<String, dynamic> json) => ProductLink(
        label: json['label'] as String,
        shop: json['shop'] as String,
        url: json['url'] as String,
        note: json['note'] as String?,
      );
}

/// Ein Supplement mit allen relevanten Informationen für die Card-Anzeige.
class Supplement {
  final String id;
  final String name;
  final String? substanceName;
  final EvidenceLevel evidenceLevel;
  final String evidenceReason;
  final String dosage;
  final String intakeTime;
  final String? intakeHint;
  final String? drugInteraction;
  final List<ProductLink> productLinks; // Mehrere Kaufoptionen

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
    this.productLinks = const [],
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
        productLinks: const [],
      );
}
