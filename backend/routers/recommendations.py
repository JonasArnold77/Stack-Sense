from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import logging

from models.profile import RecommendationRequest
from models.recommendation import RecommendationResponse, ProductLink
from services.claude_service import ClaudeService

router = APIRouter(prefix="/api/v1", tags=["Empfehlungen"])
logger = logging.getLogger(__name__)

claude_service = ClaudeService()


@router.post("/recommendations", response_model=RecommendationResponse)
async def get_recommendations(request: RecommendationRequest) -> RecommendationResponse:
    """
    Gibt personalisierte Supplement-Empfehlungen zurück.

    Nimmt Nutzerprofil + gewähltes Ziel entgegen,
    gibt Grün/Gelb/Rot-Empfehlungen von Claude zurück.
    """
    try:
        result = await claude_service.get_recommendations(
            profile=request.profile,
            goal=request.goal,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        logger.error(f"Unerwarteter Fehler: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Interner Serverfehler")


class ExplainRequest(BaseModel):
    supplement_name: str
    substance_name: str | None = None


@router.post("/explain")
async def explain_supplement(request: ExplainRequest) -> dict:
    """
    Gibt eine einfache Laienerklärung für ein Supplement zurück.
    Wird on-demand geladen wenn der Nutzer auf 'Einfach erklärt' tippt.
    """
    try:
        explanation = await claude_service.get_simple_explanation(
            supplement_name=request.supplement_name,
            substance_name=request.substance_name,
        )
        return {"explanation": explanation}
    except Exception as e:
        logger.error(f"Explain-Fehler: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erklärung konnte nicht generiert werden")


class ProductsRequest(BaseModel):
    supplement_name: str
    substance_name: str | None = None
    categories: list[str] = []


@router.post("/products")
async def get_products(request: ProductsRequest) -> dict:
    """
    Gibt on-demand KI-generierte Kaufoptionen für ein Supplement zurück.
    Wird lazy geladen wenn der Nutzer auf den Kauf-Button tippt.
    """
    try:
        links = await claude_service.get_product_suggestions(
            supplement_name=request.supplement_name,
            substance_name=request.substance_name,
            categories=request.categories,
        )
        return {"products": [l.model_dump() for l in links]}
    except Exception as e:
        logger.error(f"Produkt-Suche Fehler: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Produkte konnten nicht geladen werden")


@router.get("/health")
async def health():
    """Einfacher Health-Check — prüft ob der Server läuft."""
    return {"status": "ok", "service": "StackSense Backend"}
