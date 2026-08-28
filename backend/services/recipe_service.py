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
from services.nutrient_coverage_service import compute_recipe_nutrients, compute_stack_coverage

logger = logging.getLogger(__name__)

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

JSON-FORMAT (exakt einhalten):
{
  "recipes": [
    {
      "title": "Lachs-Bowl mit Quinoa und Spinat",
      "ingredients": [
        {"name": "Lachsfilet", "amount": 150, "unit": "g"},
        {"name": "Quinoa", "amount": 80, "unit": "g"},
        {"name": "Spinat", "amount": 100, "unit": "g"},
        {"name": "Olivenöl", "amount": 10, "unit": "ml"}
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


def _build_recipe_user_message(request: RecipeGenerationRequest) -> str:
    carb_labels = [_CARB_LABELS[c] for c in request.carb_bases]
    lines = [
        f"Ernährungsweise: {_DIET_LABELS[request.diet_type]}",
        f"Bevorzugte Kohlenhydratbasis: {', '.join(carb_labels) if carb_labels else 'keine Präferenz'}",
        f"Allergien/Unverträglichkeiten: {', '.join(request.allergies) if request.allergies else 'keine'}",
        f"Maximale Kochzeit: {request.max_cook_time_minutes} Minuten",
    ]

    if request.stack:
        stack_names = ", ".join(s.name for s in request.stack)
        lines.append(
            f"\nAktueller Supplement-Stack des Nutzers (nur als thematischer Kontext, "
            f"keine Nährwert-Berechnung nötig): {stack_names}"
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

        user_message = _build_recipe_user_message(request)

        message = await self.client.messages.create(
            model=settings.claude_model,
            max_tokens=settings.claude_max_tokens,
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
        stack_dicts = _stack_to_dicts(request.stack)

        recipes: list[GeneratedRecipe] = []
        for item in raw_recipes:
            ingredients = [
                RecipeIngredient(name=ing["name"], amount=ing["amount"], unit=ing["unit"])
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
