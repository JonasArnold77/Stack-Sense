import '../models/saved_recipe.dart';

/// Abstrakte Schnittstelle für Lese-/Schreibzugriff auf die persönliche
/// Rezept-Bibliothek. Rein lokal (kein Backend-Sync), exakt wie der Stack.
abstract class RecipeLibraryRepository {
  Future<List<SavedRecipe>> getAll();
  Future<void> saveAll(List<SavedRecipe> recipes);
}
