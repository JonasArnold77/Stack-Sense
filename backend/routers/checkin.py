"""
Check-in Router — problemfeld-spezifische Tages-Check-ins.

Endpunkte:
  GET  /api/v1/checkins/questions/{problem_field_id}  — Fragen für ein Problemfeld
  POST /api/v1/checkins/submit                        — Antworten eines Tages speichern
  GET  /api/v1/checkins/history/{problem_field_id}    — Verlauf der letzten 30 Tage
"""
import logging
from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from database.db import get_conn

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/checkins", tags=["Check-ins"])


# ─────────────────────────────────────────────────────────────────────────────
# Pydantic Schemas
# ─────────────────────────────────────────────────────────────────────────────

class CheckinQuestion(BaseModel):
    id: int
    problem_field_id: str
    question_text: str
    sort_order: int


class CheckinAnswer(BaseModel):
    question_id: int = Field(..., ge=1)
    score: int = Field(..., ge=1, le=5)


class CheckinSubmitRequest(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=128)
    problem_field_id: str = Field(..., min_length=1, max_length=64)
    date: date
    answers: list[CheckinAnswer]


class CheckinSubmitResponse(BaseModel):
    saved: int          # Anzahl gespeicherter Antworten
    skipped: int        # Duplikate (bereits eingereicht)


class DayAggregate(BaseModel):
    """Tages-Aggregat: Durchschnittsscore über alle Fragen des Problemfelds."""
    date: date
    avg_score: float    # 1.0–5.0
    question_scores: dict[int, int]  # question_id → score


class HistoryResponse(BaseModel):
    problem_field_id: str
    days: list[DayAggregate]


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/checkins/questions/{problem_field_id}
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/questions/{problem_field_id}", response_model=list[CheckinQuestion])
def get_questions(problem_field_id: str) -> list[CheckinQuestion]:
    """
    Gibt die Fragen für ein Problemfeld zurück, sortiert nach sort_order.
    Liefert eine leere Liste wenn das Problemfeld unbekannt ist.
    """
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT id, problem_field_id, question_text, sort_order
                    FROM checkin_questions
                    WHERE problem_field_id = %s
                    ORDER BY sort_order
                    """,
                    (problem_field_id,),
                )
                rows = cur.fetchall()
    except Exception as e:
        logger.error("Fehler beim Abrufen der Fragen für '%s': %s", problem_field_id, e)
        raise HTTPException(status_code=500, detail="Datenbankfehler")

    return [
        CheckinQuestion(
            id=row[0],
            problem_field_id=row[1],
            question_text=row[2],
            sort_order=row[3],
        )
        for row in rows
    ]


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/checkins/submit
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/submit", response_model=CheckinSubmitResponse)
def submit_checkin(req: CheckinSubmitRequest) -> CheckinSubmitResponse:
    """
    Speichert die Antworten eines Tages für ein Problemfeld.
    Duplikate (gleiche device_id + question_id + date) werden übersprungen
    — kein Fehler, aber auch keine Überschreibung.
    """
    if not req.answers:
        return CheckinSubmitResponse(saved=0, skipped=0)

    saved = 0
    skipped = 0

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                for answer in req.answers:
                    # INSERT … ON CONFLICT DO NOTHING = idempotent
                    cur.execute(
                        """
                        INSERT INTO daily_checkins
                            (device_id, problem_field_id, question_id, score, date)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (device_id, question_id, date) DO NOTHING
                        """,
                        (
                            req.device_id,
                            req.problem_field_id,
                            answer.question_id,
                            answer.score,
                            req.date,
                        ),
                    )
                    if cur.rowcount > 0:
                        saved += 1
                    else:
                        skipped += 1

    except Exception as e:
        logger.error(
            "Fehler beim Speichern des Check-ins (%s, %s, %s): %s",
            req.device_id, req.problem_field_id, req.date, e,
        )
        raise HTTPException(status_code=500, detail="Datenbankfehler beim Speichern")

    logger.info(
        "Check-in gespeichert: device=%s field=%s date=%s saved=%d skipped=%d",
        req.device_id[:8] + "…",
        req.problem_field_id,
        req.date,
        saved,
        skipped,
    )
    return CheckinSubmitResponse(saved=saved, skipped=skipped)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/checkins/history/{problem_field_id}
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/history/{problem_field_id}", response_model=HistoryResponse)
def get_history(
    problem_field_id: str,
    device_id: str,
    days: Optional[int] = 30,
) -> HistoryResponse:
    """
    Gibt den Check-in-Verlauf der letzten N Tage zurück.

    Query-Parameter:
      device_id  — Pflichtfeld, anonyme Geräte-UUID
      days       — Anzahl Tage (Standard: 30, Max: 90)
    """
    if not device_id:
        raise HTTPException(status_code=400, detail="device_id erforderlich")

    days = min(max(days or 30, 1), 90)
    since = date.today() - timedelta(days=days)

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT date, question_id, score
                    FROM daily_checkins
                    WHERE device_id = %s
                      AND problem_field_id = %s
                      AND date >= %s
                    ORDER BY date, question_id
                    """,
                    (device_id, problem_field_id, since),
                )
                rows = cur.fetchall()
    except Exception as e:
        logger.error(
            "Fehler beim Abrufen des Verlaufs (%s, %s): %s",
            device_id[:8] + "…", problem_field_id, e,
        )
        raise HTTPException(status_code=500, detail="Datenbankfehler")

    # Gruppieren nach Datum
    day_map: dict[date, dict[int, int]] = {}
    for row in rows:
        d, qid, score = row[0], row[1], row[2]
        if d not in day_map:
            day_map[d] = {}
        day_map[d][qid] = score

    # Aggregieren
    result_days: list[DayAggregate] = []
    for d in sorted(day_map.keys()):
        scores = list(day_map[d].values())
        avg = sum(scores) / len(scores) if scores else 0.0
        result_days.append(DayAggregate(
            date=d,
            avg_score=round(avg, 2),
            question_scores=day_map[d],
        ))

    return HistoryResponse(
        problem_field_id=problem_field_id,
        days=result_days,
    )
