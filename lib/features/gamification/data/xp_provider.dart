import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/xp_level.dart';
import '../domain/repositories/xp_repository.dart';
import 'repositories/xp_repository_impl.dart';

// ---------------------------------------------------------------------------
// Repository-Provider
// ---------------------------------------------------------------------------

final xpRepositoryProvider = Provider<XpRepository>(
  (ref) => SharedPreferencesXpRepository(),
);

// ---------------------------------------------------------------------------
// StateNotifier — XP-Stand und Level-Berechnung.
// ---------------------------------------------------------------------------

class XpNotifier extends StateNotifier<int> {
  final XpRepository _repository;

  XpNotifier(this._repository) : super(0) {
    _load();
  }

  /// Aktueller XP-Stand als Level-Objekt
  XpLevel get xpLevel => XpLevel(state);

  /// XP hinzufügen und speichern
  Future<void> addXp(int amount) async {
    state = state + amount;
    await _repository.saveXp(state);
  }

  Future<void> _load() async {
    state = await _repository.getXp();
  }
}

final xpProvider = StateNotifierProvider<XpNotifier, int>(
  (ref) => XpNotifier(ref.read(xpRepositoryProvider)),
);

/// Convenience-Provider: gibt direkt das XpLevel-Objekt zurück
final xpLevelProvider = Provider<XpLevel>((ref) {
  final totalXp = ref.watch(xpProvider);
  return XpLevel(totalXp);
});
