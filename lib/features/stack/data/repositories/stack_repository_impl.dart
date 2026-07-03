import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/stack_entry.dart';
import '../../domain/repositories/stack_repository.dart';

/// SharedPreferences-Implementierung von [StackRepository].
///
/// Ist die einzige Klasse die weiß wie und wo der Stack gespeichert wird.
/// Provider und Notifier kennen nur das abstrakte Interface.
class SharedPreferencesStackRepository implements StackRepository {
  @override
  Future<List<StackEntry>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUserStack);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StackEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Korrupte Daten — Stack leer starten, Fehler loggen
      debugPrint('StackRepository.getAll fehlgeschlagen: $e');
      return [];
    }
  }

  @override
  Future<void> saveAll(List<StackEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(AppConstants.keyUserStack, encoded);
    } catch (e) {
      debugPrint('StackRepository.saveAll fehlgeschlagen: $e');
      throw const StorageFailure('Stack konnte nicht gespeichert werden.');
    }
  }
}
