/// Evidenzlevel — Grün/Gelb/Rot-Ampel
enum EvidenceLevel { green, yellow, red }

/// Schwere einer Wechselwirkung — bestimmt Farbe des Warnfelds im Stack
enum InteractionSeverity {
  none,     // Keine Wechselwirkung
  timing,   // Zeitabstand ausreichend → gelbes Feld
  moderate, // Arzt-Rücksprache empfohlen → oranges Feld
  high,     // Starke bekannte Wechselwirkung → rotes Feld
}

/// Typ des Supplements — Einzel-Wirkstoff oder Kombipräparat
enum SupplementType {
  single, // Einzelner Wirkstoff (z.B. Magnesium Bisglycinat)
  group,  // Kombipräparat (z.B. Vitamin B-Komplex)
}

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

/// Eine natürliche Lebensmittelquelle für einen Nährstoff.
class FoodSource {
  final String food;
  final String note;

  const FoodSource({required this.food, required this.note});

  factory FoodSource.fromJson(Map<String, dynamic> json) => FoodSource(
        food: json['food'] as String,
        note: json['note'] as String? ?? '',
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
  final InteractionSeverity interactionSeverity;
  final List<ProductLink> productLinks;
  final List<String> categories;
  final SupplementType supplementType;
  /// Enthaltene Wirkstoffe — nur bei Kombipräparaten befüllt
  final List<String> enthalteneWirkstoffe;

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
    this.interactionSeverity = InteractionSeverity.none,
    this.productLinks = const [],
    this.categories = const [],
    this.supplementType = SupplementType.single,
    this.enthalteneWirkstoffe = const [],
  });
}
