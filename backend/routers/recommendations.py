from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import logging
import json
import os

from models.profile import RecommendationRequest
from models.recommendation import RecommendationResponse, ProductLink
from services.claude_service import ClaudeService
from services.pubmed_service import PubMedService

router = APIRouter(prefix="/api/v1", tags=["Empfehlungen"])
logger = logging.getLogger(__name__)

claude_service = ClaudeService()
pubmed_service = PubMedService()

# Statische Supplement-DB einmal laden (food_sources vorberechnet, kein Claude-Call)
_SUPPLEMENT_DB: dict = {}
try:
    _router_dir = os.path.dirname(os.path.abspath(__file__))
    _db_path = os.path.normpath(os.path.join(_router_dir, "..", "data", "supplement_knowledge.json"))
    with open(_db_path, "r", encoding="utf-8") as _f:
        _SUPPLEMENT_DB = json.load(_f).get("supplements", {})
    logger.info(f"Supplement-DB geladen: {len(_SUPPLEMENT_DB)} Eintraege ({_db_path})")
except Exception as _e:
    logger.warning(f"Supplement-DB nicht ladbar: {_e}")


@router.post("/recommendations", response_model=RecommendationResponse)
async def get_recommendations(request: RecommendationRequest) -> RecommendationResponse:
    """
    Gibt personalisierte Supplement-Empfehlungen zurueck.

    Nimmt Nutzerprofil + gewaehltes Ziel entgegen,
    gibt Gruen/Gelb/Rot-Empfehlungen von Claude zurueck.
    """
    try:
        result = await claude_service.get_recommendations(
            profile=request.profile,
            goal=request.goal,
            limit=request.limit,
            exclude_ids=request.exclude_ids,
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
    Gibt eine einfache Laienerklarung fuer ein Supplement zurueck.
    Wird on-demand geladen wenn der Nutzer auf "Einfach erklaert" tippt.
    """
    try:
        explanation = await claude_service.get_simple_explanation(
            supplement_name=request.supplement_name,
            substance_name=request.substance_name,
        )
        return {"explanation": explanation}
    except Exception as e:
        logger.error(f"Explain-Fehler: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erklaerung konnte nicht generiert werden")


class ProductsRequest(BaseModel):
    supplement_name: str
    substance_name: str | None = None
    categories: list[str] = []


@router.post("/products")
async def get_products(request: ProductsRequest) -> dict:
    """
    Gibt on-demand KI-generierte Kaufoptionen fuer ein Supplement zurueck.
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


class FoodSourcesRequest(BaseModel):
    supplement_name: str
    substance_name: str | None = None


@router.post("/food-sources")
async def get_food_sources(request: FoodSourcesRequest) -> dict:
    """
    Gibt natuerliche Lebensmittelquellen fuer einen Naehrstoff zurueck.
    Primaer aus supplement_knowledge.json (statisch, O(1)).
    Fallback auf Claude nur bei unbekannten Supplements.
    """
    # Supplement-ID ableiten: "Vitamin D3" -> "vitamin-d3"
    supp_id = request.supplement_name.lower().strip().replace(" ", "-").replace("_", "-")

    # 1. Statische DB-Suche
    entry = _SUPPLEMENT_DB.get(supp_id)
    if entry and entry.get("food_sources"):
        logger.info(f"food-sources: DB-Treffer fuer '{supp_id}'")
        return {"sources": entry["food_sources"]}

    # 2. Substance-Name versuchen
    if request.substance_name:
        substance_id = request.substance_name.lower().strip().replace(" ", "-")
        entry = _SUPPLEMENT_DB.get(substance_id)
        if entry and entry.get("food_sources"):
            logger.info(f"food-sources: DB-Treffer via Substance fuer '{substance_id}'")
            return {"sources": entry["food_sources"]}

    # 3. Fallback Claude (nur fuer unbekannte Supplements)
    logger.info(f"food-sources: Kein DB-Treffer fuer '{supp_id}' -- Claude-Fallback")
    try:
        sources = await claude_service.get_food_sources(
            supplement_name=request.supplement_name,
            substance_name=request.substance_name,
        )
        return {"sources": sources}
    except Exception as e:
        logger.error(f"Food-Sources Fehler: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Lebensmittelquellen konnten nicht geladen werden")


class SupplementInfo(BaseModel):
    id: str
    name: str
    substance_name: str | None = None
    enthaltene_wirkstoffe: list[str] = []


class DuplicateCheckRequest(BaseModel):
    new_supplement: SupplementInfo
    stack: list[SupplementInfo] = []


@router.post("/check-duplicates")
async def check_duplicates(request: DuplicateCheckRequest) -> dict:
    """
    Prueft semantisch ob das neue Supplement Wirkstoffe enthaelt
    die bereits im Stack vorhanden sind -- via Claude Haiku.
    Gibt { "duplicates": [ids], "reasoning": "..." } zurueck.
    """
    try:
        result = await claude_service.check_duplicates(
            new_supplement=request.new_supplement.model_dump(),
            stack=[e.model_dump() for e in request.stack],
        )
        return result
    except Exception as e:
        logger.error(f"Duplikat-Check Fehler: {e}", exc_info=True)
        return {"duplicates": [], "reasoning": "Pruefung nicht verfuegbar."}


class StudiesRequest(BaseModel):
    supplement_name: str
    substance_name: str | None = None
    goal: str | None = None


@router.post("/studies")
async def get_studies(request: StudiesRequest) -> dict:
    """
    Gibt PubMed-Studien zurueck die die Wirksamkeit eines Supplements belegen.
    Wird on-demand geladen wenn der Nutzer auf "Studien" tippt.
    """
    try:
        query_name = request.substance_name or request.supplement_name
        goal = request.goal or "health benefits"
        studies = await pubmed_service.get_supplement_evidence(
            supplement_name=query_name,
            goal=goal,
            max_results=5,
        )
        return {
            "studies": [
                {
                    "pmid": s["pmid"],
                    "title": s["title"],
                    "abstract": s["abstract"],
                    "year": s["year"],
                    "url": f"https://pubmed.ncbi.nlm.nih.gov/{s['pmid']}/",
                }
                for s in studies
            ]
        }
    except Exception as e:
        logger.error(f"Studies-Fehler: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Studien konnten nicht geladen werden")


@router.get("/health")
async def health():
    """Einfacher Health-Check -- prueft ob der Server laeuft."""
    return {"status": "ok", "service": "StackSense Backend"}
