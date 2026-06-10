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

  /// Case-insensitiver Substring-Match in beide Richtungen.
  bool _matches(String a, String b) =>
      a.contains(b) || b.contains(a);

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
