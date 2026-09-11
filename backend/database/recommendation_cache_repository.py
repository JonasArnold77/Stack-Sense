"""
Empfehlungscache — geteilte Postgres-Tabelle statt In-Memory-Dict (siehe
init_recommendation_cache_table() in database/db.py für die Begründung).
Reine, synchrone psycopg2-Funktionen — Aufrufer (services/claude_service.py)
lagern sie via asyncio.to_thread aus, damit sie den Event-Loop nicht blockieren.
"""
import logging

from .db import get_conn

logger = logging.getLogger(__name__)


def get_cached(key: str, ttl_seconds: int) -> str | None:
    """Gibt den gespeicherten JSON-Wert zurück, wenn er innerhalb der TTL liegt."""
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT value FROM recommendation_cache "
                    "WHERE cache_key = %s "
                    "AND created_at > NOW() - make_interval(secs => %s)",
                    (key, ttl_seconds),
                )
                row = cur.fetchone()
        return row[0] if row else None
    except Exception as e:
        logger.warning("Cache-Lookup fehlgeschlagen (wird als Miss behandelt): %s", e)
        return None


def set_cached(key: str, value: str) -> None:
    """Schreibt/aktualisiert einen Cache-Eintrag und räumt nebenbei alte Einträge
    auf (kein separater Cronjob nötig — die Tabelle bleibt dadurch klein)."""
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO recommendation_cache (cache_key, value, created_at) "
                    "VALUES (%s, %s, NOW()) "
                    "ON CONFLICT (cache_key) DO UPDATE "
                    "SET value = EXCLUDED.value, created_at = EXCLUDED.created_at",
                    (key, value),
                )
                cur.execute(
                    "DELETE FROM recommendation_cache "
                    "WHERE created_at < NOW() - INTERVAL '24 hours'"
                )
    except Exception as e:
        logger.warning("Cache-Schreiben fehlgeschlagen (Antwort bleibt gültig, nur nicht gecacht): %s", e)
