import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/user_profile.dart';
import '../../../core/constants/app_constants.dart';

/// Riverpod StateNotifier — verwaltet das UserProfile während Onboarding.
/// Persistiert automatisch in SharedPreferences.
class OnboardingNotifier extends StateNotifier<UserProfile> {
  OnboardingNotifier() : super(const UserProfile());

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
