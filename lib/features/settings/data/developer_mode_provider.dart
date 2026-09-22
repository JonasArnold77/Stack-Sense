import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'developer_mode_enabled';

/// Persistiert den Developer-Mode-Schalter in SharedPreferences. Blendet
/// interne Test-/Debug-Einstellungen (Datenbank-/KI-Modus, Cache-Modus,
/// Reset-Buttons, Backend-URL) aus, solange er aus ist — Standard für normale
/// Nutzer ist AUS.
class DeveloperModeNotifier extends StateNotifier<bool> {
  DeveloperModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}

final developerModeProvider =
    StateNotifierProvider<DeveloperModeNotifier, bool>(
  (ref) => DeveloperModeNotifier(),
);
