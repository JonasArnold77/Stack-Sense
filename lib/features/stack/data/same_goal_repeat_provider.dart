import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/stack_entry.dart';
import 'stack_provider.dart';

/// Ab wie vielen Supplements für DASSELBE Problemfeld/Phasenziel der
/// "erst auf Wirkung warten"-Hinweis erscheint. "Basissupplementierung" zählt
/// bewusst nicht als Problemfeld/Phasenziel (siehe _isGoalEligible) — das ist
/// die generische Basis, kein spezifisches Ziel, für das man "abwarten" würde.
const int kSameGoalRepeatThreshold = 2;

bool _isGoalEligible(String goal) => goal != 'Basissupplementierung';

/// Ein Problemfeld/Phasenziel, für das die Schwelle aktuell erreicht ist.
class SameGoalRepeat {
  final String goal;
  final int count;
  final String signature; // sortierte IDs der betroffenen Einträge
  const SameGoalRepeat({required this.goal, required this.count, required this.signature});
}

List<SameGoalRepeat> _computeRepeats(List<StackEntry> stack) {
  final byGoal = <String, List<String>>{};
  for (final e in stack) {
    for (final g in e.addedFromGoals) {
      if (!_isGoalEligible(g)) continue;
      byGoal.putIfAbsent(g, () => []).add(e.id);
    }
  }
  final result = <SameGoalRepeat>[];
  byGoal.forEach((goal, ids) {
    if (ids.length < kSameGoalRepeatThreshold) return;
    final sorted = [...ids]..sort();
    result.add(SameGoalRepeat(goal: goal, count: ids.length, signature: sorted.join(',')));
  });
  return result;
}

/// Merkt sich pro Problemfeld/Phasenziel die zuletzt "erledigte" (gesehen ODER
/// weggewischt) Signatur — analog zu CombinationCheckPromptNotifier, nur pro
/// Ziel statt für den gesamten Stack.
class SameGoalRepeatNotifier extends StateNotifier<Map<String, String>> {
  SameGoalRepeatNotifier() : super(const {}) {
    _load();
  }

  static const _prefsKey = 'same_goal_repeat_handled';

  Future<void> markHandled(String goal, String signature) async {
    state = {...state, goal: signature};
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        state = Map<String, String>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {
      state = const {};
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }
}

final sameGoalRepeatHandledProvider =
    StateNotifierProvider<SameGoalRepeatNotifier, Map<String, String>>(
  (ref) => SameGoalRepeatNotifier(),
);

/// Alle Problemfelder/Phasenziele, die JETZT die Schwelle erreichen und deren
/// aktuelle Zusammensetzung noch nicht behandelt (gesehen/weggewischt) wurde.
final pendingSameGoalRepeatsProvider = Provider<List<SameGoalRepeat>>((ref) {
  final stack = ref.watch(stackProvider);
  final handled = ref.watch(sameGoalRepeatHandledProvider);
  return _computeRepeats(stack).where((r) => handled[r.goal] != r.signature).toList();
});
