from enum import Enum
from typing import Optional

from pydantic import BaseModel

from services.nutrient_coverage_service import CoveredSupplement


class DietType(str, Enum):
    vegetarian = "vegetarian"
    vegan = "vegan"
    omnivore = "omnivore"


class CarbBase(str, Enum):
    rice = "rice"
    potatoes = "potatoes"
    pasta = "pasta"
    bread = "bread"


class RecipeIngredient(BaseModel):
    name: str
    amount: float
    unit: str  # ausschließlich "g" oder "ml" — siehe SYSTEM_PROMPT_RECIPE
    # Englischer, generischer USDA-FoodData-Central-Suchbegriff (z.B. "pumpkin
    # seeds" für "Kürbiskerne") — FDC versteht keine deutschen Zutatennamen,
    # ohne dieses Feld liefert die Freitextsuche fast immer Zufallstreffer
    # (z.B. "Eier" -> "McFlurry"). Von Claude mitgeliefert (reine Übersetzung,
    # keine Nährwert-Schätzung — verletzt nicht die Nur-Python-Berechnungsregel),
    # optional damit alte gespeicherte Rezepte ohne dieses Feld weiter laden.
    fdc_query: Optional[str] = None


class GeneratedRecipe(BaseModel):
    id: str
    title: str
    ingredients: list[RecipeIngredient]
    steps: list[str]
    cook_time_minutes: int
    # Von Python berechnet (nutrient_coverage_service), NICHT von Claude —
    # siehe recipe_service.generate_recipes().
    nutrient_overview: dict[str, float] = {}
    covered_stack_supplements: list[CoveredSupplement] = []


class StackEntrySummary(BaseModel):
    """Minimale Projektion eines StackEntry für Rezept-Anfragen — nur was für
    Prompt-Kontext bzw. Abdeckungsberechnung gebraucht wird."""
    id: str
    name: str
    substance_name: Optional[str] = None
    enthaltene_wirkstoffe: list[str] = []
    dosage_amount: Optional[float] = None
    dosage_unit: Optional[str] = None


class RecipeGenerationRequest(BaseModel):
    diet_type: DietType
    carb_bases: list[CarbBase] = []
    allergies: list[str] = []
    max_cook_time_minutes: int = 30
    stack: list[StackEntrySummary] = []
    bypass_cache: bool = False


class RecipeGenerationResponse(BaseModel):
    recipes: list[GeneratedRecipe]


class RecipeCoverageRequest(BaseModel):
    """Für 'Für heute aktivieren' — Abdeckung wird frisch gegen den aktuellen
    Stack berechnet, nicht aus einem beim Speichern zwischengespeicherten
    Snapshot (siehe Plan Phase C)."""
    ingredients: list[RecipeIngredient]
    stack: list[StackEntrySummary]


class RecipeCoverageResponse(BaseModel):
    covered_stack_supplements: list[CoveredSupplement]
