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

/// Eine PubMed-Studie mit PMID, Titel, Abstract-Kurzfassung und Link.
class PubMedStudy {
  final String pmid;
  final String title;
  final String abstract;
  final String year;
  final String url;

  const PubMedStudy({
    required this.pmid,
    required this.title,
    required this.abstract,
    required this.year,
    required this.url,
  });

  factory PubMedStudy.fromJson(Map<String, dynamic> json) => PubMedStudy(
        pmid: json['pmid'] as String? ?? '',
        title: json['title'] as String? ?? '',
        abstract: json['abstract'] as String? ?? '',
        year: json['year'] as String? ?? '',
        url: json['url'] as String? ??
            'https://pubmed.ncbi.nlm.nih.gov/${json['pmid']?? ""}/',
      );
}

/// Sekundärer Nutzen — passt zum Profil, aber nicht zur aktuell gewählten Kategorie.
/// Wird als visuell abgetrennter "Auch relevant für dich"-Block in der Card angezeigt.
class SecondaryBenefit {
  final String text;
  final EvidenceLevel evidenceLevel;
  /// Die Erkrankung / der Kontext aus dem Nutzerprofil, für die dieser Nutzen gilt.
  final String condition;

  const SecondaryBenefit({
    required this.text,
    required this.evidenceLevel,
    required this.condition,
  });

  factory SecondaryBenefit.fromJson(Map<String, dynamic> json) => SecondaryBenefit(
        text: json['text'] as String? ?? '',
        evidenceLevel: _parseLevel(json['evidence_level'] as String? ?? 'yellow'),
        condition: json['condition'] as String? ?? '',
      );

  static EvidenceLevel _parseLevel(String raw) => switch (raw) {
        'green' => EvidenceLevel.green,
        'red' => EvidenceLevel.red,
        _ => EvidenceLevel.yellow,
      };
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
  /// Sekundärer Nutzen aus dem Nutzerprofil — nicht zielrelevant, aber profilrelevant.
  /// Null wenn kein zusätzlicher Profilbezug gefunden wurde.
  final SecondaryBenefit? secondaryBenefit;

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
    this.secondaryBenefit,
  });
}
