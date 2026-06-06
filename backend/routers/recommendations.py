from fastapi import APIRouter, HTTPException
import logging

from models.profile import RecommendationRequest
from models.recommendation import RecommendationResponse
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


@router.get("/health")
async def health():
    """Einfacher Health-Check — prüft ob der Server läuft."""
    return {"status": "ok", "service": "StackSense Backend"}
