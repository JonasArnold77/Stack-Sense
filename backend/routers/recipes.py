import logging

from fastapi import APIRouter, HTTPException

from models.recipe import (
    RecipeCoverageRequest,
    RecipeCoverageResponse,
    RecipeGenerationRequest,
    RecipeGenerationResponse,
)
from services.nutrient_coverage_service import compute_recipe_nutrients, compute_stack_coverage
from services.recipe_service import RecipeService

router = APIRouter(prefix="/api/v1", tags=["Rezepte"])
logger = logging.getLogger(__name__)

recipe_service = RecipeService()


@router.post("/recipes/generate", response_model=RecipeGenerationResponse)
async def generate_recipes(request: RecipeGenerationRequest) -> RecipeGenerationResponse:
    """Generiert 3-5 personalisierte Rezepte (Titel/Zutaten/Schritte via Claude,
    Nährstoff-Übersicht + Stack-Abdeckung deterministisch in Python berechnet)."""
    try:
        return await recipe_service.generate_recipes(request)
    except ValueError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        logger.error("Fehler bei Rezeptgenerierung: %s", e)
        raise HTTPException(status_code=500, detail="Rezeptgenerierung fehlgeschlagen.")


@router.post("/recipes/coverage", response_model=RecipeCoverageResponse)
async def compute_coverage(request: RecipeCoverageRequest) -> RecipeCoverageResponse:
    """Für 'Für heute aktivieren' — berechnet die Stack-Abdeckung eines
    gespeicherten Rezepts frisch gegen den AKTUELLEN Stack (nicht gegen einen
    beim Speichern zwischengespeicherten Stand, der Stack kann sich seitdem
    geändert haben)."""
    try:
        ingredient_dicts = [ing.model_dump() for ing in request.ingredients]
        recipe_nutrients = await compute_recipe_nutrients(ingredient_dicts)
        stack_dicts = [s.model_dump() for s in request.stack]
        covered = compute_stack_coverage(recipe_nutrients, stack_dicts)
        return RecipeCoverageResponse(covered_stack_supplements=covered)
    except Exception as e:
        logger.error("Fehler bei Abdeckungsberechnung: %s", e)
        raise HTTPException(status_code=500, detail="Abdeckungsberechnung fehlgeschlagen.")
