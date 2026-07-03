import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/onboarding_repository.dart';

/// SharedPreferences-Implementierung von [OnboardingRepository].
class SharedPreferencesOnboardingRepository implements OnboardingRepository {
  @override
  Future<UserProfile?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUserProfile);
      if (raw == null) return null;
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('OnboardingRepository.getProfile fehlgeschlagen: $e');
      return null;
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.keyUserProfile, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('OnboardingRepository.saveProfile fehlgeschlagen: $e');
      throw const StorageFailure('Profil konnte nicht gespeichert werden.');
    }
  }

  @override
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  }

  @override
  Future<void> setOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyOnboardingComplete, true);
    } catch (e) {
      debugPrint('OnboardingRepository.setOnboardingComplete fehlgeschlagen: $e');
      throw const StorageFailure('Onboarding-Status konnte nicht gespeichert werden.');
    }
  }
}
