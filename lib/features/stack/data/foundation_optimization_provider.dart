import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dose_parser.dart';
import '../../../core/utils/slug_match.dart';
import '../../onboarding/data/onboarding_provider.dart';
import '../../onboarding/domain/models/user_profile.dart';
import '../../recommendations/domain/models/supplement_thresholds.dart';
import '../domain/models/stack_entry.dart';
import 'stack_provider.dart';

/// Jedes aktive Optimization-Supplement zählt für die Balken-Füllung +10
/// Prozentpunkte (100-130%-Bereich), gedeckelt bei 130% — ab 3 aktiven
/// Supplements ist der Balken voll, die tatsächliche Zahl wird trotzdem immer
/// als Text angezeigt. Bewusst einfacher, leicht anpassbarer Parameter, da
/// keine exakte Formel vorgegeben war.
const double kOptimizationPctPerSupplement = 10.0;
const double kOptimizationBarCap = 130.0;

/// Deutsche Anzeigenamen für die Foundation-Referenzliste — muss zu den
/// Slugs in kSupplementThresholds passen.
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
};

/// Basis-7 + eng begründete profilabhängige Erweiterung (siehe Plan) — nur
/// bei konkretem Profil-Signal, nicht pauschal alle nährstoffbasierten
/// Supplements.
Set<String> foundationReferenceSlugs(UserProfile profile) {
  final slugs = {
    'vitamin-d3', 'vitamin-b12', 'omega-3', 'magnesium', 'eisen', 'iodine', 'folsaeure',
  };

  final hasThyroidCondition = profile.conditions
      .any((c) => c == 'Hashimoto' || c == 'Schilddrüsenunterfunktion');
  if (hasThyroidCondition) slugs.add('selen');

  final boneRisk = profile.conditions.contains('Osteoporose') ||
      (profile.age != null && profile.age! >= 65);
  if (boneRisk) {
    slugs.add('calcium');
    slugs.add('vitamin-k2');
  }

  return slugs;
}

/// "Besonders wichtig"-Hinweis für Foundation-Items, die durch ein konkretes
/// Profil-Signal zusätzlich priorisiert sind (auch wenn sie schon in der
/// Basis-7 sind, z.B. Eisen/Folsäure bei Schwangerschaft).
bool _isPriorityForProfile(String slug, UserProfile profile) {
  if (profile.isPregnant && (slug == 'folsaeure' || slug == 'eisen' || slug == 'omega-3')) {
    return true;
  }
  if (slug == 'eisen' && profile.conditions.contains('Anämie (Eisenmangel)')) return true;
  if (slug == 'selen' &&
      profile.conditions.any((c) => c == 'Hashimoto' || c == 'Schilddrüsenunterfunktion')) {
    return true;
  }
  if ((slug == 'calcium' || slug == 'vitamin-k2') &&
      (profile.conditions.contains('Osteoporose') ||
          (profile.age != null && profile.age! >= 65))) {
    return true;
  }
  return false;
}

enum FoundationMatchState { missing, unknownAmount, matched }

class FoundationItemStatus {
  final String slug;
  final String label;
  final StackEntry? matchedEntry;
  final FoundationMatchState matchState;
  final DoseZone? zone;
  final double coveragePct; // 0-100, für die Aggregation
  final bool priorityForProfile;

  const FoundationItemStatus({
    required this.slug,
    required this.label,
    this.matchedEntry,
    required this.matchState,
    this.zone,
    required this.coveragePct,
    required this.priorityForProfile,
  });
}

class FoundationOptimizationResult {
  final double foundationScorePct;
  final List<FoundationItemStatus> foundationItems;
  final List<StackEntry> activeOptimizationEntries;
  final double optimizationBarPct;

  const FoundationOptimizationResult({
    required this.foundationScorePct,
    required this.foundationItems,
    required this.activeOptimizationEntries,
    required this.optimizationBarPct,
  });

  static const empty = FoundationOptimizationResult(
    foundationScorePct: 0,
    foundationItems: [],
    activeOptimizationEntries: [],
    optimizationBarPct: 100,
  );
}

FoundationOptimizationResult _compute(List<StackEntry> stack, UserProfile profile) {
  final referenceSlugs = foundationReferenceSlugs(profile);
  final allSlugs = kSupplementThresholds.keys.toSet();

  // Jeden Stack-Eintrag EINMAL auf seinen best passenden kuratierten Slug
  // auflösen (exakt, sonst Präfix-Fallback — siehe resolveToSlug), statt das
  // pro Referenz-Nährstoff erneut zu tun.
  final entrySlugs = <String, String?>{
    for (final e in stack)
      e.id: resolveToSlug(
        name: e.name,
        substanceName: e.substanceName,
        enthalteneWirkstoffe: e.enthalteneWirkstoffe,
        curatedSlugs: allSlugs,
      ),
  };

  final foundationItems = <FoundationItemStatus>[];
  for (final slug in referenceSlugs) {
    final threshold = kSupplementThresholds[slug];
    if (threshold == null) continue; // sollte nicht vorkommen, defensiv

    final matched = stack.where((e) => entrySlugs[e.id] == slug).firstOrNull;
    final priority = _isPriorityForProfile(slug, profile);

    if (matched == null) {
      foundationItems.add(FoundationItemStatus(
        slug: slug,
        label: _kFoundationLabels[slug] ?? slug,
        matchState: FoundationMatchState.missing,
        coveragePct: 0,
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
      priorityForProfile: priority,
    ));
  }

  final foundationScorePct = foundationItems.isEmpty
      ? 0.0
      : foundationItems.map((i) => i.coveragePct).reduce((a, b) => a + b) / foundationItems.length;

  // Optimization-Liste: JEDER Stack-Eintrag (nicht nur Referenzliste), dessen
  // Dosis in die Optimization-Zone fällt — deckt sowohl über-optimal
  // dosierte Foundation-Stoffe als auch reine Optimization-Substanzen ab.
  final activeOptimizationEntries = <StackEntry>[];
  for (final entry in stack) {
    final slug = entrySlugs[entry.id];
    if (slug == null) continue;
    final threshold = kSupplementThresholds[slug]!;
    final dose = trackableDoseFor(entry);
    if (dose == null || !unitsMatch(dose.unit, threshold.unit)) continue;
    if (classifyDose(dose.amount, threshold) == DoseZone.optimization) {
      activeOptimizationEntries.add(entry);
    }
  }

  final optimizationBarPct =
      (100 + activeOptimizationEntries.length * kOptimizationPctPerSupplement)
          .clamp(100.0, kOptimizationBarCap);

  return FoundationOptimizationResult(
    foundationScorePct: foundationScorePct,
    foundationItems: foundationItems,
    activeOptimizationEntries: activeOptimizationEntries,
    optimizationBarPct: optimizationBarPct,
  );
}

final foundationOptimizationProvider = Provider<FoundationOptimizationResult>((ref) {
  final stack = ref.watch(stackProvider);
  final profile = ref.watch(onboardingProvider);
  return _compute(stack, profile);
});
