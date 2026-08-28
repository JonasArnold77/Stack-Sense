import 'generated_recipe.dart';

/// Ein vom Nutzer gespeichertes Rezept in der persönlichen Bibliothek.
class SavedRecipe {
  final GeneratedRecipe recipe;
  final bool isFavorite;
  final DateTime savedAt;

  const SavedRecipe({
    required this.recipe,
    this.isFavorite = false,
    required this.savedAt,
  });

  SavedRecipe copyWith({bool? isFavorite}) => SavedRecipe(
        recipe: recipe,
        isFavorite: isFavorite ?? this.isFavorite,
        savedAt: savedAt,
      );

  factory SavedRecipe.fromJson(Map<String, dynamic> json) => SavedRecipe(
        recipe: GeneratedRecipe.fromJson(json['recipe'] as Map<String, dynamic>),
        isFavorite: json['isFavorite'] as bool? ?? false,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'recipe': recipe.toJson(),
        'isFavorite': isFavorite,
        'savedAt': savedAt.toIso8601String(),
      };
}
