import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/recommendation_mode.dart';

const _prefsKey = 'recommendation_mode';

/// Persistiert den Empfehlungs-Modus (LLM vs. RAG-only) in SharedPreferences.
class RecommendationModeNotifier extends StateNotifier<RecommendationMode> {
  RecommendationModeNotifier() : super(RecommendationMode.llm) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == RecommendationMode.ragOnly.name) {
      state = RecommendationMode.ragOnly;
    }
  }

  Future<void> setMode(RecommendationMode mode) async {
    if (state == mode) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final recommendationModeProvider =
    StateNotifierProvider<RecommendationModeNotifier, RecommendationMode>(
  (ref) => RecommendationModeNotifier(),
);
