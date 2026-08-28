/// Anzeigename + Einheit pro nutrient_key — muss exakt den kanonischen
/// Einheiten in backend/services/fooddata_service.py und
/// supplement_nutrients_seed.json entsprechen (die API liefert nur den
/// nutrient_key + Zahl, die Einheit ist implizit fix pro Key).
const Map<String, (String label, String unit)> kNutrientDisplay = {
  'vitamin_d': ('Vitamin D', 'IU'),
  'vitamin_e': ('Vitamin E', 'mg'),
  'vitamin_k': ('Vitamin K', 'mcg'),
  'vitamin_c': ('Vitamin C', 'mg'),
  'vitamin_a': ('Vitamin A', 'mcg'),
  'vitamin_b12': ('Vitamin B12', 'mcg'),
  'vitamin_b6': ('Vitamin B6', 'mg'),
  'folate': ('Folsäure', 'mcg'),
  'biotin': ('Biotin', 'mcg'),
  'magnesium': ('Magnesium', 'mg'),
  'zinc': ('Zink', 'mg'),
  'iron': ('Eisen', 'mg'),
  'calcium': ('Calcium', 'mg'),
  'potassium': ('Kalium', 'mg'),
  'selenium': ('Selen', 'mcg'),
  'iodine': ('Jod', 'mcg'),
  'chromium': ('Chrom', 'mcg'),
  'manganese': ('Mangan', 'mg'),
  'omega_3': ('Omega-3', 'g'),
  'protein': ('Protein', 'g'),
  'fiber': ('Ballaststoffe', 'g'),
  'sodium': ('Natrium', 'mg'),
  'lutein_zeaxanthin': ('Lutein/Zeaxanthin', 'mcg'),
  'lycopene': ('Lycopin', 'mcg'),
};

enum DietType { vegetarian, vegan, omnivore }

extension DietTypeLabel on DietType {
  String get label => switch (this) {
        DietType.vegetarian => 'Vegetarisch',
        DietType.vegan => 'Vegan',
        DietType.omnivore => 'Omnivor',
      };
}

enum CarbBase { rice, potatoes, pasta, bread }

extension CarbBaseLabel on CarbBase {
  String get label => switch (this) {
        CarbBase.rice => 'Reis',
        CarbBase.potatoes => 'Kartoffeln',
        CarbBase.pasta => 'Nudeln',
        CarbBase.bread => 'Brot',
      };
}

class RecipeIngredient {
  final String name;
  final double amount;
  final String unit; // "g" | "ml"

  const RecipeIngredient({required this.name, required this.amount, required this.unit});

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount, 'unit': unit};
}

/// Ergebnis der Stack-Abdeckungsberechnung (backend nutrient_coverage_service) —
/// welches Stack-Supplement wird zu wie viel Prozent durch das Rezept gedeckt.
class CoveredSupplement {
  final String stackEntryId;
  final String stackEntryName;
  final String nutrientKey;
  final double coveragePct;
  final double recipeAmount;
  final double stackDoseAmount;
  final String unit;

  const CoveredSupplement({
    required this.stackEntryId,
    required this.stackEntryName,
    required this.nutrientKey,
    required this.coveragePct,
    required this.recipeAmount,
    required this.stackDoseAmount,
    required this.unit,
  });

  factory CoveredSupplement.fromJson(Map<String, dynamic> json) => CoveredSupplement(
        stackEntryId: json['stack_entry_id'] as String,
        stackEntryName: json['stack_entry_name'] as String,
        nutrientKey: json['nutrient_key'] as String,
        coveragePct: (json['coverage_pct'] as num).toDouble(),
        recipeAmount: (json['recipe_amount'] as num).toDouble(),
        stackDoseAmount: (json['stack_dose_amount'] as num).toDouble(),
        unit: json['unit'] as String,
      );

  Map<String, dynamic> toJson() => {
        'stack_entry_id': stackEntryId,
        'stack_entry_name': stackEntryName,
        'nutrient_key': nutrientKey,
        'coverage_pct': coveragePct,
        'recipe_amount': recipeAmount,
        'stack_dose_amount': stackDoseAmount,
        'unit': unit,
      };
}

class GeneratedRecipe {
  final String id;
  final String title;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final int cookTimeMinutes;
  final Map<String, double> nutrientOverview;
  final List<CoveredSupplement> coveredStackSupplements;

  const GeneratedRecipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.cookTimeMinutes,
    this.nutrientOverview = const {},
    this.coveredStackSupplements = const [],
  });

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? [];
    final rawSteps = json['steps'] as List<dynamic>? ?? [];
    final rawOverview = json['nutrient_overview'] as Map<String, dynamic>? ?? {};
    final rawCovered = json['covered_stack_supplements'] as List<dynamic>? ?? [];

    return GeneratedRecipe(
      id: json['id'] as String,
      title: json['title'] as String,
      ingredients: rawIngredients
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: rawSteps.map((e) => e as String).toList(),
      cookTimeMinutes: (json['cook_time_minutes'] as num).toInt(),
      nutrientOverview:
          rawOverview.map((k, v) => MapEntry(k, (v as num).toDouble())),
      coveredStackSupplements: rawCovered
          .map((e) => CoveredSupplement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps,
        'cook_time_minutes': cookTimeMinutes,
        'nutrient_overview': nutrientOverview,
        'covered_stack_supplements': coveredStackSupplements.map((c) => c.toJson()).toList(),
      };
}
