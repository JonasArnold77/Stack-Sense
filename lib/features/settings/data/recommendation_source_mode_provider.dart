import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/recommendation_source_mode.dart';

const _prefsKey = 'recommendation_source_mode';

/// Persistiert den Modus (Live vs. Vorberechnet) in SharedPreferences.
class RecommendationSourceModeNotifier extends StateNotifier<RecommendationSourceMode> {
  RecommendationSourceModeNotifier() : super(RecommendationSourceMode.live) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == RecommendationSourceMode.precomputed.name) {
      state = RecommendationSourceMode.precomputed;
    }
  }

  Future<void> setMode(RecommendationSourceMode mode) async {
    if (state == mode) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final recommendationSourceModeProvider = StateNotifierProvider<
    RecommendationSourceModeNotifier, RecommendationSourceMode>(
  (ref) => RecommendationSourceModeNotifier(),
);
