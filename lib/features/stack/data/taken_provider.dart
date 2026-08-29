import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/day_key.dart';

/// Verwaltet wie viel von jedem Supplement an welchem Tag eingenommen wurde.
/// Key-Format: "supplementId_yyyy-MM-dd" (siehe dayKey()). Speichert eine
/// Menge statt nur ja/nein, damit der Kalender Teil-Einnahmen abbilden kann
/// (z.B. "0,3 von 1g genommen"). Für Einträge ohne strukturierte Dosis
/// (dosageAmount == null) bleibt es faktisch binär: [checkInFull] ohne
/// targetAmount schreibt den Sentinel 1.0, [isTaken] fragt nur ab ob
/// überhaupt ein Wert hinterlegt ist — bestehende Call-Sites (Heute-Screen)
/// bleiben dadurch unverändert lauffähig.
class TakenNotifier extends StateNotifier<Map<String, double>> {
  TakenNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'taken_supplements_v2';

  /// Wie viel wurde heute bereits genommen (in der Einheit von dosageUnit).
  double amountTaken(String supplementId, DateTime date) =>
      state[dayKey(supplementId, date)] ?? 0.0;

  /// Rein binär: wurde überhaupt etwas eingecheckt? Für Freitext-Einträge
  /// ohne strukturierte Dosis die einzig sinnvolle Frage.
  bool isTaken(String supplementId, DateTime date) =>
      state.containsKey(dayKey(supplementId, date));

  Future<void> setAmount(String supplementId, DateTime date, double amount) async {
    final key = dayKey(supplementId, date);
    final next = Map<String, double>.from(state);
    if (amount <= 0) {
      next.remove(key);
    } else {
      next[key] = amount;
    }
    state = next;
    await _save();
  }

  /// Komplett einchecken — nutzt targetAmount (strukturierte Dosis) falls
  /// vorhanden, sonst Sentinel 1.0 für reinen Freitext-Fall.
  Future<void> checkInFull(String supplementId, DateTime date, {double? targetAmount}) =>
      setAmount(supplementId, date, targetAmount ?? 1.0);

  Future<void> uncheck(String supplementId, DateTime date) =>
      setAmount(supplementId, date, 0);

  /// Umschalten: eingenommen → nicht eingenommen und umgekehrt. Bestehende
  /// Call-Sites ohne targetAmount verhalten sich weiter rein binär.
  Future<void> toggle(String supplementId, DateTime date, {double? targetAmount}) async {
    if (isTaken(supplementId, date)) {
      await uncheck(supplementId, date);
    } else {
      await checkInFull(supplementId, date, targetAmount: targetAmount);
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
        return;
      }
      // Migration von der alten rein-binären Speicherung (Set<String>-JSON-
      // Liste unter 'taken_supplements') — einmalig, danach nur noch v2.
      final legacyRaw = prefs.getString('taken_supplements');
      if (legacyRaw != null) {
        final list = jsonDecode(legacyRaw) as List<dynamic>;
        state = {for (final k in list.cast<String>()) k: 1.0};
        await _save();
      }
    } catch (_) {
      state = {};
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state));
  }
}

final takenProvider =
    StateNotifierProvider<TakenNotifier, Map<String, double>>(
  (ref) => TakenNotifier(),
);
