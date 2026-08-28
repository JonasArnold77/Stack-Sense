import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/generated_recipe.dart';
import '../domain/models/saved_recipe.dart';
import '../domain/repositories/recipe_library_repository.dart';
import 'repositories/recipe_library_repository_impl.dart';

final recipeLibraryRepositoryProvider = Provider<RecipeLibraryRepository>(
  (ref) => SharedPreferencesRecipeLibraryRepository(),
);

/// Business-Logik für die persönliche Rezept-Bibliothek — rein lokal
/// (kein Backend-Sync), exaktes Muster von StackNotifier.
class RecipeLibraryNotifier extends StateNotifier<List<SavedRecipe>> {
  final RecipeLibraryRepository _repository;

  RecipeLibraryNotifier(this._repository) : super([]) {
    _load();
  }

  bool isSaved(String recipeId) => state.any((r) => r.recipe.id == recipeId);

  Future<void> save(GeneratedRecipe recipe) async {
    if (isSaved(recipe.id)) return;
    state = [...state, SavedRecipe(recipe: recipe, savedAt: DateTime.now())];
    await _persist();
  }

  Future<void> delete(String recipeId) async {
    state = state.where((r) => r.recipe.id != recipeId).toList();
    await _persist();
  }

  Future<void> toggleFavorite(String recipeId) async {
    state = state
        .map((r) => r.recipe.id == recipeId ? r.copyWith(isFavorite: !r.isFavorite) : r)
        .toList();
    await _persist();
  }

  Future<void> _load() async {
    state = await _repository.getAll();
  }

  Future<void> _persist() async {
    await _repository.saveAll(state);
  }
}

final recipeLibraryProvider =
    StateNotifierProvider<RecipeLibraryNotifier, List<SavedRecipe>>(
  (ref) => RecipeLibraryNotifier(ref.read(recipeLibraryRepositoryProvider)),
);
