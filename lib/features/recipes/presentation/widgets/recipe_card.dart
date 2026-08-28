import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/generated_recipe.dart';

/// Rezept-Karte — zeigt Titel/Kochzeit/Zutaten/Schritte (einklappbar) und
/// Nährstoff-Übersicht. [trailing] hängt vom Kontext ab: Speichern-Button auf
/// dem Ergebnis-Screen, Favorisieren/Löschen/Aktivieren in der Bibliothek.
class RecipeCard extends StatefulWidget {
  final GeneratedRecipe recipe;
  final Widget? trailing;

  const RecipeCard({super.key, required this.recipe, this.trailing});

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _stepsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final nutrientEntries = recipe.nutrientOverview.entries
        .where((e) => kNutrientDisplay.containsKey(e.key) && e.value > 0)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(recipe.title,
                    style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('${recipe.cookTimeMinutes} Min.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),

          Text('Zutaten', style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ...recipe.ingredients.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${i.name} — ${i.amount.toStringAsFixed(0)}${i.unit}',
                  style: AppTextStyles.bodySmall,
                ),
              )),
          const SizedBox(height: AppConstants.spaceS),

          InkWell(
            onTap: () => setState(() => _stepsExpanded = !_stepsExpanded),
            child: Row(
              children: [
                Text('Zubereitung',
                    style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
                Icon(_stepsExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
          if (_stepsExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recipe.steps.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key + 1}. ${e.value}', style: AppTextStyles.bodySmall),
                  );
                }).toList(),
              ),
            ),

          if (recipe.coveredStackSupplements.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceM),
            Text('Deckt aus deinem Stack ab',
                style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _groupedCoverage(recipe).entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    '${e.key}: ${e.value.toStringAsFixed(0)}%',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ],

          if (nutrientEntries.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spaceM),
            Text('Nährstoff-Übersicht',
                style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: nutrientEntries.map((e) {
                final (label, unit) = kNutrientDisplay[e.key]!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppConstants.radiusRound),
                  ),
                  child: Text(
                    '$label: ${e.value.toStringAsFixed(e.value < 10 ? 1 : 0)}$unit',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Pro Stack-Supplement die höchste Abdeckung (ein Supplement kann über
  /// mehrere Nährstoffe gematcht sein, z.B. Kombipräparate) — für eine
  /// kompakte "Name: XX%"-Anzeige statt einer Zeile pro Nährstoff.
  Map<String, double> _groupedCoverage(GeneratedRecipe recipe) {
    final result = <String, double>{};
    for (final c in recipe.coveredStackSupplements) {
      final current = result[c.stackEntryName];
      if (current == null || c.coveragePct > current) {
        result[c.stackEntryName] = c.coveragePct;
      }
    }
    return result;
  }
}
