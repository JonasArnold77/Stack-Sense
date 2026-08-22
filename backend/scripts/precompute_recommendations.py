"""
Vorberechnung von Themenfeld-Ranglisten + Supplement-Zusatzfeldern.
Füllt precomputed_goal_ranking (Grundreihenfolge pro Themenfeld) und
precomputed_supplement_info (Einfach erklärt / In Lebensmitteln /
Einnahmehinweise, pro Supplement — themenfeld-unabhängig, dedupliziert).

Vorher einmalig ausführen:
    python scripts/migrate_add_precompute_tables.py

Läuft für alle 18 Themenfelder (12 Problemfelder + Basis-Supplementierung +
5 Phasenziele) x 2 Modi (KI/Datenbank) x bis zu 20 Supplements pro Themenfeld.
Das sind 36 Ranking-Calls + N x 2 Detail-/Explain-Calls (N = Anzahl
einzigartiger (Supplement, Modus)-Paare über alle Themenfelder, dedupliziert)
— läuft mehrere Minuten und kostet reale Claude-API-Kosten. Am besten im
Hintergrund laufen lassen.

Die Themenfeld-Liste MUSS synchron gehalten werden mit:
  - lib/features/recommendations/presentation/widgets/goal_tile_grid.dart (goalData)
  - lib/features/phase_goals/domain/models/phase_goal.dart (kPhaseGoalDefinitions)
(kein Cross-Language-Import möglich — bei Änderungen dort auch hier nachziehen.)

Ausführen (aus dem backend/ Ordner):
    python scripts/precompute_recommendations.py
    python scripts/precompute_recommendations.py --goals="Besserer Schlaf,Mehr Energie"   # Testlauf, nur diese Themen
"""
import asyncio
import json
import logging
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import psycopg2
import psycopg2.extras

from services.claude_service import ClaudeService, _SUPPLEMENT_DB

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

DB_CONFIG = {
    "host": "stacksense-db.chym26e8iw2p.eu-central-1.rds.amazonaws.com",
    "user": "stacksense",
    "password": "Jo790097",
    "dbname": "postgres",
    "port": 5432,
    "sslmode": "require",
}

PROBLEM_FIELDS = [
    "Mehr Energie", "Besserer Schlaf", "Fokus & Konzentration", "Sport & Regeneration",
    "Immunsystem stärken", "Stimmung & Wohlbefinden", "Herzgesundheit", "Haut & Haare",
    "Gewichtsmanagement", "Gelenkgesundheit", "Frauengesundheit / Zyklus", "Hormonbalance",
]
PHASE_GOALS = [
    "Marathon-Vorbereitung", "Prüfungsphase", "Reise & Jetlag",
    "Erkältungssaison", "Stressige Arbeitsphase",
]
ALL_GOALS = PROBLEM_FIELDS + ["Basis-Supplementierung"] + PHASE_GOALS

RANKING_LIMIT = 20
REQUEST_DELAY = 0.4


def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)


def upsert_ranking(cur, goal: str, db_only: bool, items: list[dict]) -> None:
    for item in items:
        cur.execute(
            """
            INSERT INTO precomputed_goal_ranking
                (goal, db_only, supplement_id, name, base_relevance_score)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (goal, db_only, supplement_id)
            DO UPDATE SET name = EXCLUDED.name,
                          base_relevance_score = EXCLUDED.base_relevance_score,
                          generated_at = now()
            """,
            (goal, db_only, item["id"], item["name"], item["base_relevance_score"]),
        )


def upsert_supplement_info(
    cur, supplement_id: str, db_only: bool,
    simple_explanation: str | None, food_sources: list | None,
    dosage: str | None, intake_time: str | None, intake_hint: str | None,
) -> None:
    cur.execute(
        """
        INSERT INTO precomputed_supplement_info
            (supplement_id, db_only, simple_explanation, food_sources, dosage, intake_time, intake_hint)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (supplement_id, db_only)
        DO UPDATE SET simple_explanation = EXCLUDED.simple_explanation,
                      food_sources = EXCLUDED.food_sources,
                      dosage = EXCLUDED.dosage,
                      intake_time = EXCLUDED.intake_time,
                      intake_hint = EXCLUDED.intake_hint,
                      generated_at = now()
        """,
        (
            supplement_id, db_only,
            simple_explanation,
            psycopg2.extras.Json(food_sources) if food_sources else None,
            dosage, intake_time, intake_hint,
        ),
    )


async def get_food_sources_for(claude: ClaudeService, supplement_id: str, name: str) -> list | None:
    """Gleiche Priorität wie der /food-sources-Endpoint: erst statische
    supplement_knowledge.json, nur bei unbekannten Supplements Claude-Fallback."""
    entry = _SUPPLEMENT_DB.get(supplement_id)
    if entry and entry.get("food_sources"):
        return entry["food_sources"]
    try:
        sources = await claude.get_food_sources(supplement_name=name, substance_name=None)
        return sources or None
    except Exception as e:
        logger.warning(f"  Food-Sources fehlgeschlagen für {name}: {e}")
        return None


async def main(goals: list[str]) -> None:
    claude = ClaudeService()
    conn = get_db_connection()
    conn.autocommit = False
    cur = conn.cursor()

    # ── Schritt 1: Grundranglisten für alle Themenfelder x beide Modi ──────
    # (id -> name) pro Modus, über alle Themenfelder dedupliziert.
    unique_supplements: dict[bool, dict[str, str]] = {False: {}, True: {}}

    for goal in goals:
        for db_only in (False, True):
            logger.info(f"Ranking: '{goal}' (db_only={db_only})")
            items: list[dict] = []
            try:
                items = await claude.get_goal_ranking(goal, db_only=db_only, limit=RANKING_LIMIT)
            except Exception as e:
                logger.warning(f"  Ranking fehlgeschlagen: {e}")

            if not items:
                logger.warning(f"  -> 0 Supplements (Themenfeld bleibt vorerst ungedeckt)")
                time.sleep(REQUEST_DELAY)
                continue

            for attempt in range(2):
                try:
                    upsert_ranking(cur, goal, db_only, items)
                    conn.commit()
                    break
                except psycopg2.OperationalError as e:
                    logger.warning(f"  DB-Verbindung verloren, reconnect... ({e})")
                    try:
                        conn.close()
                    except Exception:
                        pass
                    conn = get_db_connection()
                    conn.autocommit = False
                    cur = conn.cursor()

            for item in items:
                unique_supplements[db_only][item["id"]] = item["name"]
            logger.info(f"  -> {len(items)} Supplements gespeichert")
            time.sleep(REQUEST_DELAY)

    # ── Schritt 2: Zusatzfelder pro einzigartigem (Supplement, Modus)-Paar ─
    total_pairs = sum(len(v) for v in unique_supplements.values())
    logger.info(f"{total_pairs} einzigartige (Supplement, Modus)-Paare für Zusatzfelder")

    done = 0
    for db_only, supplements in unique_supplements.items():
        for supp_id, name in supplements.items():
            done += 1
            logger.info(f"[{done}/{total_pairs}] Zusatzfelder: {name} (db_only={db_only})")

            try:
                explanation = await claude.get_simple_explanation(name, None)
            except Exception as e:
                logger.warning(f"  Explain fehlgeschlagen: {e}")
                explanation = None
            time.sleep(REQUEST_DELAY)

            dosage = intake_time = intake_hint = None
            try:
                detail = await claude.get_supplement_detail(supp_id, name, db_only=db_only)
                dosage, intake_time, intake_hint = detail.dosage, detail.intake_time, detail.intake_hint
            except Exception as e:
                logger.warning(f"  Detail fehlgeschlagen: {e}")
            time.sleep(REQUEST_DELAY)

            food_sources = await get_food_sources_for(claude, supp_id, name)
            time.sleep(REQUEST_DELAY)

            for attempt in range(2):
                try:
                    upsert_supplement_info(
                        cur, supp_id, db_only,
                        simple_explanation=explanation, food_sources=food_sources,
                        dosage=dosage, intake_time=intake_time, intake_hint=intake_hint,
                    )
                    conn.commit()
                    break
                except psycopg2.OperationalError as e:
                    logger.warning(f"  DB-Verbindung verloren, reconnect... ({e})")
                    try:
                        conn.close()
                    except Exception:
                        pass
                    conn = get_db_connection()
                    conn.autocommit = False
                    cur = conn.cursor()

    cur.close()
    conn.close()
    logger.info(
        f"""
╔══════════════════════════════════════════╗
║  Vorberechnung abgeschlossen             ║
║  Themenfelder:  {len(goals):>4}                      ║
║  Supplements:   {total_pairs:>4} (Supplement,Modus)-Paare ║
╚══════════════════════════════════════════╝
"""
    )


if __name__ == "__main__":
    goals_arg = ALL_GOALS
    for arg in sys.argv[1:]:
        if arg.startswith("--goals="):
            goals_arg = [g.strip() for g in arg.split("=", 1)[1].split(",") if g.strip()]
    logger.info(f"Starte Vorberechnung für {len(goals_arg)} Themenfelder: {goals_arg}")
    asyncio.run(main(goals_arg))
