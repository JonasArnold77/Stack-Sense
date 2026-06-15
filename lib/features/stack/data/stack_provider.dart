import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/stack_entry.dart';
import '../../recommendations/domain/models/supplement.dart';

/// Verwaltet den Supplement-Stack des Nutzers.
/// Persistiert automatisch in SharedPreferences bei jeder Änderung.
class StackNotifier extends StateNotifier<List<StackEntry>> {
  StackNotifier() : super([]) {
    _loadFromPrefs();
  }

  // --- Öffentliche API ---

  bool contains(String supplementId) =>
      state.any((e) => e.id == supplementId);

  /// Einfaches Hinzufügen ohne Duplikat-Check (intern / nach Dialog-Bestätigung).
  Future<void> add(Supplement supplement) async {
    if (contains(supplement.id)) return;
    final entry = StackEntry.fromSupplement(supplement);
    state = [...state, entry];
    await _saveToPrefs();
  }

  /// Hinzufügen mit Duplikat-Warnflag (wenn Nutzer "Beides behalten" wählt).
  Future<void> addWithDuplicateWarning(Supplement supplement) async {
    if (contains(supplement.id)) return;
    final entry = StackEntry.fromSupplement(supplement)
        .copyWith(hasDuplicateWarning: true);
    state = [...state, entry];
    await _saveToPrefs();
  }

  Future<void> remove(String supplementId) async {
    state = state.where((e) => e.id != supplementId).toList();
    await _saveToPrefs();
  }

  /// Mehrere Einträge auf einmal entfernen (Duplikat-Bereinigung).
  Future<void> removeMany(List<String> ids) async {
    state = state.where((e) => !ids.contains(e.id)).toList();
    await _saveToPrefs();
  }

  /// Setzt hasDuplicateWarning=true für bestehende Einträge (wenn "Beides behalten").
  Future<void> markDuplicateWarnings(List<String> ids) async {
    state = state
        .map((e) => ids.contains(e.id) ? e.copyWith(hasDuplicateWarning: true) : e)
        .toList();
    await _saveToPrefs();
  }

  Future<void> clear() async {
    state = [];
    await _saveToPrefs();
  }

  /// Fügt ein Supplement als temporären Phasenziel-Eintrag zum Stack hinzu.
  /// Das Supplement wird mit [phaseGoalId] und [endDate] markiert.
  Future<void> addForPhaseGoal({
    required Supplement supplement,
    required String phaseGoalId,
    required DateTime endDate,
  }) async {
    if (contains(supplement.id)) return;
    // fromSupplement baut den Basis-Entry; wir rekonstruieren ihn mit Phase-Feldern.
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
      addedAt: DateTime.now(),
    );
    state = [...state, entry];
    await _saveToPrefs();
  }

  /// Entfernt alle Stack-Einträge die zu einem bestimmten Phasenziel gehören.
  Future<void> removeByPhaseGoal(String phaseGoalId) async {
    state = state.where((e) => e.phaseGoalId != phaseGoalId).toList();
    await _saveToPrefs();
  }

  /// Entfernt automatisch alle abgelaufenen Phasenziel-Supplements.
  /// Gibt die IDs der entfernten phaseGoalIds zurück.
  Future<List<String>> removeExpiredPhaseSupplements() async {
    final now = DateTime.now();
    final expired = state
        .where((e) =>
            e.phaseEndDate != null && now.isAfter(e.phaseEndDate!))
        .map((e) => e.phaseGoalId!)
        .toSet()
        .toList();
    if (expired.isNotEmpty) {
      state = state
          .where((e) =>
              e.phaseEndDate == null || !now.isAfter(e.phaseEndDate!))
          .toList();
      await _saveToPrefs();
    }
    return expired;
  }

  /// Setzt addedAt aller Stack-Einträge auf ~14 Tage zurück.
  /// Wird für die Verlaufs-Simulation verwendet damit Korrelationen sichtbar werden.
  /// Die Supplements sind dann "in Woche 2" hinzugekommen — passend zur Simulationskurve.
  Future<void> backdateForSimulation() async {
    if (state.isEmpty) return;
    final baseDate = DateTime.now().subtract(const Duration(days: 14));
    state = state
        .map((e) => e.copyWith(addedAt: baseDate))
        .toList();
    await _saveToPrefs();
  }

  /// Alle Einträge für einen bestimmten Zeitslot
  List<StackEntry> forSlot(IntakeSlot slot) =>
      state.where((e) => e.intakeSlot == slot).toList();

  /// Findet alle Stack-Einträge deren Wirkstoffe mit dem neuen Supplement überlappen.
  ///
  /// Matching-Logik (case-insensitiv, substring):
  /// - Gruppen-Supplement: jedes Element in enthalteneWirkstoffe gegen bestehende Einträge
  /// - Einzel-Supplement: name/substanceName gegen enthalteneWirkstoffe aller Gruppen
  List<StackEntry> findDuplicates(Supplement supplement) {
    final newWirkstoffe = _wirkstoffeOf(supplement);
    return state.where((entry) {
      final entryWirkstoffe = _wirkstoffeOfEntry(entry);
      // Überlappung wenn mindestens ein Wirkstoff auf beiden Seiten matched
      return newWirkstoffe.any((nw) =>
          entryWirkstoffe.any((ew) => _matches(nw, ew)));
    }).toList();
  }

  // --- Hilfsmethoden für Duplikat-Erkennung ---

  /// Liefert alle Wirkstoffe eines Supplements (lowercase).
  List<String> _wirkstoffeOf(Supplement s) {
    if (s.supplementType == SupplementType.group) {
      return s.enthalteneWirkstoffe.map((w) => w.toLowerCase()).toList();
    }
    return [
      s.name.toLowerCase(),
      if (s.substanceName != null) s.substanceName!.toLowerCase(),
    ];
  }

  /// Liefert alle Wirkstoffe eines StackEntry (lowercase).
  List<String> _wirkstoffeOfEntry(StackEntry e) {
    if (e.supplementType == SupplementType.group) {
      return e.enthalteneWirkstoffe.map((w) => w.toLowerCase()).toList();
    }
    return [
      e.name.toLowerCase(),
      if (e.substanceName != null) e.substanceName!.toLowerCase(),
    ];
  }

  /// Exakter case-insensitiver Match auf den vollen Wirkstoff-Namen.
  /// Da wir eine Supplement-Datenbank mit standardisierten Bezeichnungen nutzen,
  /// reicht exakter Vergleich — keine Substring-Logik nötig.
  bool _matches(String a, String b) => a.toLowerCase() == b.toLowerCase();

  // --- Persistenz ---

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUserStack);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => StackEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Korrupte Daten ignorieren — Stack leer starten
      state = [];
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(AppConstants.keyUserStack, encoded);
  }
}

final stackProvider =
    StateNotifierProvider<StackNotifier, List<StackEntry>>(
  (ref) => StackNotifier(),
);
