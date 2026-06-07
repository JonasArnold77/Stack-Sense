import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/xp_level.dart';

/// Verwaltet den gesamten XP-Stand des Nutzers.
/// Persistiert in SharedPreferences.
class XpNotifier extends StateNotifier<int> {
  XpNotifier() : super(0) {
    _load();
  }

  /// Aktueller XP-Stand als Level-Objekt
  XpLevel get xpLevel => XpLevel(state);

  /// XP hinzufügen und speichern
  Future<void> addXp(int amount) async {
    state = state + amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyUserXp, state);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(AppConstants.keyUserXp) ?? 0;
  }
}

final xpProvider = StateNotifierProvider<XpNotifier, int>(
  (ref) => XpNotifier(),
);

/// Convenience-Provider: gibt direkt das XpLevel-Objekt zurück
final xpLevelProvider = Provider<XpLevel>((ref) {
  final totalXp = ref.watch(xpProvider);
  return XpLevel(totalXp);
});
