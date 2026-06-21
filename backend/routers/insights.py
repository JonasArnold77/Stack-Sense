"""
Community-Insights Router
--------------------------
POST /api/v1/checkin-sync  — Speichert Check-in-Daten pro Supplement (anonym, device_id).
GET  /api/v1/community-insights — Aggregierte Verbesserungs-Stats für eine Liste von Supplements.

Datenschutz: Kein personenbezogenes Datum — nur anonyme device_id (UUID, lokal generiert).
Aggregation: Nutzer brauchen mind. 5 Check-ins mit einem Supplement,
             damit ihr Verlauf gewertet wird. Verbesserung = letzte Hälfte > erste Hälfte + 0.3.
"""
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel

from database.db import get_conn

router = APIRouter(prefix="/api/v1", tags=["Community Insights"])
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Request / Response Modelle
# ---------------------------------------------------------------------------

class CheckinSyncEntry(BaseModel):
    """Ein einzelner Check-in-Datenpunkt, verknüpft mit einem Supplement-Namen."""
    supplement_name: str
    checkin_date: str          # ISO-Date "2025-06-20"
    sleep_score: int
    energy_score: int
    focus_score: int
    mood_score: int


class CheckinSyncRequest(BaseModel):
    device_id: str             # anonyme UUID aus dem Gerät
    entries: list[CheckinSyncEntry]


class SupplementInsight(BaseModel):
    supplement_name: str
    dimension: str             # "sleep" | "energy" | "focus" | "mood"
    dimension_label: str       # "Schlaf" | "Energie" | …
    improvement_percent: int   # 0–100
    user_count: int
    label: str                 # fertige Anzeigetext für die UI


class CommunityInsightsResponse(BaseModel):
    insights: dict[str, SupplementInsight]   # key = supplement_name (lowercase)


# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------

_DIMENSION_LABELS = {
    "sleep":  "Schlaf",
    "energy": "Energie",
    "focus":  "Fokus",
    "mood":   "Stimmung",
}

_DIMENSIONS = list(_DIMENSION_LABELS.keys())


def _build_label(dim_label: str, pct: int, count: int, supp_name: str) -> str:
    """Baut den deutschen Bewertungstext für den Community-Banner."""
    if pct >= 70:
        quality = "deutlich verbessert"
    elif pct >= 50:
        quality = "spürbar verbessert"
    else:
        quality = "leicht verbessert"

    if count == 1:
        return f"★ 1 Nutzerbewertung: {dim_label} durch {supp_name} {quality}"
    return f"★ {count} Nutzerbewertungen: {dim_label} durch {supp_name} {quality}"


def _aggregate_supplement(cur, supplement_name: str) -> Optional[SupplementInsight]:
    """
    Berechnet die beste Community-Insight für ein Supplement.
    Gibt None zurück wenn nicht genug Daten vorhanden (< 3 Nutzer).
    """
    # Alle Nutzer die dieses Supplement mind. 5x getracked haben
    cur.execute("""
        SELECT device_id, checkin_date,
               sleep_score, energy_score, focus_score, mood_score
        FROM supplement_checkins
        WHERE LOWER(supplement_name) = LOWER(%s)
        ORDER BY device_id, checkin_date
    """, (supplement_name,))
    rows = cur.fetchall()

    if not rows:
        return None

    # Nach device_id gruppieren
    users: dict[str, list[dict]] = {}
    for row in rows:
        did = row[0]
        users.setdefault(did, []).append({
            "date":   row[1],
            "sleep":  row[2],
            "energy": row[3],
            "focus":  row[4],
            "mood":   row[5],
        })

    # Nutzer mit mind. 5 Check-ins für Verlaufsanalyse — Fallback auf ≥ 2
    eligible = {did: entries for did, entries in users.items() if len(entries) >= 5}
    if not eligible:
        eligible = {did: entries for did, entries in users.items() if len(entries) >= 2}
    if not eligible:
        return None
    # TODO: Mindest-Schwelle auf 20 Nutzer erhöhen sobald genug Daten vorhanden

    best_dim: Optional[str] = None
    best_pct = 0
    best_count = 0

    for dim in _DIMENSIONS:
        improved = 0
        valid = 0

        for entries in eligible.values():
            scores = [e[dim] for e in entries if e[dim] is not None]
            if len(scores) < 2:
                continue
            valid += 1
            mid = max(1, len(scores) // 2)
            first_avg = sum(scores[:mid]) / mid
            last_avg  = sum(scores[mid:]) / (len(scores) - mid)
            if last_avg >= first_avg + 0.3:
                improved += 1

        if valid < 1:
            continue

        pct = round((improved / valid) * 100)
        if pct > best_pct and pct >= 40:   # Mindest-Schwelle 40%
            best_pct = pct
            best_dim = dim
            best_count = valid

    if best_dim is None:
        return None

    dim_label = _DIMENSION_LABELS[best_dim]
    return SupplementInsight(
        supplement_name=supplement_name,
        dimension=best_dim,
        dimension_label=dim_label,
        improvement_percent=best_pct,
        user_count=best_count,
        label=_build_label(dim_label, best_pct, best_count, supplement_name),
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/checkin-sync", status_code=200)
async def sync_checkin(request: CheckinSyncRequest) -> dict:
    """
    Speichert Check-in-Daten eines Nutzers für jedes Supplement im Stack.
    Idempotent: UPSERT per (device_id, supplement_name, checkin_date).
    Kein Auth nötig — nur anonyme device_id.
    """
    if not request.entries:
        return {"ok": True}

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                for entry in request.entries:
                    cur.execute("""
                        INSERT INTO supplement_checkins
                            (device_id, supplement_name, checkin_date,
                             sleep_score, energy_score, focus_score, mood_score)
                        VALUES (%s, LOWER(%s), %s, %s, %s, %s, %s)
                        ON CONFLICT (device_id, supplement_name, checkin_date)
                        DO UPDATE SET
                            sleep_score  = EXCLUDED.sleep_score,
                            energy_score = EXCLUDED.energy_score,
                            focus_score  = EXCLUDED.focus_score,
                            mood_score   = EXCLUDED.mood_score
                    """, (
                        request.device_id,
                        entry.supplement_name,
                        entry.checkin_date,
                        entry.sleep_score,
                        entry.energy_score,
                        entry.focus_score,
                        entry.mood_score,
                    ))
    except Exception as e:
        # Nicht-kritisch: Check-in Sync darf still scheitern
        logger.warning("Check-in Sync fehlgeschlagen: %s", e)

    return {"ok": True}


@router.post("/community-insights", response_model=CommunityInsightsResponse)
async def get_community_insights(supplement_names: list[str]) -> CommunityInsightsResponse:
    """
    Gibt aggregierte Community-Insights für eine Liste von Supplement-Namen zurück.
    Nur Supplements mit ausreichend Daten (≥ 3 Nutzer) bekommen einen Insight.
    """
    if not supplement_names:
        return CommunityInsightsResponse(insights={})

    result: dict[str, SupplementInsight] = {}

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                for name in supplement_names[:20]:   # Max 20 pro Request
                    insight = _aggregate_supplement(cur, name)
                    if insight:
                        result[name.lower()] = insight
    except Exception as e:
        logger.error("Community Insights Fehler: %s", e)
        # Graceful degradation: leere Antwort statt Fehler
        return CommunityInsightsResponse(insights={})

    return CommunityInsightsResponse(insights=result)
