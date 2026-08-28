import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/recipe_library_provider.dart';
import '../../domain/models/generated_recipe.dart';
import '../widgets/recipe_card.dart';

/// Ergebnis-Screen — zeigt die 3-5 gerade generierten Rezepte. Rein flüchtig
/// (kein State außer dem, was übergeben wurde) — erst "Speichern" legt ein
/// Rezept dauerhaft in der Bibliothek ab.
class RecipeResultsScreen extends ConsumerWidget {
  final List<GeneratedRecipe> recipes;

  const RecipeResultsScreen({super.key, required this.recipes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Deine Rezepte'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: recipes.isEmpty
            ? const Center(child: Text('Keine Rezepte gefunden.'))
            : ListView(
                padding: const EdgeInsets.all(AppConstants.screenPaddingH),
                children: recipes
                    .map((r) => RecipeCard(recipe: r, trailing: _SaveButton(recipe: r)))
                    .toList(),
              ),
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  final GeneratedRecipe recipe;

  const _SaveButton({required this.recipe});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(recipeLibraryProvider.notifier).save(recipe);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rezept in Bibliothek gespeichert'),
          action: SnackBarAction(
            label: 'Anzeigen',
            onPressed: () => context.go(AppRoutes.recipes),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(recipeLibraryProvider);
    final isSaved = library.any((r) => r.recipe.id == recipe.id);

    return FilledButton.tonalIcon(
      onPressed: isSaved ? null : () => _save(context, ref),
      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline, size: 18),
      label: Text(isSaved ? 'Gespeichert' : 'Speichern'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}
