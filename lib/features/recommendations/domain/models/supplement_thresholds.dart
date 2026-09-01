/// Zwei Schwellenwerte pro Substanz fürs Foundation-&-Optimization-Feature:
/// [minAmount] (Mindestbedarf, unterhalb dessen ein Mangel droht) und
/// [optimalAmount] (übliche/optimale Supplement-Dosis). Quelle für die ~27
/// nährstoffbasierten Substanzen: NIH Office of Dietary Supplements (ODS)
/// Fact Sheets für [minAmount] (RDA/AI), gängige kommerzielle Supplement-
/// Dosierungen (dieselbe Quelle/Methodik wie `supplement_nutrients_seed.json`)
/// für [optimalAmount]. Für die ~40 Aminosäuren/Kräuterextrakte ohne
/// Mangel-Konzept ist [minAmount] `null` — hier ist [optimalAmount] die in
/// Studien gängig verwendete Wirkdosis.
///
/// Bewusst NICHT abgedeckt: Kombi-/Sonderform-Präparate ohne sauberen
/// Einzel-Elementwert (b-vitamine-komplex, zink-magnesium-b6, zink-carnosin,
/// magnesium-l-threonat — z.B. liefert Magnesium-L-Threonat pro Kapsel
/// weniger elementares Magnesium als die RDA, was bei geteilten Präparaten
/// fälschlich immer als "defizitär" erscheinen würde) sowie Probiotika (in
/// KBE/CFU dosiert, keine der von dose_parser.dart unterstützten Einheiten).
class SupplementThreshold {
  final double? minAmount;
  final double optimalAmount;
  final String unit;

  const SupplementThreshold({
    this.minAmount,
    required this.optimalAmount,
    required this.unit,
  });
}

/// Vereinheitlicht Einheiten-Schreibweisen, die dasselbe meinen, bevor eine
/// Stack-Dosis gegen einen Schwellenwert verglichen wird — sonst würde z.B.
/// "µg" (aus dem Freitext geparst) nie zu "mcg" (Schwellenwert-Einheit)
/// passen, obwohl beides Mikrogramm ist.
String _canonicalUnit(String unit) {
  final lower = unit.toLowerCase();
  if (lower == 'µg' || lower == 'μg' || lower == 'mcg') return 'mcg';
  if (lower == 'ie' || lower == 'iu') return 'iu';
  return lower;
}

bool unitsMatch(String a, String b) => _canonicalUnit(a) == _canonicalUnit(b);

enum DoseZone { deficient, foundation, optimization }

/// Ordnet eine Dosis (bereits einheitengeprüft, siehe [unitsMatch]) einer der
/// drei Zonen zu. `minAmount == null` (reine Optimization-Substanz, z.B.
/// Kreatin) hat kein Mangel-Konzept — jede aktive Dosis zählt direkt als
/// Optimization, nicht als Foundation.
DoseZone classifyDose(double amount, SupplementThreshold t) {
  if (t.minAmount == null) return DoseZone.optimization;
  if (amount < t.minAmount!) return DoseZone.deficient;
  if (amount <= t.optimalAmount) return DoseZone.foundation;
  return DoseZone.optimization;
}

/// Schlüssel = Supplement-Slug, identisch zu `Supplement.id`/`StackEntry.id`
/// (siehe backend/data/supplement_knowledge.json) und zu den Slugs in
/// `kSupplementSafetyWarnings`.
const Map<String, SupplementThreshold> kSupplementThresholds = {
  // --- Nährstoffbasiert (Foundation-fähig) ---
  'vitamin-d3': SupplementThreshold(minAmount: 800, optimalAmount: 2000, unit: 'iu'),
  'vitamin-b12': SupplementThreshold(minAmount: 2.4, optimalAmount: 500, unit: 'mcg'),
  'omega-3': SupplementThreshold(minAmount: 250, optimalAmount: 1000, unit: 'mg'),
  'magnesium': SupplementThreshold(minAmount: 310, optimalAmount: 400, unit: 'mg'),
  'eisen': SupplementThreshold(minAmount: 8, optimalAmount: 18, unit: 'mg'),
  'iodine': SupplementThreshold(minAmount: 150, optimalAmount: 300, unit: 'mcg'),
  'folsaeure': SupplementThreshold(minAmount: 400, optimalAmount: 800, unit: 'mcg'),
  'selen': SupplementThreshold(minAmount: 55, optimalAmount: 200, unit: 'mcg'),
  'calcium': SupplementThreshold(minAmount: 500, optimalAmount: 1200, unit: 'mg'),
  'vitamin-k2': SupplementThreshold(minAmount: 90, optimalAmount: 180, unit: 'mcg'),
  'vitamin-k1': SupplementThreshold(minAmount: 90, optimalAmount: 120, unit: 'mcg'),
  'vitamin-a': SupplementThreshold(minAmount: 700, optimalAmount: 900, unit: 'mcg'),
  'vitamin-c': SupplementThreshold(minAmount: 75, optimalAmount: 500, unit: 'mg'),
  'vitamin-e': SupplementThreshold(minAmount: 15, optimalAmount: 134, unit: 'mg'),
  'vitamin-b6': SupplementThreshold(minAmount: 1.3, optimalAmount: 10, unit: 'mg'),
  'zink': SupplementThreshold(minAmount: 8, optimalAmount: 15, unit: 'mg'),
  'biotin': SupplementThreshold(minAmount: 30, optimalAmount: 300, unit: 'mcg'),
  'chromium': SupplementThreshold(minAmount: 25, optimalAmount: 200, unit: 'mcg'),
  'mangan': SupplementThreshold(minAmount: 1.8, optimalAmount: 5, unit: 'mg'),
  // Kalium-Supplements sind aus Sicherheitsgründen regulatorisch auf sehr
  // geringe Einzeldosen begrenzt — decken realistisch nie einen "Mangel" ab,
  // daher kein minAmount (rein als Optimization behandelt).
  'kalium': SupplementThreshold(optimalAmount: 99, unit: 'mg'),
  'lutein': SupplementThreshold(optimalAmount: 20, unit: 'mg'),
  'zeaxanthin': SupplementThreshold(optimalAmount: 4, unit: 'mg'),
  'lycopin': SupplementThreshold(optimalAmount: 10, unit: 'mg'),

  // --- Aminosäuren / Kräuterextrakte / sonstige (reine Optimization) ---
  '5-htp': SupplementThreshold(optimalAmount: 100, unit: 'mg'),
  'alpha-gpc': SupplementThreshold(optimalAmount: 300, unit: 'mg'),
  'alpha-liponsaeure': SupplementThreshold(optimalAmount: 300, unit: 'mg'),
  'ashwagandha': SupplementThreshold(optimalAmount: 600, unit: 'mg'),
  'astaxanthin': SupplementThreshold(optimalAmount: 12, unit: 'mg'),
  'bcaa': SupplementThreshold(optimalAmount: 5000, unit: 'mg'),
  'berberin': SupplementThreshold(optimalAmount: 1000, unit: 'mg'),
  'beta-alanin': SupplementThreshold(optimalAmount: 3200, unit: 'mg'),
  'chlorella': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'citrullin-malat': SupplementThreshold(optimalAmount: 6000, unit: 'mg'),
  'collagen': SupplementThreshold(optimalAmount: 10000, unit: 'mg'),
  'coq10': SupplementThreshold(optimalAmount: 200, unit: 'mg'),
  'curcumin': SupplementThreshold(optimalAmount: 1000, unit: 'mg'),
  'gaba': SupplementThreshold(optimalAmount: 750, unit: 'mg'),
  'ginseng': SupplementThreshold(optimalAmount: 400, unit: 'mg'),
  'glucosamin': SupplementThreshold(optimalAmount: 1500, unit: 'mg'),
  'glycin': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'gruentee-extrakt': SupplementThreshold(optimalAmount: 500, unit: 'mg'),
  'hmb': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'hyaluronsaeure': SupplementThreshold(optimalAmount: 200, unit: 'mg'),
  'ingwer-extrakt': SupplementThreshold(optimalAmount: 1000, unit: 'mg'),
  'kreatin': SupplementThreshold(optimalAmount: 5000, unit: 'mg'),
  'l-arginin': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'l-carnitin': SupplementThreshold(optimalAmount: 2000, unit: 'mg'),
  'l-glutamin': SupplementThreshold(optimalAmount: 5000, unit: 'mg'),
  'l-theanin': SupplementThreshold(optimalAmount: 200, unit: 'mg'),
  'lions-mane': SupplementThreshold(optimalAmount: 1000, unit: 'mg'),
  'maca-lepidium-meyenii': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'mariendistel': SupplementThreshold(optimalAmount: 300, unit: 'mg'),
  'melatonin': SupplementThreshold(optimalAmount: 3, unit: 'mg'),
  'msm': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'nac': SupplementThreshold(optimalAmount: 1200, unit: 'mg'),
  'phosphatidylserine': SupplementThreshold(optimalAmount: 300, unit: 'mg'),
  'quercetin': SupplementThreshold(optimalAmount: 500, unit: 'mg'),
  'reishi': SupplementThreshold(optimalAmount: 1000, unit: 'mg'),
  'resveratrol': SupplementThreshold(optimalAmount: 500, unit: 'mg'),
  'rhodiola-rosea': SupplementThreshold(optimalAmount: 400, unit: 'mg'),
  'spirulina': SupplementThreshold(optimalAmount: 3000, unit: 'mg'),
  'taurin': SupplementThreshold(optimalAmount: 2000, unit: 'mg'),
  'traubenkernextrakt': SupplementThreshold(optimalAmount: 150, unit: 'mg'),
  'weissdorn': SupplementThreshold(optimalAmount: 300, unit: 'mg'),
};
