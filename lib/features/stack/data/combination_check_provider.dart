import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stack_provider.dart';
import '../domain/models/stack_entry.dart';

/// Ab wie vielen gleichzeitig aktiven Supplements der "Kombination checken
/// lassen"-Hinweis erscheint.
const int kCombinationCheckThreshold = 8;

/// Stabile "Signatur" der aktuellen Stack-Zusammensetzung (sortierte IDs) —
/// ändert sich bei jedem Hinzufügen/Entfernen, aber NICHT bei bloßem Neuladen
/// derselben Einträge. Damit lässt sich "wurde für GENAU diese Zusammen-
/// setzung schon geprüft/weggewischt?" zuverlässig beantworten.
String stackSignature(List<StackEntry> stack) =>
    (stack.map((e) => e.id).toList()..sort()).join(',');

/// Merkt sich die zuletzt "erledigte" (geprüft ODER weggewischt) Stack-
/// Signatur — der Hinweis erscheint erst wieder, wenn sich die Zusammen-
/// setzung seitdem geändert hat (nicht bei jedem Öffnen des Screens erneut).
class CombinationCheckPromptNotifier extends StateNotifier<String?> {
  CombinationCheckPromptNotifier() : super(null) {
    _load();
  }

  static const _prefsKey = 'combination_check_last_handled_signature';

  Future<void> markHandled(String signature) async {
    state = signature;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, signature);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_prefsKey);
    } catch (_) {
      state = null;
    }
  }
}

final combinationCheckPromptProvider =
    StateNotifierProvider<CombinationCheckPromptNotifier, String?>(
  (ref) => CombinationCheckPromptNotifier(),
);

/// Ob der Hinweis gerade angezeigt werden soll: Stack-Größe über der
/// Schwelle UND die aktuelle Zusammensetzung wurde noch nicht gecheckt/
/// weggewischt.
final shouldShowCombinationCheckPromptProvider = Provider<bool>((ref) {
  final stack = ref.watch(stackProvider);
  if (stack.length < kCombinationCheckThreshold) return false;
  final handledSignature = ref.watch(combinationCheckPromptProvider);
  return handledSignature != stackSignature(stack);
});
