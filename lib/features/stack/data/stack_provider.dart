import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recommendations/domain/models/supplement.dart';
import '../domain/models/stack_entry.dart';
import '../domain/repositories/stack_repository.dart';
import 'repositories/stack_repository_impl.dart';

// ---------------------------------------------------------------------------
// Repository-Provider — einziger Ort wo die konkrete Implementierung genannt wird.
// In Tests kann dieser Provider überschrieben werden (z.B. InMemoryStackRepository).
// ---------------------------------------------------------------------------

final stackRepositoryProvider = Provider<StackRepository>(
  (ref) => SharedPreferencesStackRepository(),
);

// ---------------------------------------------------------------------------
// StateNotifier — Business Logic für den Supplement-Stack.
// Kennt nur das StackRepository-Interface, nie SharedPreferences direkt.
// ---------------------------------------------------------------------------

class StackNotifier extends StateNotifier<List<StackEntry>> {
  final StackRepository _repository;

  StackNotifier(this._repository) : super([]) {
    _load();
  }

  // --- Öffentliche Abfragen ---

  bool contains(String supplementId) =>
      state.any((e) => e.id == supplementId);

  List<StackEntry> forSlot(IntakeSlot slot) =>
      state.where((e) => e.intakeSlot == slot).toList();

  // --- Mutationen ---

  /// Einfaches Hinzufügen ohne Duplikat-Check (intern / nach Dialog-Bestätigung).
  /// [goalId]      – wenn angegeben, wird das Supplement diesem Ziel zugeordnet.
  /// [goalContext] – Anzeige-Name des Problemfelds / Phasenziels (z.B. "Schlaf").
  Future<void> add(
    Supplement supplement, {
    String? goalId,
    String? goalContext,
  }) async {
    if (contains(supplement.id)) return;
    var entry = StackEntry.fromSupplement(supplement);
    entry = entry.copyWith(
      goalIds: goalId != null ? [goalId] : entry.goalIds,
      addedFromGoals: goalContext != null ? [goalContext] : entry.addedFromGoals,
    );
    state = [...state, entry];
    await _persist();
  }

  /// Fügt einen weiteren Ziel-Kontext zum bestehenden Stack-Eintrag hinzu.
  /// Doppelte werden ignoriert. Wird aufgerufen wenn der Nutzer auf einer anderen
  /// Problemfeld-/Phasenziel-Karte auf "+ [Ziel]" tippt.
  Future<void> addGoalContext(String supplementId, String goalName) async {
    state = state.map((e) {
      if (e.id != supplementId) return e;
      if (e.addedFromGoals.contains(goalName)) return e; // bereits vorhanden
      return e.copyWith(addedFromGoals: [...e.addedFromGoals, goalName]);
    }).toList();
    await _persist();
  }

  /// Hinzufügen mit Duplikat-Warnflag (wenn Nutzer "Beides behalten" wählt).
  Future<void> addWithDuplicateWarning(Supplement supplement) async {
    if (contains(supplement.id)) return;
    final entry = StackEntry.fromSupplement(supplement)
        .copyWith(hasDuplicateWarning: true);
    state = [...state, entry];
    await _persist();
  }

  Future<void> remove(String supplementId) async {
    state = state.where((e) => e.id != supplementId).toList();
    await _persist();
  }

  /// Mehrere Einträge auf einmal entfernen (Duplikat-Bereinigung).
  Future<void> removeMany(List<String> ids) async {
    state = state.where((e) => !ids.contains(e.id)).toList();
    await _persist();
  }

  /// Setzt hasDuplicateWarning=true für bestehende Einträge.
  Future<void> markDuplicateWarnings(List<String> ids) async {
    state = state
        .map((e) => ids.contains(e.id) ? e.copyWith(hasDuplicateWarning: true) : e)
        .toList();
    await _persist();
  }

  Future<void> clear() async {
    state = [];
    await _persist();
  }

  /// Fügt ein Supplement als temporären Phasenziel-Eintrag zum Stack hinzu.
  /// [goalContext] – Phasenziel-Name (z.B. "Marathon-Vorbereitung") für den Source-Badge.
  Future<void> addForPhaseGoal({
    required Supplement supplement,
    required String phaseGoalId,
    required DateTime endDate,
    String? goalContext,
  }) async {
    if (contains(supplement.id)) return;
    final base = StackEntry.fromSupplement(supplement);
    final entry = StackEntry(
      id: base.id,
      name: base.name,
      substanceName: base.substanceName,
      evidenceLevel: base.evidenceLevel,
      dosage: base.dosage,
      intakeTime: base.intakeTime,
      intakeSlot: base.intakeSlot,
      intakeHint: base.intakeHint,
      drugInteraction: base.drugInteraction,
      interactionSeverity: base.interactionSeverity,
      supplementType: base.supplementType,
      enthalteneWirkstoffe: base.enthalteneWirkstoffe,
      categories: base.categories,
      phaseGoalId: phaseGoalId,
      phaseEndDate: endDate,
      addedFromGoals: goalContext != null ? [goalContext] : const [],
      addedAt: DateTime.now(),
    );
    state = [...state, entry];
    await _persist();
  }

  /// Entfernt alle Stack-Einträge die zu einem bestimmten Phasenziel gehören.
  Future<void> removeByPhaseGoal(String phaseGoalId) async {
    state = state.where((e) => e.phaseGoalId != phaseGoalId).toList();
    await _persist();
  }

  /// Entfernt automatisch alle abgelaufenen Phasenziel-Supplements.
  /// Gibt die IDs der entfernten phaseGoalIds zurück.
  Future<List<String>> removeExpiredPhaseSupplements() async {
    final now = DateTime.now();
    final expired = state
        .where((e) => e.phaseEndDate != null && now.isAfter(e.phaseEndDate!))
        .map((e) => e.phaseGoalId!)
        .toSet()
        .toList();
    if (expired.isNotEmpty) {
      state = state
          .where((e) => e.phaseEndDate == null || !now.isAfter(e.phaseEndDate!))
          .toList();
      await _persist();
    }
    return expired;
  }

  /// Backdating für Simulation — setzt addedAt aller Einträge 14 Tage zurück.
  Future<void> backdateForSimulation() async {
    if (state.isEmpty) return;
    final baseDate = DateTime.now().subtract(const Duration(days: 14));
    state = state.map((e) => e.copyWith(addedAt: baseDate)).toList();
    await _persist();
  }

  // --- Duplikat-Erkennung ---

  /// Findet alle Stack-Einträge deren Wirkstoffe mit dem neuen Supplement überlappen.
  List<StackEntry> findDuplicates(Supplement supplement) {
    final newWirkstoffe = _wirkstoffeOf(supplement);
    return state.where((entry) {
      final entryWirkstoffe = _wirkstoffeOfEntry(entry);
      return newWirkstoffe.any((nw) =>
          entryWirkstoffe.any((ew) => _matches(nw, ew)));
    }).toList();
  }

  List<String> _wirkstoffeOf(Supplement s) {
    if (s.supplementType == SupplementType.group) {
      return s.enthalteneWirkstoffe.map((w) => w.toLowerCase()).toList();
    }
    return [
      s.name.toLowerCase(),
      if (s.substanceName != null) s.substanceName!.toLowerCase(),
    ];
  }

  List<String> _wirkstoffeOfEntry(StackEntry e) {
    if (e.supplementType == SupplementType.group) {
      return e.enthalteneWirkstoffe.map((w) => w.toLowerCase()).toList();
    }
    return [
      e.name.toLowerCase(),
      if (e.substanceName != null) e.substanceName!.toLowerCase(),
    ];
  }

  bool _matches(String a, String b) => a.toLowerCase() == b.toLowerCase();

  // --- Persistenz (nur über Repository-Interface) ---

  Future<void> _load() async {
    state = await _repository.getAll();
  }

  Future<void> _persist() async {
    await _repository.saveAll(state);
  }
}

final stackProvider = StateNotifierProvider<StackNotifier, List<StackEntry>>(
  (ref) => StackNotifier(ref.read(stackRepositoryProvider)),
);
