import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/phase_goal.dart';
import '../../domain/repositories/phase_goals_repository.dart';

/// SharedPreferences-Implementierung von [PhaseGoalsRepository].
class SharedPreferencesPhaseGoalsRepository implements PhaseGoalsRepository {
  @override
  Future<List<ActivePhaseGoal>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyPhaseGoals);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ActivePhaseGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('PhaseGoalsRepository.getAll fehlgeschlagen: $e');
      return [];
    }
  }

  @override
  Future<void> saveAll(List<ActivePhaseGoal> goals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(goals.map((g) => g.toJson()).toList());
      await prefs.setString(AppConstants.keyPhaseGoals, encoded);
    } catch (e) {
      debugPrint('PhaseGoalsRepository.saveAll fehlgeschlagen: $e');
      throw const StorageFailure('Phasenziele konnten nicht gespeichert werden.');
    }
  }
}
