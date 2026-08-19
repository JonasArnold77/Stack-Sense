import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../domain/models/checkin_entry.dart';
import '../domain/repositories/checkin_repository.dart';
import 'repositories/checkin_repository_impl.dart';

// ---------------------------------------------------------------------------
// Repository-Provider
// ---------------------------------------------------------------------------

final checkinRepositoryProvider = Provider<CheckinRepository>(
  (ref) => SharedPreferencesCheckinRepository(),
);

// ---------------------------------------------------------------------------
// StateNotifier — Business Logic für Check-ins und Streak.
// Persistenz läuft ausschließlich über CheckinRepository.
// ---------------------------------------------------------------------------

class CheckinNotifier extends StateNotifier<List<CheckinEntry>> {
  final CheckinRepository _repository;

  CheckinNotifier(this._repository) : super([]) {
    _load();
  }

  // --- Öffentliche Abfragen ---

  /// Wurde heute bereits eingecheckt?
  bool get hasCheckedInToday {
    if (state.isEmpty) return false;
    return state.any((e) => e.dateOnly == _today());
  }

  /// Heutiger Check-in (falls vorhanden)
  CheckinEntry? get todayEntry {
    try {
      return state.firstWhere((e) => e.dateOnly == _today());
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
  Future<void> submit(CheckinEntry entry, {List<String> supplementNames = const []}) async {
    final today = _today();
    final filtered = state.where((e) => e.dateOnly != today).toList();
    state = [...filtered, entry];
    await _persist();
    // Anonym ans Backend senden (nicht-blockierend, scheitert still)
    _syncToBackend(entry, supplementNames);
  }

  Future<void> clearAll() async {
    state = [];
    await _persist();
  }

  // --- Community-Backend-Sync (anonym, nicht-kritisch) ---

  Future<void> _syncToBackend(CheckinEntry entry, List<String> supplementNames) async {
    if (supplementNames.isEmpty) return;
    try {
      final deviceId = await _getOrCreateDeviceId();
      final dateStr = _formatDate(entry.date);
      await ApiService.instance.syncCheckin(
        deviceId: deviceId,
        checkinDate: dateStr,
        sleep: entry.sleep,
        energy: entry.energy,
        focus: entry.focus,
        mood: entry.mood,
        supplementNames: supplementNames,
      );
    } catch (_) {
      // Nicht-kritisch — Community-Feature darf still scheitern
    }
  }

  Future<void> syncAllToBackend(List<String> supplementNames) async {
    if (state.isEmpty || supplementNames.isEmpty) return;
    try {
      final deviceId = await _getOrCreateDeviceId();
      for (final entry in state) {
        await ApiService.instance.syncCheckin(
          deviceId: deviceId,
          checkinDate: _formatDate(entry.date),
          sleep: entry.sleep,
          energy: entry.energy,
          focus: entry.focus,
          mood: entry.mood,
          supplementNames: supplementNames,
        );
      }
    } catch (_) {}
  }

  // --- Simulation ---

  /// Generiert 21 Tage simulierte Check-in-Daten für Demo-Zwecke.
  Future<void> simulateHistory({Map<String, double>? goalBoosts}) async {
    final rng = Random(42);
    final today = _today();
    final entries = <CheckinEntry>[];

    for (int daysAgo = 20; daysAgo >= 1; daysAgo--) {
      final date = today.subtract(Duration(days: daysAgo));
      final supplementEffect = daysAgo <= 13 ? ((13 - daysAgo) / 13.0) : 0.0;

      double simScore(double base, double target, {double boost = 0}) {
        final trend = base + (target - base) * supplementEffect + boost * supplementEffect;
        final noise = (rng.nextDouble() - 0.5) * 0.6;
        return (trend + noise).clamp(1.0, 5.0);
      }

      entries.add(CheckinEntry(
        date: date,
        energy: simScore(2.2, 3.8, boost: goalBoosts?['energy'] ?? 0).round().clamp(1, 5),
        sleep:  simScore(2.0, 4.0, boost: goalBoosts?['sleep']  ?? 0).round().clamp(1, 5),
        focus:  simScore(2.5, 3.6, boost: goalBoosts?['focus']  ?? 0).round().clamp(1, 5),
        mood:   simScore(2.3, 3.9, boost: goalBoosts?['mood']   ?? 0).round().clamp(1, 5),
      ));
    }

    state = entries;
    await _persist();
  }

  // --- Hilfsmethoden ---

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(AppConstants.keyDeviceId);
    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await prefs.setString(AppConstants.keyDeviceId, deviceId);
    }
    return deviceId;
  }

  String _generateDeviceId() {
    const chars = 'abcdef0123456789';
    final rng = Random.secure();
    String segment(int len) =>
        List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${segment(8)}-${segment(4)}-${segment(4)}-${segment(4)}-${segment(12)}';
  }

  // --- Persistenz (nur über Repository) ---

  Future<void> _load() async {
    state = await _repository.getAll();
  }

  Future<void> _persist() async {
    await _repository.saveAll(state);
  }
}

final checkinProvider = StateNotifierProvider<CheckinNotifier, List<CheckinEntry>>(
  (ref) => CheckinNotifier(ref.read(checkinRepositoryProvider)),
);
