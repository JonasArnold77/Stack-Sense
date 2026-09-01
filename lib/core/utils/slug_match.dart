/// Spiegelt die Slug-Matching-Logik aus backend/services/nutrient_coverage_service.py
/// (_slugify / _resolve_slug), damit die App ohne Netzwerk-Call pro Supplement-
/// Karte entscheiden kann, ob ein Supplement über Lebensmittel abdeckbar ist.
String slugify(String name) => name.toLowerCase().trim().replaceAll(' ', '-').replaceAll('_', '-');

/// Exakter Treffer zuerst, sonst Präfix-Fallback gegen die Basis-Mineralien:
/// echte Supplement-/Wirkstoffnamen tragen fast immer die konkrete chemische
/// Form ("Magnesium Bisglycinat", "Eisen (Fe2+ / Fe3+)") statt des bloßen
/// Namens. Bei mehreren Präfix-Treffern gewinnt der längste (spezifischste).
String? _resolveSlug(String candidate, Set<String> curatedSlugs) {
  if (curatedSlugs.contains(candidate)) return candidate;
  String? best;
  for (final slug in curatedSlugs) {
    if (candidate.startsWith('$slug-') || candidate.startsWith('$slug(')) {
      if (best == null || slug.length > best.length) best = slug;
    }
  }
  return best;
}

/// Ist dieses Supplement über Lebensmittel abdeckbar? Prüft substanceName
/// zuerst (pharmakologische Identität), dann name, dann bei Kombipräparaten
/// jeden Wirkstoff aus enthalteneWirkstoffe — dieselbe Prioritätsreihenfolge
/// wie _candidate_slugs() im Backend.
bool isNutrientMappable({
  required String name,
  String? substanceName,
  List<String> enthalteneWirkstoffe = const [],
  required Set<String> curatedSlugs,
}) {
  if (curatedSlugs.isEmpty) return false;
  return resolveToSlug(
        name: name,
        substanceName: substanceName,
        enthalteneWirkstoffe: enthalteneWirkstoffe,
        curatedSlugs: curatedSlugs,
      ) !=
      null;
}

/// Wie [isNutrientMappable], gibt aber den getroffenen Slug selbst zurück
/// statt nur ja/nein — z.B. fürs Foundation-&-Optimization-Feature, das
/// wissen muss WELCHE Referenz-Substanz ein Stack-Eintrag ist, um die
/// passenden Schwellenwerte (kSupplementThresholds) nachzuschlagen.
String? resolveToSlug({
  required String name,
  String? substanceName,
  List<String> enthalteneWirkstoffe = const [],
  required Set<String> curatedSlugs,
}) {
  if (curatedSlugs.isEmpty) return null;
  final candidates = <String>[
    if (substanceName != null && substanceName.isNotEmpty) slugify(substanceName),
    slugify(name),
    ...enthalteneWirkstoffe.map(slugify),
  ];
  for (final c in candidates) {
    final hit = _resolveSlug(c, curatedSlugs);
    if (hit != null) return hit;
  }
  return null;
}
