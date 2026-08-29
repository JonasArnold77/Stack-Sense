"""
Recipe Service — generiert Rezeptinhalte über Claude (Titel/Zutaten/Schritte/
Kochzeit) und berechnet die Nährstoff-Übersicht + Stack-Abdeckung danach
deterministisch in Python (nutrient_coverage_service), NICHT von Claude
geschätzt — siehe Plan-Dokument "Zentrale Design-Entscheidung".

Kein Response-Cache (anders als ClaudeService.get_recommendations): der
Nutzer will bei jeder Generierung Abwechslung, ein Cache würde nur
repetitive Ergebnisse liefern ohne echten Kostenvorteil.
"""
import json
import logging
import uuid

import anthropic

from config.settings import settings
from models.recipe import (
    CarbBase,
    DietType,
    GeneratedRecipe,
    RecipeGenerationRequest,
    RecipeGenerationResponse,
    RecipeIngredient,
    StackEntrySummary,
)
from services.claude_json import extract_json
from services.nutrient_coverage_service import (
    compute_recipe_nutrients,
    compute_stack_coverage,
    get_stack_target_nutrients,
)

logger = logging.getLogger(__name__)

# Eigenes (höheres) Token-Budget statt settings.claude_max_tokens (2500, für die
# kürzeren Empfehlungs-Antworten dimensioniert): 3-5 Rezepte mit je bis zu 8
# Zutaten inkl. "fdc_query" pro Zutat sprengen das — sonst wird die JSON-Antwort
# mitten im Stream abgeschnitten (ungültiges JSON, ValueError in generate_recipes).
_RECIPE_MAX_TOKENS = 4096

_DIET_LABELS = {
    DietType.vegetarian: "Vegetarisch",
    DietType.vegan: "Vegan",
    DietType.omnivore: "Omnivor (alles erlaubt)",
}

_CARB_LABELS = {
    CarbBase.rice: "Reis",
    CarbBase.potatoes: "Kartoffeln",
    CarbBase.pasta: "Nudeln",
    CarbBase.bread: "Brot",
}

# Deutsche Anzeigenamen — muss zu kNutrientDisplay in
# lib/features/recipes/domain/models/generated_recipe.dart passen.
_NUTRIENT_LABELS = {
    "vitamin_d": "Vitamin D", "vitamin_e": "Vitamin E", "vitamin_k": "Vitamin K",
    "vitamin_c": "Vitamin C", "vitamin_a": "Vitamin A", "vitamin_b12": "Vitamin B12",
    "vitamin_b6": "Vitamin B6", "folate": "Folsäure", "biotin": "Biotin",
    "magnesium": "Magnesium", "zinc": "Zink", "iron": "Eisen", "calcium": "Calcium",
    "potassium": "Kalium", "selenium": "Selen", "iodine": "Jod", "chromium": "Chrom",
    "manganese": "Mangan", "omega_3": "Omega-3", "protein": "Protein",
    "fiber": "Ballaststoffe", "sodium": "Natrium",
    "lutein_zeaxanthin": "Lutein/Zeaxanthin", "lycopene": "Lycopin",
}

SYSTEM_PROMPT_RECIPE = """Du bist ein Koch-Assistent für die App LifeLab. Du erstellst \
personalisierte Rezeptvorschläge basierend auf Ernährungspräferenzen.

DEINE AUFGABE:
Erstelle 3–5 unterschiedliche, alltagstaugliche Rezepte, die zu den angegebenen \
Präferenzen passen.

⛔ HARDREGEL — KEINE NÄHRWERT-ANGABEN:
Gib AUSSCHLIESSLICH Titel, Zutaten (mit Menge + Einheit), Zubereitungsschritte und \
Kochzeit an. Erfinde KEINE Nährwert-Prozentsätze, KEINE Angaben zu Vitaminen/ \
Mineralstoffen/Kalorien — diese werden separat exakt berechnet, nicht von dir \
geschätzt.

WICHTIGE REGELN:
1. Antworte AUSSCHLIESSLICH mit validem JSON — kein Text davor oder danach
2. Zutatenmengen AUSSCHLIESSLICH in Gramm ("g") oder Milliliter ("ml") angeben — \
niemals Stückzahlen ("2 Eier"), Esslöffel o.ä. Schätze eine sinnvolle Gramm-/ \
Milliliter-Menge.
3. Halte die Ernährungsweise strikt ein (vegan bedeutet: keinerlei tierische \
Produkte, auch keine Milch/Eier/Honig)
4. Vermeide ALLE angegebenen Allergene vollständig, auch in Zutatennamen \
("Mandelmilch" bei Nussallergie ist verboten)
5. Jedes Rezept MUSS mindestens eine der angegebenen Kohlenhydratbasen enthalten \
(falls welche angegeben wurden)
6. cook_time_minutes darf die angegebene maximale Kochzeit nicht überschreiten
7. Die 3–5 Rezepte müssen sich in Zutaten/Zubereitungsart klar unterscheiden — \
keine bloßen Variationen desselben Gerichts
8. steps: 3–8 kurze, klare Schritte auf Deutsch
9. title: prägnant, appetitanregend, max. 60 Zeichen
10. Falls "ZIEL-NÄHRSTOFFE" angegeben sind: baue nach Möglichkeit in JEDES Rezept \
mindestens eine Zutat ein, die reich an einem dieser Nährstoffe ist (z.B. bei \
"Magnesium" → Kürbiskerne, Mandeln, Spinat; bei "Eisen" → Rind, Linsen). Das hat \
NIEDRIGERE Priorität als Ernährungsweise/Allergien/Kohlenhydratbasis — nur \
einbauen wenn es zum Rezept passt, nicht erzwingen.
11. JEDE Zutat braucht zusätzlich "fdc_query": einen ENGLISCHEN, generischen \
Suchbegriff für die USDA FoodData-Central-Datenbank (z.B. "Kürbiskerne" → \
"pumpkin seeds", "Hähnchenbrust" → "chicken breast", "Olivenöl" → "olive oil"). \
Ohne diesen Suchbegriff kann die Nährstoff-Datenbank die Zutat nicht finden — \
IMMER angeben, auch bei einfachen Zutaten. Möglichst generisch/unmarkiert \
(kein Markenname, keine Zubereitungsart wie "gekocht" im Suchbegriff, außer sie \
ändert den Nährwert wesentlich, z.B. "gekochter Reis" → "white rice, cooked").

JSON-FORMAT (exakt einhalten):
{
  "recipes": [
    {
      "title": "Lachs-Bowl mit Quinoa und Spinat",
      "ingredients": [
        {"name": "Lachsfilet", "amount": 150, "unit": "g", "fdc_query": "salmon fillet"},
        {"name": "Quinoa", "amount": 80, "unit": "g", "fdc_query": "quinoa, cooked"},
        {"name": "Spinat", "amount": 100, "unit": "g", "fdc_query": "spinach, raw"},
        {"name": "Olivenöl", "amount": 10, "unit": "ml", "fdc_query": "olive oil"}
      ],
      "steps": [
        "Quinoa nach Packungsanweisung kochen.",
        "Lachs in einer Pfanne mit etwas Olivenöl von beiden Seiten braten.",
        "Spinat kurz andünsten.",
        "Alles zusammen anrichten."
      ],
      "cook_time_minutes": 25
    }
  ]
}
"""


def _build_recipe_user_message(request: RecipeGenerationRequest, target_nutrients: set[str]) -> str:
    carb_labels = [_CARB_LABELS[c] for c in request.carb_bases]
    lines = [
        f"Ernährungsweise: {_DIET_LABELS[request.diet_type]}",
        f"Bevorzugte Kohlenhydratbasis: {', '.join(carb_labels) if carb_labels else 'keine Präferenz'}",
        f"Allergien/Unverträglichkeiten: {', '.join(request.allergies) if request.allergies else 'keine'}",
        f"Maximale Kochzeit: {request.max_cook_time_minutes} Minuten",
    ]

    if request.stack:
        stack_names = ", ".join(s.name for s in request.stack)
        lines.append(f"\nAktueller Supplement-Stack des Nutzers: {stack_names}")

    if target_nutrients:
        target_labels = sorted(_NUTRIENT_LABELS.get(k, k) for k in target_nutrients)
        lines.append(
            f"\nZIEL-NÄHRSTOFFE (siehe Regel 10 — nach Möglichkeit über Zutaten abdecken, "
            f"niedrigere Priorität als die übrigen Präferenzen): {', '.join(target_labels)}"
        )
    elif request.stack:
        lines.append(
            "\n(Für keines der Supplements im Stack lässt sich eine Lebensmittel-Nährstoff-"
            "Abdeckung berechnen — z.B. weil es sich um Aminosäuren/Kräuterextrakte ohne "
            "erfasste Nährstoff-Entsprechung handelt. Kein ZIEL-NÄHRSTOFF nötig.)"
        )

    lines.append(f"\nGeneriere 3–5 Rezepte gemäß dieser Präferenzen.")
    return "\n".join(lines)


def _stack_to_dicts(stack: list[StackEntrySummary]) -> list[dict]:
    return [
        {
            "id": s.id,
            "name": s.name,
            "substance_name": s.substance_name,
            "enthaltene_wirkstoffe": s.enthaltene_wirkstoffe,
            "dosage_amount": s.dosage_amount,
            "dosage_unit": s.dosage_unit,
        }
        for s in stack
    ]


class RecipeService:
    def __init__(self):
        self.client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)

    async def generate_recipes(self, request: RecipeGenerationRequest) -> RecipeGenerationResponse:
        logger.info(
            "Rezeptanfrage: diet=%s, carb_bases=%s, allergies=%s, max_cook_time=%s",
            request.diet_type, request.carb_bases, request.allergies,
            request.max_cook_time_minutes,
        )

        stack_dicts = _stack_to_dicts(request.stack)
        target_nutrients = get_stack_target_nutrients(stack_dicts)
        user_message = _build_recipe_user_message(request, target_nutrients)

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=_RECIPE_MAX_TOKENS,
            system=SYSTEM_PROMPT_RECIPE,
            messages=[{"role": "user", "content": user_message}],
        )

        raw = extract_json(message.content[0].text.strip())
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error("Claude JSON-Fehler (Rezepte): %s\nRaw: %s", e, raw[:500])
            raise ValueError(f"Claude-Antwort ist kein valides JSON: {e}")

        raw_recipes = data.get("recipes", [])

        recipes: list[GeneratedRecipe] = []
        for item in raw_recipes:
            ingredients = [
                RecipeIngredient(
                    name=ing["name"],
                    amount=ing["amount"],
                    unit=ing["unit"],
                    fdc_query=ing.get("fdc_query"),
                )
                for ing in item.get("ingredients", [])
            ]
            ingredient_dicts = [ing.model_dump() for ing in ingredients]

            nutrient_overview = await compute_recipe_nutrients(ingredient_dicts)
            covered = compute_stack_coverage(nutrient_overview, stack_dicts)

            recipes.append(GeneratedRecipe(
                id=str(uuid.uuid4()),
                title=item.get("title", "Rezept"),
                ingredients=ingredients,
                steps=item.get("steps", []),
                cook_time_minutes=item.get("cook_time_minutes", request.max_cook_time_minutes),
                nutrient_overview=nutrient_overview,
                covered_stack_supplements=covered,
            ))

        return RecipeGenerationResponse(recipes=recipes)
