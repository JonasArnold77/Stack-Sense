import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../stack/data/recipe_override_provider.dart';
import '../../../stack/data/stack_provider.dart';
import '../../../stack/domain/models/stack_entry.dart';
import '../../domain/models/generated_recipe.dart';
import '../../domain/models/saved_recipe.dart';

enum _Choice { keep, remove, reduce }

/// Absolute Mengen statt Prozent anzeigen (z.B. "111 von 400mg") — Prozentwerte
/// sagen dem Nutzer nicht, wie viel er konkret noch supplementieren muss.
String _fmtAmount(double value) => value.toStringAsFixed(value < 10 ? 1 : 0);

/// Zeigt beim "Für heute aktivieren" eines Rezepts, welche Stack-Supplements
/// dadurch (teilweise) abgedeckt werden, und lässt den Nutzer pro Supplement
/// wählen: entfernen, Dosis reduzieren (falls berechenbar) oder beibehalten.
/// Berechnet die Abdeckung IMMER frisch gegen den aktuellen Stack — nicht
/// gegen einen beim Speichern zwischengespeicherten Stand.
class RecipeActivationDialog extends ConsumerStatefulWidget {
  final SavedRecipe saved;

  const RecipeActivationDialog({super.key, required this.saved});

  static Future<void> show(BuildContext context, SavedRecipe saved) {
    return showDialog(
      context: context,
      builder: (_) => RecipeActivationDialog(saved: saved),
    );
  }

  @override
  ConsumerState<RecipeActivationDialog> createState() => _RecipeActivationDialogState();
}

class _RecipeActivationDialogState extends ConsumerState<RecipeActivationDialog> {
  bool _isLoading = true;
  String? _error;
  List<CoveredSupplement> _covered = [];
  final Map<String, _Choice> _choices = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stack = ref.read(stackProvider);
      final covered = await ApiService.instance.computeRecipeCoverage(
        ingredients: widget.saved.recipe.ingredients,
        stack: stack,
      );
      if (!mounted) return;
      setState(() {
        _covered = covered;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Abdeckung konnte nicht berechnet werden.';
        _isLoading = false;
      });
    }
  }

  Map<String, List<CoveredSupplement>> get _groupedByEntry {
    final grouped = <String, List<CoveredSupplement>>{};
    for (final c in _covered) {
      grouped.putIfAbsent(c.stackEntryId, () => []).add(c);
    }
    return grouped;
  }

  double _maxCoverage(List<CoveredSupplement> items) =>
      items.map((c) => c.coveragePct).reduce((a, b) => a > b ? a : b);

  Future<void> _apply() async {
    final stack = ref.read(stackProvider);
    final notifier = ref.read(recipeOverrideProvider.notifier);
    final today = DateTime.now();

    for (final entry in _groupedByEntry.entries) {
      final choice = _choices[entry.key] ?? _Choice.keep;
      if (choice == _Choice.keep) continue;

      final stackEntry = stack.where((e) => e.id == entry.key).firstOrNull;
      if (stackEntry == null) continue;

      if (choice == _Choice.remove) {
        await notifier.setOverride(
          entry.key,
          today,
          RecipeOverride(action: RecipeOverrideAction.removed, recipeTitle: widget.saved.recipe.title),
        );
      } else if (choice == _Choice.reduce && stackEntry.dosageAmount != null) {
        final maxCoverage = _maxCoverage(entry.value);
        final newAmount = stackEntry.dosageAmount! * (1 - maxCoverage / 100);
        await notifier.setOverride(
          entry.key,
          today,
          RecipeOverride(
            action: RecipeOverrideAction.reduced,
            reducedToAmount: newAmount,
            reducedToUnit: stackEntry.dosageUnit,
            recipeTitle: widget.saved.recipe.title,
          ),
        );
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Für heute aktivieren'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildBody(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        if (!_isLoading && _error == null && _covered.isNotEmpty)
          FilledButton(onPressed: _apply, child: const Text('Anwenden')),
        if (!_isLoading && (_error != null || _covered.isEmpty))
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.spaceL),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.evidenceRed));
    }
    if (_covered.isEmpty) {
      return Text(
        'Für "${widget.saved.recipe.title}" wurden heute keine überschneidenden Supplements in deinem Stack gefunden.',
        style: AppTextStyles.bodyMedium,
      );
    }

    final stack = ref.watch(stackProvider);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dieses Rezept deckt heute teilweise ab:',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spaceM),
          ..._groupedByEntry.entries.map((entry) {
            final stackEntry = stack.where((e) => e.id == entry.key).firstOrNull;
            if (stackEntry == null) return const SizedBox.shrink();
            return _SupplementChoiceRow(
              stackEntry: stackEntry,
              covered: entry.value,
              choice: _choices[entry.key] ?? _Choice.keep,
              onChanged: (c) => setState(() => _choices[entry.key] = c),
            );
          }),
        ],
      ),
    );
  }
}

class _SupplementChoiceRow extends StatelessWidget {
  final StackEntry stackEntry;
  final List<CoveredSupplement> covered;
  final _Choice choice;
  final ValueChanged<_Choice> onChanged;

  const _SupplementChoiceRow({
    required this.stackEntry,
    required this.covered,
    required this.choice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final maxCoverage = covered.map((c) => c.coveragePct).reduce((a, b) => a > b ? a : b);
    final canReduce = stackEntry.dosageAmount != null && maxCoverage < 100;
    final coverageLabels = covered
        .map((c) =>
            '${kNutrientDisplay[c.nutrientKey]?.$1 ?? c.nutrientKey}: '
            '${_fmtAmount(c.recipeAmount)} von ${_fmtAmount(c.stackDoseAmount)}${c.unit}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stackEntry.name, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(coverageLabels, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: AppConstants.spaceS),
          Wrap(
            spacing: 8,
            children: [
              _choiceChip('Beibehalten', _Choice.keep, choice, onChanged),
              _choiceChip('Entfernen', _Choice.remove, choice, onChanged),
              if (canReduce)
                _choiceChip(
                  'Reduzieren auf ${(stackEntry.dosageAmount! * (1 - maxCoverage / 100)).toStringAsFixed(0)}${stackEntry.dosageUnit}',
                  _Choice.reduce,
                  choice,
                  onChanged,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceChip(
    String label,
    _Choice value,
    _Choice selected,
    ValueChanged<_Choice> onChanged,
  ) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        fontSize: 12,
      ),
    );
  }
}
