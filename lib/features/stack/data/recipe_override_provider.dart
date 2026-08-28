import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/day_key.dart';

enum RecipeOverrideAction { removed, reduced }

/// "Für heute aktivieren" — ein Supplement wird für den jeweiligen Tag als
/// (teilweise) durch ein Rezept abgedeckt markiert. Gilt NUR für diesen Tag:
/// dank des datumsbasierten Schlüssels (siehe dayKey()) ist der Stack am
/// nächsten Tag automatisch wieder normal, ganz ohne Extra-Logik — exakt wie
/// bei TakenNotifier.
class RecipeOverride {
  final RecipeOverrideAction action;
  /// Nur bei `reduced` befüllt — die berechnete neue Menge für heute.
  final double? reducedToAmount;
  final String? reducedToUnit;
  final String recipeTitle;

  const RecipeOverride({
    required this.action,
    this.reducedToAmount,
    this.reducedToUnit,
    required this.recipeTitle,
  });

  factory RecipeOverride.fromJson(Map<String, dynamic> json) => RecipeOverride(
        action: RecipeOverrideAction.values.byName(json['action'] as String),
        reducedToAmount: (json['reducedToAmount'] as num?)?.toDouble(),
        reducedToUnit: json['reducedToUnit'] as String?,
        recipeTitle: json['recipeTitle'] as String,
      );

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'reducedToAmount': reducedToAmount,
        'reducedToUnit': reducedToUnit,
        'recipeTitle': recipeTitle,
      };
}

class RecipeOverrideNotifier extends StateNotifier<Map<String, RecipeOverride>> {
  RecipeOverrideNotifier() : super({}) {
    _load();
  }

  static const _prefsKey = 'recipe_overrides_today';

  RecipeOverride? overrideFor(String supplementId, DateTime date) =>
      state[dayKey(supplementId, date)];

  Future<void> setOverride(String supplementId, DateTime date, RecipeOverride override) async {
    state = {...state, dayKey(supplementId, date): override};
    await _save();
  }

  Future<void> clearOverride(String supplementId, DateTime date) async {
    final next = Map<String, RecipeOverride>.from(state);
    next.remove(dayKey(supplementId, date));
    state = next;
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = map.map((k, v) => MapEntry(k, RecipeOverride.fromJson(v as Map<String, dynamic>)));
      }
    } catch (_) {
      state = {};
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_prefsKey, encoded);
  }
}

final recipeOverrideProvider =
    StateNotifierProvider<RecipeOverrideNotifier, Map<String, RecipeOverride>>(
  (ref) => RecipeOverrideNotifier(),
);
