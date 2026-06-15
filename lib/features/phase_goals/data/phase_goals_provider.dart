import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/phase_goal.dart';

/// Verwaltet alle aktiven Phasenziele des Nutzers.
/// Persistiert in SharedPreferences. Cleanup abgelaufener Ziele erfolgt
/// beim nächsten App-Start via [removeExpired].
class PhaseGoalsNotifier extends StateNotifier<List<ActivePhaseGoal>> {
  PhaseGoalsNotifier() : super([]) {
    _loadFromPrefs();
  }

  // --- Öffentliche API ---

  /// Aktiviert ein neues Phasenziel für [durationDays] Tage.
  /// Gibt die neue [ActivePhaseGoal] Instanz zurück.
  Future<ActivePhaseGoal> activate({
    required String definitionId,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: durationDays));
    final goal = ActivePhaseGoal(
      id: '${definitionId}_${now.millisecondsSinceEpoch}',
      definitionId: definitionId,
      startDate: start,
      endDate: end,
      supplementIds: const [],
    );
    state = [...state, goal];
    await _saveToPrefs();
    return goal;
  }

  /// Fügt Supplement-IDs zu einem aktiven Phasenziel hinzu.
  Future<void> addSupplementIds(String goalId, List<String> ids) async {
    state = state.map((g) {
      if (g.id != goalId) return g;
      final merged = {...g.supplementIds, ...ids}.toList();
      return g.withSupplementIds(merged);
    }).toList();
    await _saveToPrefs();
  }

  /// Beendet ein Phasenziel manuell (löscht es aus der Liste).
  /// Das Entfernen der zugehörigen Stack-Einträge muss der Aufrufer übernehmen.
  Future<void> deactivate(String goalId) async {
    state = state.where((g) => g.id != goalId).toList();
    await _saveToPrefs();
  }

  /// Entfernt alle abgelaufenen Phasenziele und gibt ihre IDs zurück,
  /// damit der Aufrufer die Stack-Supplements dazu entfernen kann.
  Future<List<String>> removeExpired() async {
    final expired =
        state.where((g) => g.isExpired).map((g) => g.id).toList();
    if (expired.isNotEmpty) {
      state = state.where((g) => !g.isExpired).toList();
      await _saveToPrefs();
    }
    return expired;
  }

  /// Gibt das aktive Phasenziel für eine [goalId] zurück, oder null.
  ActivePhaseGoal? find(String goalId) {
    try {
      return state.firstWhere((g) => g.id == goalId);
    } catch (_) {
      return null;
    }
  }

  bool get hasActive => state.isNotEmpty;

  // --- Persistenz ---

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyPhaseGoals);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => ActivePhaseGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.map((g) => g.toJson()).toList());
    await prefs.setString(AppConstants.keyPhaseGoals, encoded);
  }
}

final phaseGoalsProvider =
    StateNotifierProvider<PhaseGoalsNotifier, List<ActivePhaseGoal>>(
  (ref) => PhaseGoalsNotifier(),
);
