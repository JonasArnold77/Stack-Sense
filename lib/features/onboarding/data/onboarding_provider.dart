import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/lifestyle_options.dart';
import '../domain/models/user_profile.dart';
import '../../../core/constants/app_constants.dart';

/// Riverpod StateNotifier — verwaltet das UserProfile während Onboarding.
/// Persistiert automatisch in SharedPreferences.
class OnboardingNotifier extends StateNotifier<UserProfile> {
  OnboardingNotifier() : super(const UserProfile()) {
    _load();
  }

  /// Beim Erzeugen des Providers (App-Start) das gespeicherte Profil laden —
  /// ohne diesen Aufruf blieb loadFromPrefs() bisher komplett ungenutzt und
  /// jeder App-Start begann mit einem leeren Profil, obwohl längst eines
  /// gespeichert war (onboardingCompletedAt dadurch immer null → App
  /// verlangte bei jedem Start erneut das komplette Onboarding).
  Future<void> _load() async {
    final saved = await loadFromPrefs();
    if (saved != null) state = saved;
  }

  // Profil schrittweise aufbauen
  void updateAge(int age) => state = state.copyWith(age: age);
  void updateGender(Gender gender) => state = state.copyWith(gender: gender);
  void updateSportLevel(SportLevel level) =>
      state = state.copyWith(sportLevel: level);

  void toggleCondition(String condition) {
    final updated = List<String>.from(state.conditions);
    if (updated.contains(condition)) {
      updated.remove(condition);
    } else {
      updated.add(condition);
    }
    state = state.copyWith(conditions: updated);
  }

  /// Essgewohnheit / Alltag an- oder abwählen (Mehrfachauswahl).
  void toggleLifestyle(String item) {
    final updated = List<String>.from(state.lifestyle);
    if (updated.contains(item)) {
      updated.remove(item);
    } else {
      updated.add(item);
    }
    state = state.copyWith(lifestyle: updated);
  }

  /// Ernährungsform setzen — ersetzt eine vorher gewählte; nochmal tippen
  /// auf dieselbe hebt die Auswahl auf.
  void setDiet(String diet) {
    final had = state.lifestyle.contains(diet);
    final updated = state.lifestyle
        .where((e) => !kDietOptions.contains(e))
        .toList();
    if (!had) updated.insert(0, diet);
    state = state.copyWith(lifestyle: updated);
  }

  void updateMedications(List<String> meds) =>
      state = state.copyWith(medications: meds);

  void toggleGoal(String goal) {
    final updated = List<String>.from(state.goals);
    if (updated.contains(goal)) {
      updated.remove(goal);
    } else {
      updated.add(goal);
    }
    state = state.copyWith(goals: updated);
  }

  void setIsPregnant(bool value) =>
      state = state.copyWith(isPregnant: value);

  /// Onboarding abschließen — Profil speichern
  Future<void> completeOnboarding() async {
    final completed = state.copyWith(
      onboardingCompletedAt: DateTime.now(),
    );
    state = completed;
    await _saveToPrefs(completed);
  }

  Future<void> _saveToPrefs(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyUserProfile,
      jsonEncode(profile.toJson()),
    );
    await prefs.setBool(AppConstants.keyOnboardingComplete, true);
  }

  /// Setzt das Profil komplett zurück (Alter, Geschlecht, Erkrankungen,
  /// Ziele, ...) und löscht den gespeicherten Stand — damit der Nutzer das
  /// Onboarding bewusst noch einmal von vorne durchlaufen kann.
  Future<void> resetProfile() async {
    state = const UserProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUserProfile);
    await prefs.remove(AppConstants.keyOnboardingComplete);
  }

  /// Gespeichertes Profil laden (beim App-Start)
  static Future<UserProfile?> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.keyUserProfile);
    if (json == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, UserProfile>(
  (ref) => OnboardingNotifier(),
);
