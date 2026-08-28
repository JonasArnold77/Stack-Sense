import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_screen_header.dart';
import '../../data/recipe_library_provider.dart';
import '../../domain/models/saved_recipe.dart';
import '../widgets/recipe_card.dart';

/// Rezepte-Tab — persönliche Bibliothek gespeicherter Rezepte + Einstieg in
/// die Generierung. Ersetzt den Phase-A-Platzhalter.
class RecipeLibraryScreen extends ConsumerStatefulWidget {
  const RecipeLibraryScreen({super.key});

  @override
  ConsumerState<RecipeLibraryScreen> createState() => _RecipeLibraryScreenState();
}

class _RecipeLibraryScreenState extends ConsumerState<RecipeLibraryScreen> {
  bool _onlyFavorites = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(recipeLibraryProvider);
    final visible = _onlyFavorites ? library.where((r) => r.isFavorite).toList() : library;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientScreenHeader(
            title: 'Rezepte',
            subtitle: 'Personalisierte Rezepte für deinen Stack',
            actions: [
              IconButton(
                icon: Icon(
                  _onlyFavorites ? Icons.star : Icons.star_outline,
                  color: Colors.white,
                ),
                tooltip: 'Nur Favoriten',
                onPressed: () => setState(() => _onlyFavorites = !_onlyFavorites),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.screenPaddingH),
            child: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.recipeFilter),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Neue Rezepte generieren'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spaceXL),
                      child: Text(
                        _onlyFavorites
                            ? 'Noch keine Favoriten.'
                            : 'Noch keine Rezepte gespeichert.\nGeneriere dein erstes Rezept oben.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.screenPaddingH,
                      0,
                      AppConstants.screenPaddingH,
                      AppConstants.screenPaddingH,
                    ),
                    children: visible
                        .map((saved) => RecipeCard(
                              recipe: saved.recipe,
                              trailing: _LibraryActions(saved: saved),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LibraryActions extends ConsumerWidget {
  final SavedRecipe saved;

  const _LibraryActions({required this.saved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            saved.isFavorite ? Icons.star : Icons.star_outline,
            color: saved.isFavorite ? const Color(0xFFF4B400) : AppColors.textTertiary,
          ),
          tooltip: 'Favorisieren',
          onPressed: () =>
              ref.read(recipeLibraryProvider.notifier).toggleFavorite(saved.recipe.id),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary),
          tooltip: 'Löschen',
          onPressed: () => ref.read(recipeLibraryProvider.notifier).delete(saved.recipe.id),
        ),
        FilledButton.tonal(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bald verfügbar')),
          ),
          child: const Text('Für heute'),
        ),
      ],
    );
  }
}
