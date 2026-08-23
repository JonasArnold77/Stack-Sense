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

/// Ein schneller Such-Treffer (Name/Kategorie) — bevor die volle Karte
/// generiert wurde. Siehe ApiService.searchSupplements / lookupSupplement.
class SupplementSearchResult {
  final String id;
  final String name;
  final String category;

  const SupplementSearchResult({
    required this.id,
    required this.name,
    required this.category,
  });

  factory SupplementSearchResult.fromJson(Map<String, dynamic> json) =>
      SupplementSearchResult(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String? ?? '',
      );
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

  Map<String, dynamic> toJson() => {
        'label': label,
        'shop': shop,
        'url': url,
        'note': note,
      };
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

  Map<String, dynamic> toJson() => {
        'text': text,
        'evidence_level': evidenceLevel.name,
        'condition': condition,
      };
}

/// Eine Synergie-Empfehlung — Kombination von Wirkstoffen die sich gegenseitig verstärken.
class SupplementSynergy {
  final String id;
  /// Die beteiligten Wirkstoffe (z.B. ["Magnesium Bisglycinat", "Vitamin B6"])
  final List<String> substances;
  final EvidenceLevel evidenceLevel;
  /// Passgenauigkeit für das aktuelle Ziel: 0–100
  final int synergyScore;
  /// Mechanistische Erklärung warum diese Kombination wirkt
  final String synergyExplanation;
  /// Optionaler kombinierter Einnahmehinweis
  final String? dosageHint;

  const SupplementSynergy({
    required this.id,
    required this.substances,
    required this.evidenceLevel,
    required this.synergyScore,
    required this.synergyExplanation,
    this.dosageHint,
  });

  factory SupplementSynergy.fromJson(Map<String, dynamic> json) {
    final rawSubstances = json['substances'] as List<dynamic>? ?? [];
    return SupplementSynergy(
      id: json['id'] as String,
      substances: rawSubstances.map((e) => e as String).toList(),
      evidenceLevel: _parseLevel(json['evidence_level'] as String? ?? 'yellow'),
      synergyScore: (json['synergy_score'] as num?)?.toInt() ?? 70,
      synergyExplanation: json['synergy_explanation'] as String? ?? '',
      dosageHint: json['dosage_hint'] as String?,
    );
  }

  static EvidenceLevel _parseLevel(String raw) => switch (raw) {
        'green' => EvidenceLevel.green,
        'red' => EvidenceLevel.red,
        _ => EvidenceLevel.yellow,
      };
}

/// Stoffklasse des Supplements — für das Kategorie-Symbol auf der Card.
/// Unabhängig von [Supplement.categories] (zielbezogene Tags wie "Schlaf").
enum SubstanceCategory {
  vitamine,
  mineralstoffe,
  omegaFettsaeuren,
  aminosaeurenProtein,
  pflanzlicheExtrakte,
  darmVerdauung,
}

extension SubstanceCategoryLabel on SubstanceCategory {
  /// Kurzes, kompaktes Label fürs Karten-Symbol.
  String get shortLabel => switch (this) {
        SubstanceCategory.vitamine => 'Vitamin',
        SubstanceCategory.mineralstoffe => 'Mineral',
        SubstanceCategory.omegaFettsaeuren => 'Omega',
        SubstanceCategory.aminosaeurenProtein => 'Protein',
        SubstanceCategory.pflanzlicheExtrakte => 'Pflanze',
        SubstanceCategory.darmVerdauung => 'Darm',
      };

  /// Vollständiger Name für Tooltips/Detailansichten.
  String get fullLabel => switch (this) {
        SubstanceCategory.vitamine => 'Vitamine',
        SubstanceCategory.mineralstoffe => 'Mineralstoffe',
        SubstanceCategory.omegaFettsaeuren => 'Omega & Fettsäuren',
        SubstanceCategory.aminosaeurenProtein => 'Aminosäuren & Protein',
        SubstanceCategory.pflanzlicheExtrakte => 'Pflanzliche Extrakte',
        SubstanceCategory.darmVerdauung => 'Darm & Verdauung',
      };
}

SubstanceCategory? parseSubstanceCategory(String? raw) => switch (raw) {
      'Vitamine' => SubstanceCategory.vitamine,
      'Mineralstoffe' => SubstanceCategory.mineralstoffe,
      'Omega & Fettsäuren' => SubstanceCategory.omegaFettsaeuren,
      'Aminosäuren & Protein' => SubstanceCategory.aminosaeurenProtein,
      'Pflanzliche Extrakte' => SubstanceCategory.pflanzlicheExtrakte,
      'Darm & Verdauung' => SubstanceCategory.darmVerdauung,
      _ => null,
    };

/// Ein Supplement mit allen relevanten Informationen für die Card-Anzeige.
class Supplement {
  final String id;
  final String name;
  final String? substanceName;
  final EvidenceLevel evidenceLevel;
  final SubstanceCategory? substanceCategory;
  final String pitch;         // Kurzer Nutzen-Satz für die Card (persönlich, ohne Fachjargon)
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
  /// Wie gut lässt sich der Bedarf durch Ernährung decken? 1 (kaum) – 10 (sehr leicht)
  final int foodCoverageScore;
  /// Passgenauigkeit für das aktuelle Ziel/Kontext: 0–100
  final int relevanceScore;

  const Supplement({
    required this.id,
    required this.name,
    this.substanceName,
    required this.evidenceLevel,
    this.substanceCategory,
    this.pitch = '',
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
    this.foodCoverageScore = 5,
    this.relevanceScore = 75,
  });

  /// Round-trip-Serialisierung fürs lokale Zwischenspeichern bereits geladener
  /// Empfehlungslisten (siehe RecommendationLocalCache) — dasselbe Feld-Schema
  /// wie die Backend-Antwort, damit ein und derselbe Parser beide Quellen liest.
  factory Supplement.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['product_links'] as List<dynamic>? ?? [];
    final rawCategories = json['categories'] as List<dynamic>? ?? [];
    final rawWirkstoffe = json['enthaltene_wirkstoffe'] as List<dynamic>? ?? [];
    final rawSecondary = json['secondary_benefit'] as Map<String, dynamic>?;

    return Supplement(
      id: json['id'] as String,
      name: json['name'] as String,
      substanceName: json['substance_name'] as String?,
      evidenceLevel: _parseEvidenceLevel(json['evidence_level'] as String? ?? 'yellow'),
      substanceCategory: parseSubstanceCategory(json['substance_category'] as String?),
      pitch: (json['pitch'] as String?) ?? '',
      evidenceReason: (json['evidence_reason'] as String?) ?? '',
      dosage: (json['dosage'] as String?) ?? '',
      intakeTime: (json['intake_time'] as String?) ?? '',
      intakeHint: json['intake_hint'] as String?,
      drugInteraction: json['drug_interaction'] as String?,
      interactionSeverity: _parseSeverity(json['interaction_severity'] as String?),
      productLinks: rawLinks
          .map((e) => ProductLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: rawCategories.map((e) => e as String).toList(),
      supplementType: _parseSupplementType(json['supplement_type'] as String?),
      enthalteneWirkstoffe: rawWirkstoffe.map((e) => e as String).toList(),
      secondaryBenefit:
          rawSecondary != null ? SecondaryBenefit.fromJson(rawSecondary) : null,
      foodCoverageScore: (json['food_coverage_score'] as num?)?.toInt() ?? 5,
      relevanceScore: (json['relevance_score'] as num?)?.toInt() ?? 75,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'substance_name': substanceName,
        'evidence_level': evidenceLevel.name,
        'substance_category': substanceCategory?.fullLabel,
        'pitch': pitch,
        'evidence_reason': evidenceReason,
        'dosage': dosage,
        'intake_time': intakeTime,
        'intake_hint': intakeHint,
        'drug_interaction': drugInteraction,
        'interaction_severity': interactionSeverity.name,
        'product_links': productLinks.map((p) => p.toJson()).toList(),
        'categories': categories,
        'supplement_type': supplementType.name,
        'enthaltene_wirkstoffe': enthalteneWirkstoffe,
        'secondary_benefit': secondaryBenefit?.toJson(),
        'food_coverage_score': foodCoverageScore,
        'relevance_score': relevanceScore,
      };

  static EvidenceLevel _parseEvidenceLevel(String raw) => switch (raw) {
        'green' => EvidenceLevel.green,
        'yellow' => EvidenceLevel.yellow,
        _ => EvidenceLevel.red,
      };

  static InteractionSeverity _parseSeverity(String? raw) => switch (raw) {
        'timing' => InteractionSeverity.timing,
        'moderate' => InteractionSeverity.moderate,
        'high' => InteractionSeverity.high,
        _ => InteractionSeverity.none,
      };

  static SupplementType _parseSupplementType(String? raw) => switch (raw) {
        'group' => SupplementType.group,
        _ => SupplementType.single,
      };
}
