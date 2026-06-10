import 'dart:convert';
import 'dart:math';
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

  // --- Simulation ---

  /// Generiert 21 Tage simulierte Check-in-Daten.
  ///
  /// Verlauf pro Dimension:
  /// - Woche 1 (Tage 21–15): Startwerte 2.0–3.0, eher schlecht
  /// - Woche 2 (Tage 14–8):  Ergänzung kommt dazu, langsame Besserung
  /// - Woche 3 (Tage 7–0):   Deutliche Verbesserung Richtung 3.5–4.5
  ///
  /// [goalBoosts] — optional Map von Dimension auf Extra-Boost (z.B. {"sleep": 0.5})
  Future<void> simulateHistory({Map<String, double>? goalBoosts}) async {
    final rng = Random(42); // Seed = reproduzierbar
    final today = _today();
    final entries = <CheckinEntry>[];

    for (int daysAgo = 20; daysAgo >= 0; daysAgo--) {
      final date = today.subtract(Duration(days: daysAgo));

      // Fortschritt 0.0 (Tag 20, vor Supplements) → 1.0 (heute)
      final progress = (20 - daysAgo) / 20.0;

      // Ab Tag 14 (daysAgo <= 14) greifen die Supplements
      final supplementEffect = daysAgo <= 13 ? ((13 - daysAgo) / 13.0) : 0.0;

      double _simScore(double base, double target, {double boost = 0}) {
        // Linearer Anstieg von base → target mit natürlichem Rauschen
        final trend = base + (target - base) * supplementEffect + boost * supplementEffect;
        final noise = (rng.nextDouble() - 0.5) * 0.6; // ±0.3 Streuung
        return (trend + noise).clamp(1.0, 5.0);
      }

      final energyBoost = goalBoosts?['energy'] ?? 0;
      final sleepBoost = goalBoosts?['sleep'] ?? 0;
      final focusBoost = goalBoosts?['focus'] ?? 0;
      final moodBoost = goalBoosts?['mood'] ?? 0;

      entries.add(CheckinEntry(
        date: date,
        energy: _simScore(2.2, 3.8, boost: energyBoost).round().clamp(1, 5),
        sleep:  _simScore(2.0, 4.0, boost: sleepBoost).round().clamp(1, 5),
        focus:  _simScore(2.5, 3.6, boost: focusBoost).round().clamp(1, 5),
        mood:   _simScore(2.3, 3.9, boost: moodBoost).round().clamp(1, 5),
      ));
    }

    state = entries;
    await _saveToPrefs();
  }

  /// Löscht alle simulierten / echten Daten (Reset für Tests).
  Future<void> clearAll() async {
    state = [];
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
