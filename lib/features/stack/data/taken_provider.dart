import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verwaltet welche Supplements an welchen Tagen als "eingenommen" markiert wurden.
/// Key-Format: "supplementId_yyyy-MM-dd"
class TakenNotifier extends StateNotifier<Set<String>> {
  TakenNotifier() : super({}) {
    _load();
  }

  static String _key(String supplementId, DateTime date) =>
      '${supplementId}_${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool isTaken(String supplementId, DateTime date) =>
      state.contains(_key(supplementId, date));

  /// Umschalten: eingenommen → nicht eingenommen und umgekehrt.
  Future<void> toggle(String supplementId, DateTime date) async {
    final key = _key(supplementId, date);
    final next = Set<String>.from(state);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    state = next;
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('taken_supplements');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list.map((e) => e as String).toSet();
      }
    } catch (_) {
      state = {};
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'taken_supplements', jsonEncode(state.toList()));
  }
}

final takenProvider =
    StateNotifierProvider<TakenNotifier, Set<String>>(
  (ref) => TakenNotifier(),
);
