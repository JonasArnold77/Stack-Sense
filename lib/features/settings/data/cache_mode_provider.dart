import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/cache_mode.dart';

const _prefsKey = 'cache_mode';

/// Persistiert den Cache-Testmodus in SharedPreferences.
class CacheModeNotifier extends StateNotifier<CacheMode> {
  CacheModeNotifier() : super(CacheMode.cached) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == CacheMode.noCache.name) {
      state = CacheMode.noCache;
    }
  }

  Future<void> setMode(CacheMode mode) async {
    if (state == mode) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final cacheModeProvider = StateNotifierProvider<CacheModeNotifier, CacheMode>(
  (ref) => CacheModeNotifier(),
);
