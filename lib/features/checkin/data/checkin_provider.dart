import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/checkin_entry.dart';

/// Verwaltet alle Check-ins und Streak-Berechnung.
/// Persistiert automatisch in SharedPreferences.
class CheckinNotifier extends StateNotifier<List<CheckinEntry>> {
  CheckinNotifier() : super([]) {
    _loadFromPrefs();
  }

  // --- Öffentliche Abfragen ---

  /// Wurde heute bereits eingecheckt?
  bool get hasCheckedInToday {
    if (state.isEmpty) return false;
    final today = _today();
    return state.any((e) => e.dateOnly == today);
  }

  /// Heutiger Check-in (falls vorhanden)
  CheckinEntry? get todayEntry {
    final today = _today();
    try {
      return state.firstWhere((e) => e.dateOnly == today);
    } catch (_) {
      return null;
    }
  }

  /// Aktuelle Streak in Tagen (aufeinanderfolgende Tage mit Check-in)
  int get currentStreak {
    if (state.isEmpty) return 0;

    final sorted = [...state]
      ..sort((a, b) => b.dateOnly.compareTo(a.dateOnly));

    int streak = 0;
    DateTime expected = _today();

    for (final entry in sorted) {
      if (entry.dateOnly == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (entry.dateOnly.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }

  /// Letzten N Einträge chronologisch (neueste zuerst)
  List<CheckinEntry> recent({int count = 7}) {
    final sorted = [...state]
      ..sort((a, b) => b.dateOnly.compareTo(a.dateOnly));
    return sorted.take(count).toList();
  }

  // --- Mutationen ---

  /// Check-in für heute speichern. Überschreibt bestehenden falls vorhanden.
  Future<void> submit(CheckinEntry entry) async {
    final today = _today();
    // Alten heutigen Eintrag entfernen falls vorhanden
    final filtered = state.where((e) => e.dateOnly != today).toList();
    state = [...filtered, entry];
    await _saveToPrefs();
  }

  // --- Persistenz ---

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyCheckinHistory);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => CheckinEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(AppConstants.keyCheckinHistory, encoded);
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

final checkinProvider =
    StateNotifierProvider<CheckinNotifier, List<CheckinEntry>>(
  (ref) => CheckinNotifier(),
);
