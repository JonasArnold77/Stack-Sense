/// Provider für problemfeld-spezifische Tages-Check-ins.
///
/// Architektur:
/// - Persistenz: SharedPreferences (offline-first, wie alle anderen Provider)
/// - Backend-Sync: Fire-and-forget via ApiService (nicht-kritisch)
/// - Aktive Problemfelder: abgeleitet aus Stack (addedFromGoals → Problemfeld-ID)

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';
import '../../stack/data/stack_provider.dart';
import '../../stack/domain/models/stack_entry.dart';
import '../domain/models/problem_checkin.dart';
import 'problem_checkin_questions.dart';

// ---------------------------------------------------------------------------
// Persistenz-Key
// ---------------------------------------------------------------------------

const _kPrefKey = 'problem_checkins_v1';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Alle gespeicherten Problemfeld-Check-ins, chronologisch (älteste zuerst).
final problemCheckinProvider =
    StateNotifierProvider<ProblemCheckinNotifier, List<ProblemCheckinEntry>>(
  (ref) => ProblemCheckinNotifier(ref),
);

// ---------------------------------------------------------------------------
// Abgeleitete Provider
// ---------------------------------------------------------------------------

/// Aktive Problemfelder — alle Felder für die mindestens ein Supplement
/// im Stack vorhanden ist (via addedFromGoals → kGoalLabelToProblemFieldId).
final activeProblemFieldsProvider = Provider<List<String>>((ref) {
  final stack = ref.watch(stackProvider);
  return _deriveActiveFields(stack);
});

/// Zusammenfassung des heutigen Check-in-Status pro aktivem Problemfeld.
final dailyCheckinSummaryProvider =
    Provider<List<ProblemFieldCheckinSummary>>((ref) {
  final activeFields = ref.watch(activeProblemFieldsProvider);
  final entries = ref.watch(problemCheckinProvider);
  final today = _dateOnly(DateTime.now());

  return activeFields.map((fieldId) {
    final todayEntry = entries.where((e) {
      return e.problemFieldId == fieldId && e.dateOnly == today;
    }).firstOrNull;

    if (todayEntry == null) {
      return ProblemFieldCheckinSummary(
        problemFieldId: fieldId,
        status: DailyCheckinStatus.pending,
      );
    }
    return ProblemFieldCheckinSummary(
      problemFieldId: fieldId,
      status: DailyCheckinStatus.completed,
      todayAvgScore: todayEntry.avgScore,
    );
  }).toList();
});

/// Anzahl noch ausstehender Check-ins für heute.
final pendingCheckinCountProvider = Provider<int>((ref) {
  return ref
      .watch(dailyCheckinSummaryProvider)
      .where((s) => s.status == DailyCheckinStatus.pending)
      .length;
});

/// Verlauf der letzten [days] Tage für ein bestimmtes Problemfeld.
/// Gibt eine Map<DateTime(dateOnly), double(avgScore)> zurück.
final problemCheckinHistoryProvider = Provider.family<
    Map<DateTime, double>,
    ({String fieldId, int days})>((ref, args) {
  final entries = ref.watch(problemCheckinProvider);
  final since = _dateOnly(
    DateTime.now().subtract(Duration(days: args.days)),
  );

  final result = <DateTime, double>{};
  for (final entry in entries) {
    if (entry.problemFieldId == args.fieldId &&
        !entry.dateOnly.isBefore(since)) {
      result[entry.dateOnly] = entry.avgScore;
    }
  }
  return result;
});

/// Verlauf pro Frage (question_id → Liste von (date, score)).
/// Für die 4-Minigraphen im Insights-Screen.
final problemCheckinPerQuestionProvider = Provider.family<
    Map<int, List<({DateTime date, int score})>>,
    ({String fieldId, int days})>((ref, args) {
  final entries = ref.watch(problemCheckinProvider);
  final since = _dateOnly(
    DateTime.now().subtract(Duration(days: args.days)),
  );

  final result = <int, List<({DateTime date, int score})>>{};

  // Fragen für dieses Feld initialisieren
  for (final q in getQuestionsForField(args.fieldId)) {
    result[q.id] = [];
  }

  for (final entry in entries) {
    if (entry.problemFieldId != args.fieldId) continue;
    if (entry.dateOnly.isBefore(since)) continue;
    for (final answer in entry.answers) {
      result.putIfAbsent(answer.questionId, () => []);
      result[answer.questionId]!.add((date: entry.dateOnly, score: answer.score));
    }
  }

  // Chronologisch sortieren
  for (final list in result.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }

  return result;
});

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class ProblemCheckinNotifier
    extends StateNotifier<List<ProblemCheckinEntry>> {
  final Ref _ref;

  ProblemCheckinNotifier(this._ref) : super([]) {
    _load();
  }

  // --- Öffentliche Abfragen ---

  /// Ob für das gegebene Problemfeld heute bereits eingecheckt wurde.
  bool hasCheckedInToday(String problemFieldId) {
    final today = _dateOnly(DateTime.now());
    return state.any(
      (e) => e.problemFieldId == problemFieldId && e.dateOnly == today,
    );
  }

  /// Heutiger Eintrag für ein Problemfeld (null wenn noch nicht vorhanden).
  ProblemCheckinEntry? todayEntry(String problemFieldId) {
    final today = _dateOnly(DateTime.now());
    try {
      return state.firstWhere(
        (e) => e.problemFieldId == problemFieldId && e.dateOnly == today,
      );
    } catch (_) {
      return null;
    }
  }

  // --- Mutationen ---

  /// Check-in für ein Problemfeld speichern.
  /// Überschreibt einen bestehenden Check-in für heute (Idempotent).
  Future<void> submit({
    required String problemFieldId,
    required List<ProblemCheckinAnswer> answers,
  }) async {
    final today = _dateOnly(DateTime.now());
    final entry = ProblemCheckinEntry(
      problemFieldId: problemFieldId,
      date: today,
      answers: answers,
    );

    // Bestehenden Eintrag für heute ersetzen (oder anhängen)
    final filtered = state
        .where((e) => !(e.problemFieldId == problemFieldId && e.dateOnly == today))
        .toList();
    state = [...filtered, entry];

    await _persist();
    _syncToBackend(entry);
  }

  Future<void> clearAll() async {
    state = [];
    await _persist();
  }

  // --- Backend-Sync (fire-and-forget) ---

  Future<void> _syncToBackend(ProblemCheckinEntry entry) async {
    // Nur Felder mit dedizierten Backend-Fragen syncen.
    // Felder mit generischen Fragen (negative IDs) bleiben rein lokal.
    if (!kBackendSyncedFields.contains(entry.problemFieldId)) return;
    if (entry.answers.any((a) => a.questionId < 0)) return;

    try {
      final deviceId = await _getOrCreateDeviceId();
      await ApiService.instance.submitProblemCheckin(
        deviceId: deviceId,
        problemFieldId: entry.problemFieldId,
        date: entry.date,
        answers: entry.answers
            .map((a) => {'question_id': a.questionId, 'score': a.score})
            .toList(),
      );
    } catch (_) {
      // Nicht-kritisch: lokale Daten sind primär, Backend ist Bonus.
    }
  }

  // --- Persistenz ---

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) =>
              ProblemCheckinEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_kPrefKey, raw);
    } catch (_) {}
  }

  Future<String> _getOrCreateDeviceId() async {
    const key = 'device_id';
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(key);
    if (id == null) {
      id = _generateUuid();
      await prefs.setString(key, id);
    }
    return id;
  }

  String _generateUuid() {
    // Einfaches UUID v4 ohne externe Library
    const chars = 'abcdef0123456789';
    String seg(int n) => List.generate(n, (_) {
          final idx = DateTime.now().microsecondsSinceEpoch % chars.length;
          return chars[idx];
        }).join();
    return '${seg(8)}-${seg(4)}-${seg(4)}-${seg(4)}-${seg(12)}';
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Leitet aktive Problemfelder aus den Stack-Einträgen ab.
/// Iteriert über alle addedFromGoals-Werte und mapped sie via
/// kGoalLabelToProblemFieldId auf Problemfeld-IDs.
List<String> _deriveActiveFields(List<StackEntry> stack) {
  final fields = <String>{};
  for (final entry in stack) {
    for (final goalLabel in entry.addedFromGoals) {
      final fieldId = kGoalLabelToProblemFieldId[goalLabel];
      if (fieldId != null) fields.add(fieldId);
    }
    // goalIds ebenfalls prüfen (direktes Ziel-Label als ID gespeichert)
    for (final goalId in entry.goalIds) {
      final fieldId = kGoalLabelToProblemFieldId[goalId];
      if (fieldId != null) fields.add(fieldId);
    }
  }
  // Stabile Reihenfolge über alle bekannten Felder.
  // Neue Einträge am Ende anhängen — bestehende Reihenfolge nicht ändern.
  const order = [
    'Schlaf', 'Energie', 'Fokus', 'Stimmung',
    'Sport', 'Immunsystem', 'Verdauung', 'Frauengesundheit',
    // Felder mit generischen Fragen (lokal, kein Backend-Sync):
    'Herzgesundheit', 'Haut', 'Gewicht', 'Gelenke', 'Hormone', 'Basis',
  ];
  // Felder die noch nicht in `order` stehen (unbekannte Goals) am Ende anhängen
  final ordered = order.where(fields.contains).toList();
  for (final f in fields) {
    if (!ordered.contains(f)) ordered.add(f);
  }
  return ordered;
}
