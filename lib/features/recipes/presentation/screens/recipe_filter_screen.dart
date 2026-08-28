import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../stack/data/stack_provider.dart';
import '../../domain/models/generated_recipe.dart';

const _cookTimeOptions = [15, 30, 45, 60, 90];

/// Filter vor jeder Rezeptgenerierung — bewusst OHNE gespeicherte
/// Standard-Präferenzen: bei jedem Aufruf startet das Formular mit
/// generischen Werten und wird frisch ausgefüllt (Vereinfachung, vom Nutzer
/// explizit bestätigt).
class RecipeFilterScreen extends ConsumerStatefulWidget {
  const RecipeFilterScreen({super.key});

  @override
  ConsumerState<RecipeFilterScreen> createState() => _RecipeFilterScreenState();
}

class _RecipeFilterScreenState extends ConsumerState<RecipeFilterScreen> {
  DietType _dietType = DietType.omnivore;
  final Set<CarbBase> _carbBases = {};
  final _allergyController = TextEditingController();
  final List<String> _allergies = [];
  int _cookTime = 30;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _allergyController.dispose();
    super.dispose();
  }

  void _addAllergy() {
    final value = _allergyController.text.trim();
    if (value.isEmpty || _allergies.contains(value)) return;
    setState(() {
      _allergies.add(value);
      _allergyController.clear();
    });
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stack = ref.read(stackProvider);
      final recipes = await ApiService.instance.generateRecipes(
        dietType: _dietType,
        carbBases: _carbBases.toList(),
        allergies: _allergies,
        maxCookTimeMinutes: _cookTime,
        stack: stack,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.push(AppRoutes.recipeResults, extra: recipes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Rezepte konnten nicht generiert werden. Bitte erneut versuchen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rezepte generieren'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.screenPaddingH),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                decoration: BoxDecoration(
                  color: AppColors.evidenceRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  border: Border.all(color: AppColors.evidenceRed.withOpacity(0.3)),
                ),
                child: Text(_error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.evidenceRed)),
              ),
              const SizedBox(height: AppConstants.spaceM),
            ],

            Text('Ernährungsweise', style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppConstants.spaceS),
            Wrap(
              spacing: 8,
              children: DietType.values.map((d) {
                final selected = _dietType == d;
                return ChoiceChip(
                  label: Text(d.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _dietType = d),
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppConstants.spaceL),

            Text('Bevorzugte Kohlenhydratbasis', style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Mehrfachauswahl möglich', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: AppConstants.spaceS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CarbBase.values.map((c) {
                final selected = _carbBases.contains(c);
                return FilterChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _carbBases.add(c);
                    } else {
                      _carbBases.remove(c);
                    }
                  }),
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppConstants.spaceL),

            Text('Allergien / Unverträglichkeiten', style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppConstants.spaceS),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allergyController,
                    decoration: const InputDecoration(
                      hintText: 'z.B. Nüsse, Laktose',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addAllergy(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onPressed: _addAllergy,
                ),
              ],
            ),
            if (_allergies.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spaceS),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allergies
                    .map((a) => Chip(
                          label: Text(a),
                          onDeleted: () => setState(() => _allergies.remove(a)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: AppConstants.spaceL),

            Text('Maximale Kochzeit', style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppConstants.spaceS),
            Wrap(
              spacing: 8,
              children: _cookTimeOptions.map((minutes) {
                final selected = _cookTime == minutes;
                return ChoiceChip(
                  label: Text('$minutes Min.'),
                  selected: selected,
                  onSelected: (_) => setState(() => _cookTime = minutes),
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppConstants.spaceXL),

            FilledButton(
              onPressed: _isLoading ? null : _generate,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Rezepte generieren'),
            ),
          ],
        ),
      ),
    );
  }
}
