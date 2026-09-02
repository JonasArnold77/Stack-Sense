import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/dose_parser.dart';
import '../../../core/utils/slug_match.dart';
import '../../onboarding/data/onboarding_provider.dart';
import '../../onboarding/domain/models/user_profile.dart';
import '../../recommendations/domain/models/supplement_thresholds.dart';
import '../domain/models/stack_entry.dart';
import 'stack_provider.dart';

/// Level-Namen — Index 0 = Level 1.
const List<String> kFoundationLevelNames = ['Beginner', 'Building', 'Solid', 'Strong', 'Complete'];
const List<String> kOptimizationLevelNames = ['Explorer', 'Active', 'Advanced', 'Performance', 'Elite'];

/// Untere Prozent-Schwelle pro Foundation-Level (Index 0 = Level 1s Startwert).
/// 100% ist erst Level 5 "Complete" — vollständige Abdeckung.
const List<double> _kFoundationLevelThresholds = [0, 20, 40, 60, 100];

/// Untere Anzahl-Schwelle pro Optimization-Level (aktive Problemfeld-
/// Supplements) — bewusst eng gestuft, da "viele" Optimization-Supplements
/// realistisch selten zweistellig werden.
const List<int> _kOptimizationLevelThresholds = [0, 1, 2, 4, 6];

class LevelInfo {
  final int level; // 1-5
  final String name;
  final double progressToNext; // 0.0-1.0, 1.0 wenn Level 5 (kein "nächstes" mehr)
  final bool isMax;

  const LevelInfo({
    required this.level,
    required this.name,
    required this.progressToNext,
    required this.isMax,
  });
}

LevelInfo _levelFor({
  required double value,
  required List<double> thresholds,
  required List<String> names,
}) {
  var levelIndex = 0;
  for (var i = thresholds.length - 1; i >= 0; i--) {
    if (value >= thresholds[i]) {
      levelIndex = i;
      break;
    }
  }
  final isMax = levelIndex == thresholds.length - 1;
  final progress = isMax
      ? 1.0
      : ((value - thresholds[levelIndex]) / (thresholds[levelIndex + 1] - thresholds[levelIndex]))
          .clamp(0.0, 1.0);
  return LevelInfo(
    level: levelIndex + 1,
    name: names[levelIndex],
    progressToNext: progress,
    isMax: isMax,
  );
}

LevelInfo foundationLevelFor(double scorePct) => _levelFor(
      value: scorePct,
      thresholds: _kFoundationLevelThresholds,
      names: kFoundationLevelNames,
    );

LevelInfo optimizationLevelFor(int activeCount) => _levelFor(
      value: activeCount.toDouble(),
      thresholds: _kOptimizationLevelThresholds.map((e) => e.toDouble()).toList(),
      names: kOptimizationLevelNames,
    );

/// Wie [optimizationLevelFor], nur mit dem rohen (nicht gerundeten) Zwischen-
/// wert — für die Level-up-Zähl-Animation in LevelUpOverlay. Die Thresholds
/// [0, 1, 2, 4, 6] sind alle ganze Zahlen; würde man den animierten
/// Zwischenwert vor dem Lookup runden (wie zuvor), läge der gerundete Count
/// bei jedem Ein-Supplement-Schritt (0→1, 1→2, ...) exakt AUF der nächsten
/// Levelgrenze und progressToNext wäre die gesamte Animation über 0% — der
/// Balken hätte sich nie sichtbar bewegt. Mit dem rohen Zwischenwert bleibt
/// der Fortschritt fraktional und der Balken füllt sich sichtbar.
LevelInfo optimizationLevelForRaw(double rawCount) => _levelFor(
      value: rawCount,
      thresholds: _kOptimizationLevelThresholds.map((e) => e.toDouble()).toList(),
      names: kOptimizationLevelNames,
    );

/// Kleine "das braucht praktisch jeder"-Basis (Mangel in der Allgemein-
/// bevölkerung sehr verbreitet) — erscheint bei JEDEM Nutzer, unabhängig vom
/// Profil. Alles andere kommt ausschließlich über konkrete Profil-Signale
/// dazu (siehe _kConditionTriggers/_kGoalTriggers/Alter/Geschlecht/Schwanger-
/// schaft unten) — deshalb ist die Foundation-Liste pro Nutzer unterschiedlich.
const Set<String> _kBaselineSlugs = {'vitamin-d3', 'omega-3', 'magnesium'};

/// Erkrankung (exakte Chip-Strings aus onboarding_step2_screen.dart) →
/// zusätzlich essenzielle Nährstoffe.
const Map<String, List<String>> _kConditionTriggers = {
  'Hashimoto': ['selen', 'iodine', 'vitamin-d3'],
  'Schilddrüsenunterfunktion': ['selen', 'iodine', 'vitamin-d3'],
  'Anämie (Eisenmangel)': ['eisen', 'vitamin-c'],
  'Osteoporose': ['calcium', 'vitamin-d3', 'vitamin-k2', 'magnesium'],
  'Diabetes Typ 2': ['magnesium', 'chromium', 'vitamin-d3'],
  'Bluthochdruck': ['magnesium', 'omega-3'],
  'PCOS': ['magnesium', 'vitamin-d3', 'omega-3'],
  'Depressionen / Burnout': ['omega-3', 'vitamin-d3', 'magnesium'],
  'Migräne': ['magnesium'],
  'Arthritis': ['omega-3', 'vitamin-d3'],
  'Schlafstörungen': ['magnesium'],
};

/// Ziel (exakte Chip-Strings aus onboarding_step3_screen.dart) → zusätzlich
/// essenzielle Nährstoffe.
const Map<String, List<String>> _kGoalTriggers = {
  'Mehr Energie': ['vitamin-b12', 'eisen', 'magnesium'],
  'Besserer Schlaf': ['magnesium'],
  'Fokus & Konzentration': ['omega-3', 'eisen', 'vitamin-b12'],
  'Sport & Regeneration': ['magnesium', 'vitamin-d3', 'eisen'],
  'Immunsystem stärken': ['vitamin-d3', 'zink', 'vitamin-c'],
  'Stimmung & Wohlbefinden': ['omega-3', 'vitamin-d3', 'magnesium'],
  'Herzgesundheit': ['omega-3', 'magnesium'],
  'Haut & Haare': ['biotin', 'zink', 'vitamin-c'],
  'Gelenkgesundheit': ['vitamin-d3', 'omega-3'],
  'Frauengesundheit / Zyklus': ['eisen', 'magnesium', 'vitamin-b6'],
  'Hormonbalance': ['vitamin-d3', 'magnesium', 'zink'],
};

/// Deutsche Anzeigenamen — muss jeden Slug abdecken, der über Basis,
/// Bedingungs- oder Ziel-Trigger auftauchen kann.
const Map<String, String> _kFoundationLabels = {
  'vitamin-d3': 'Vitamin D3',
  'vitamin-b12': 'Vitamin B12',
  'omega-3': 'Omega-3',
  'magnesium': 'Magnesium',
  'eisen': 'Eisen',
  'iodine': 'Jod',
  'folsaeure': 'Folsäure',
  'selen': 'Selen',
  'calcium': 'Calcium',
  'vitamin-k2': 'Vitamin K2',
  'vitamin-c': 'Vitamin C',
  'vitamin-b6': 'Vitamin B6',
  'zink': 'Zink',
  'biotin': 'Biotin',
  'chromium': 'Chrom',
};

/// Alle Nährstoffe, die durch ein KONKRETES Profil-Signal (Erkrankung, Ziel,
/// Alter, Geschlecht, Schwangerschaft) zusätzlich essenziell werden — ohne
/// die kleine Allgemein-Basis. Zwei Nutzer mit unterschiedlichem Profil
/// bekommen dadurch unterschiedliche Ergebnisse.
Set<String> _profileTriggeredSlugs(UserProfile profile) {
  final slugs = <String>{};

  for (final condition in profile.conditions) {
    final triggered = _kConditionTriggers[condition];
    if (triggered != null) slugs.addAll(triggered);
  }
  for (final goal in profile.goals) {
    final triggered = _kGoalTriggers[goal];
    if (triggered != null) slugs.addAll(triggered);
  }

  if (profile.isPregnant) {
    slugs.addAll(['folsaeure', 'eisen', 'omega-3', 'vitamin-d3']);
  }
  if (profile.gender == Gender.female && profile.age != null && profile.age! < 51) {
    slugs.add('eisen');
  }
  if (profile.age != null && profile.age! >= 50) {
    slugs.add('vitamin-b12');
  }
  if (profile.age != null && profile.age! >= 65) {
    slugs.addAll(['calcium', 'vitamin-d3', 'vitamin-k2']);
  }

  return slugs;
}

/// Foundation-Referenzliste = kleine Allgemein-Basis + alle profilspezifisch
/// getriggerten Nährstoffe. Pro Nutzer einzigartig (siehe _profileTriggeredSlugs).
Set<String> foundationReferenceSlugs(UserProfile profile) =>
    _kBaselineSlugs.union(_profileTriggeredSlugs(profile));

/// Ist dieser Stack-Eintrag "aus einem Problemfeld gewählt"? Das ist der
/// Fall, wenn er einem Phasenziel zugeordnet ist (goalIds) ODER einen
/// konkreten Themen-/Zielkontext trägt (addedFromGoals) — mit Ausnahme des
/// generischen "Basissupplementierung"-Labels aus profile_recommendations_
/// screen.dart, das explizit KEINEM spezifischen Problemfeld entspricht.
bool _isFromProblemfeld(StackEntry entry) {
  if (entry.goalIds.isNotEmpty) return true;
  return entry.addedFromGoals.any((g) => g != 'Basissupplementierung');
}

enum FoundationMatchState { missing, unknownAmount, matched }

class FoundationItemStatus {
  final String slug;
  final String label;
  final StackEntry? matchedEntry;
  final FoundationMatchState matchState;
  final DoseZone? zone;
  final double coveragePct; // 0-100, für die Aggregation
  final bool isBaseline; // Teil der kleinen Allgemein-Basis
  final bool priorityForProfile; // durch ein konkretes Profil-Signal getriggert

  const FoundationItemStatus({
    required this.slug,
    required this.label,
    this.matchedEntry,
    required this.matchState,
    this.zone,
    required this.coveragePct,
    required this.isBaseline,
    required this.priorityForProfile,
  });
}

class FoundationOptimizationResult {
  final double foundationScorePct;
  final List<FoundationItemStatus> foundationItems;
  final List<StackEntry> activeOptimizationEntries;

  const FoundationOptimizationResult({
    required this.foundationScorePct,
    required this.foundationItems,
    required this.activeOptimizationEntries,
  });

  LevelInfo get foundationLevel => foundationLevelFor(foundationScorePct);
  LevelInfo get optimizationLevel => optimizationLevelFor(activeOptimizationEntries.length);

  static const empty = FoundationOptimizationResult(
    foundationScorePct: 0,
    foundationItems: [],
    activeOptimizationEntries: [],
  );
}

FoundationOptimizationResult _compute(List<StackEntry> stack, UserProfile profile) {
  final referenceSlugs = foundationReferenceSlugs(profile);
  final profileTriggered = _profileTriggeredSlugs(profile);
  final allThresholdSlugs = kSupplementThresholds.keys.toSet();

  // Jeden Stack-Eintrag EINMAL auf seinen best passenden kuratierten Slug
  // auflösen (exakt, sonst Präfix-Fallback — siehe resolveToSlug), statt das
  // pro Referenz-Nährstoff erneut zu tun.
  final entrySlugs = <String, String?>{
    for (final e in stack)
      e.id: resolveToSlug(
        name: e.name,
        substanceName: e.substanceName,
        enthalteneWirkstoffe: e.enthalteneWirkstoffe,
        curatedSlugs: allThresholdSlugs,
      ),
  };

  final foundationItems = <FoundationItemStatus>[];
  for (final slug in referenceSlugs) {
    final threshold = kSupplementThresholds[slug];
    if (threshold == null) continue; // sollte nicht vorkommen, defensiv

    final matched = stack.where((e) => entrySlugs[e.id] == slug).firstOrNull;
    final isBaseline = _kBaselineSlugs.contains(slug);
    final priority = profileTriggered.contains(slug);

    if (matched == null) {
      foundationItems.add(FoundationItemStatus(
        slug: slug,
        label: _kFoundationLabels[slug] ?? slug,
        matchState: FoundationMatchState.missing,
        coveragePct: 0,
        isBaseline: isBaseline,
        priorityForProfile: priority,
      ));
      continue;
    }

    final dose = trackableDoseFor(matched);
    if (dose == null || !unitsMatch(dose.unit, threshold.unit)) {
      foundationItems.add(FoundationItemStatus(
        slug: slug,
        label: _kFoundationLabels[slug] ?? slug,
        matchedEntry: matched,
        matchState: FoundationMatchState.unknownAmount,
        coveragePct: 0,
        isBaseline: isBaseline,
        priorityForProfile: priority,
      ));
      continue;
    }

    final zone = classifyDose(dose.amount, threshold);
    final min = threshold.minAmount;
    final coveragePct = (min == null || dose.amount < min)
        ? 0.0
        : ((dose.amount - min) / (threshold.optimalAmount - min) * 100).clamp(0.0, 100.0);

    foundationItems.add(FoundationItemStatus(
      slug: slug,
      label: _kFoundationLabels[slug] ?? slug,
      matchedEntry: matched,
      matchState: FoundationMatchState.matched,
      zone: zone,
      coveragePct: coveragePct,
      isBaseline: isBaseline,
      priorityForProfile: priority,
    ));
  }

  final foundationScorePct = foundationItems.isEmpty
      ? 0.0
      : foundationItems.map((i) => i.coveragePct).reduce((a, b) => a + b) / foundationItems.length;

  // Optimization-Liste: ALLE Supplements, die aus einem Problemfeld gewählt
  // wurden — unabhängig von Dosis/Schwellenwerten. Ein Supplement kann
  // gleichzeitig Foundation-relevant UND aus einem Problemfeld gewählt sein
  // (z.B. Vitamin D3 profilbedingt essenziell, aber über "Immunsystem
  // stärken" hinzugefügt) — beide Listen beleuchten unterschiedliche Fragen
  // und schließen sich nicht gegenseitig aus.
  final activeOptimizationEntries = stack.where(_isFromProblemfeld).toList();

  return FoundationOptimizationResult(
    foundationScorePct: foundationScorePct,
    foundationItems: foundationItems,
    activeOptimizationEntries: activeOptimizationEntries,
  );
}

final foundationOptimizationProvider = Provider<FoundationOptimizationResult>((ref) {
  final stack = ref.watch(stackProvider);
  final profile = ref.watch(onboardingProvider);
  return _compute(stack, profile);
});

/// Merkt sich den zuletzt ANGEZEIGTEN Foundation-/Optimization-Stand.
///
/// foundationOptimizationProvider selbst hat kein Gedächtnis an einen
/// "vorherigen" Wert — es berechnet bei jedem Aufruf nur den aktuellen Stand
/// aus dem Stack. Die Heute-Seite hängt aber an einem einfachen ShellRoute
/// (siehe app_router.dart), das seine Kinder bei jedem Tab-Wechsel neu baut —
/// fügt der Nutzer also z.B. über "Problemfelder" ein Supplement hinzu und
/// kehrt zu "Heute" zurück, entsteht FoundationOptimizationLevels komplett
/// neu, mit dem bereits aktualisierten Wert direkt im ersten Frame. Ohne
/// diesen Provider gäbe es also nichts, wovon aus die Level-Karte hoch-
/// animieren könnte — der Sprung wäre unsichtbar statt ein Erlebnis.
/// Dieser Provider lebt unabhängig vom Widget-Baum und merkt sich deshalb
/// zuverlässig, was zuletzt gezeigt wurde, damit die nächste Anzeige davon
/// aus hochzählen kann.
class LevelSnapshot {
  final double foundationScorePct;
  final int optimizationCount;
  const LevelSnapshot({required this.foundationScorePct, required this.optimizationCount});
}

/// Persistiert in SharedPreferences (nicht nur im Speicher) — sonst würde
/// ein App-Neustart, bevor die Feier tatsächlich gesehen wurde (z.B. weil
/// der Nutzer die App direkt nach dem Hinzufügen eines Supplements schließt),
/// den zuletzt gezeigten Stand stillschweigend auf den neuen Wert setzen und
/// die fällige Animation für immer verlieren. State ist bewusst
/// AsyncValue<LevelSnapshot?> statt nur LevelSnapshot? — der Unterschied
/// zwischen "lädt noch" und "wirklich noch nie gezeigt" ist entscheidend:
/// ohne ihn würde JEDER Kaltstart den allerersten Frame (state ist synchron
/// immer erst null, bevor SharedPreferences geantwortet hat) fälschlich als
/// "nie gezeigt" werten und den echten, geladenen Stand sofort überschreiben.
class LastShownLevelsNotifier extends StateNotifier<AsyncValue<LevelSnapshot?>> {
  LastShownLevelsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _keyFoundationPct = 'last_shown_foundation_score_pct';
  static const _keyOptimizationCount = 'last_shown_optimization_count';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final pct = prefs.getDouble(_keyFoundationPct);
    final count = prefs.getInt(_keyOptimizationCount);
    state = AsyncValue.data(
      (pct != null && count != null)
          ? LevelSnapshot(foundationScorePct: pct, optimizationCount: count)
          : null,
    );
  }

  Future<void> markShown(LevelSnapshot snapshot) async {
    state = AsyncValue.data(snapshot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFoundationPct, snapshot.foundationScorePct);
    await prefs.setInt(_keyOptimizationCount, snapshot.optimizationCount);
  }
}

final lastShownLevelsProvider =
    StateNotifierProvider<LastShownLevelsNotifier, AsyncValue<LevelSnapshot?>>(
  (ref) => LastShownLevelsNotifier(),
);
