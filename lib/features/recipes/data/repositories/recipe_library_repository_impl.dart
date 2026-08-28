import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/saved_recipe.dart';
import '../../domain/repositories/recipe_library_repository.dart';

/// SharedPreferences-Implementierung von [RecipeLibraryRepository] — exaktes
/// Muster von SharedPreferencesStackRepository (ganze Liste als ein JSON-Blob).
class SharedPreferencesRecipeLibraryRepository implements RecipeLibraryRepository {
  @override
  Future<List<SavedRecipe>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyRecipeLibrary);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('RecipeLibraryRepository.getAll fehlgeschlagen: $e');
      return [];
    }
  }

  @override
  Future<void> saveAll(List<SavedRecipe> recipes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(recipes.map((r) => r.toJson()).toList());
      await prefs.setString(AppConstants.keyRecipeLibrary, encoded);
    } catch (e) {
      debugPrint('RecipeLibraryRepository.saveAll fehlgeschlagen: $e');
      throw const StorageFailure('Rezept-Bibliothek konnte nicht gespeichert werden.');
    }
  }
}
