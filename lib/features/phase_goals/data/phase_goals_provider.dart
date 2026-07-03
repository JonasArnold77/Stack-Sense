import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/phase_goal.dart';
import '../domain/repositories/phase_goals_repository.dart';
import 'repositories/phase_goals_repository_impl.dart';

// ---------------------------------------------------------------------------
// Repository-Provider
// ---------------------------------------------------------------------------

final phaseGoalsRepositoryProvider = Provider<PhaseGoalsRepository>(
  (ref) => SharedPreferencesPhaseGoalsRepository(),
);

// ---------------------------------------------------------------------------
// StateNotifier — Business Logic für Phasenziele.
// ---------------------------------------------------------------------------

class PhaseGoalsNotifier extends StateNotifier<List<ActivePhaseGoal>> {
  final PhaseGoalsRepository _repository;

  PhaseGoalsNotifier(this._repository) : super([]) {
    _load();
  }

  // --- Öffentliche API ---

  /// Aktiviert ein neues Phasenziel für [durationDays] Tage.
  Future<ActivePhaseGoal> activate({
    required String definitionId,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final goal = ActivePhaseGoal(
      id: '${definitionId}_${now.millisecondsSinceEpoch}',
      definitionId: definitionId,
      startDate: start,
      endDate: start.add(Duration(days: durationDays)),
      supplementIds: const [],
    );
    state = [...state, goal];
    await _persist();
    return goal;
  }

  /// Fügt Supplement-IDs zu einem aktiven Phasenziel hinzu.
  Future<void> addSupplementIds(String goalId, List<String> ids) async {
    state = state.map((g) {
      if (g.id != goalId) return g;
      final merged = {...g.supplementIds, ...ids}.toList();
      return g.withSupplementIds(merged);
    }).toList();
    await _persist();
  }

  /// Beendet ein Phasenziel manuell.
  Future<void> deactivate(String goalId) async {
    state = state.where((g) => g.id != goalId).toList();
    await _persist();
  }

  /// Entfernt alle abgelaufenen Phasenziele und gibt ihre IDs zurück.
  Future<List<String>> removeExpired() async {
    final expired = state.where((g) => g.isExpired).map((g) => g.id).toList();
    if (expired.isNotEmpty) {
      state = state.where((g) => !g.isExpired).toList();
      await _persist();
    }
    return expired;
  }

  ActivePhaseGoal? find(String goalId) {
    try {
      return state.firstWhere((g) => g.id == goalId);
    } catch (_) {
      return null;
    }
  }

  bool get hasActive => state.isNotEmpty;

  // --- Persistenz (nur über Repository) ---

  Future<void> _load() async {
    state = await _repository.getAll();
  }

  Future<void> _persist() async {
    await _repository.saveAll(state);
  }
}

final phaseGoalsProvider = StateNotifierProvider<PhaseGoalsNotifier, List<ActivePhaseGoal>>(
  (ref) => PhaseGoalsNotifier(ref.read(phaseGoalsRepositoryProvider)),
);
