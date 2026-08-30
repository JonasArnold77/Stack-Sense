import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Merkt sich, für welche Stack-Einträge der Nutzer bestätigt hat, die
/// Wechselwirkungswarnung (moderate/high) mit einem Arzt besprochen zu haben.
/// Anders als TakenNotifier/RecipeOverrideNotifier NICHT tagesbasiert — eine
/// Arztrücksprache ist keine tägliche Handlung, die Bestätigung gilt
/// dauerhaft für diesen Stack-Eintrag (bis er entfernt und neu hinzugefügt
/// wird, was eine neue ID erzeugt und die Bestätigung dadurch natürlich
/// zurücksetzt).
class DoctorConsultationNotifier extends StateNotifier<Set<String>> {
  DoctorConsultationNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'doctor_consulted_supplement_ids';

  bool isConfirmed(String stackEntryId) => state.contains(stackEntryId);

  Future<void> confirm(String stackEntryId) async {
    if (state.contains(stackEntryId)) return;
    state = {...state, stackEntryId};
    await _save();
  }

  Future<void> clear(String stackEntryId) async {
    if (!state.contains(stackEntryId)) return;
    final next = Set<String>.from(state)..remove(stackEntryId);
    state = next;
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list.cast<String>().toSet();
      }
    } catch (_) {
      state = {};
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toList()));
  }
}

final doctorConsultationProvider =
    StateNotifierProvider<DoctorConsultationNotifier, Set<String>>(
  (ref) => DoctorConsultationNotifier(),
);
