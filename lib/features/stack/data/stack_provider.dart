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

  Future<void> add(Supplement supplement) async {
    if (contains(supplement.id)) return;
    final entry = StackEntry.fromSupplement(supplement);
    state = [...state, entry];
    await _saveToPrefs();
  }

  Future<void> remove(String supplementId) async {
    state = state.where((e) => e.id != supplementId).toList();
    await _saveToPrefs();
  }

  Future<void> clear() async {
    state = [];
    await _saveToPrefs();
  }

  /// Alle Einträge für einen bestimmten Zeitslot
  List<StackEntry> forSlot(IntakeSlot slot) =>
      state.where((e) => e.intakeSlot == slot).toList();

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
