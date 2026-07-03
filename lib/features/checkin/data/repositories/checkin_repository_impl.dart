import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/checkin_entry.dart';
import '../../domain/repositories/checkin_repository.dart';

/// SharedPreferences-Implementierung von [CheckinRepository].
class SharedPreferencesCheckinRepository implements CheckinRepository {
  @override
  Future<List<CheckinEntry>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyCheckinHistory);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CheckinEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('CheckinRepository.getAll fehlgeschlagen: $e');
      return [];
    }
  }

  @override
  Future<void> saveAll(List<CheckinEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(AppConstants.keyCheckinHistory, encoded);
    } catch (e) {
      debugPrint('CheckinRepository.saveAll fehlgeschlagen: $e');
      throw const StorageFailure('Check-ins konnten nicht gespeichert werden.');
    }
  }
}
