"""
Datenbank-Verbindung — psycopg2 Connection Pool.
Wird von user_repository.py und vector_service.py genutzt.
"""
import logging
from contextlib import contextmanager
from typing import Generator

import psycopg2
from psycopg2 import pool as pg_pool

from config.settings import settings

logger = logging.getLogger(__name__)

_pool: pg_pool.ThreadedConnectionPool | None = None


def get_pool() -> pg_pool.ThreadedConnectionPool:
    """Gibt den globalen Connection-Pool zurück, erstellt ihn bei Bedarf."""
    global _pool
    if _pool is None:
        try:
            _pool = pg_pool.ThreadedConnectionPool(
                minconn=1,
                maxconn=10,
                host=settings.db_host,
                port=settings.db_port,
                dbname=settings.db_name,
                user=settings.db_user,
                password=settings.db_pass,
                connect_timeout=5,
                sslmode="require",
            )
            logger.info("PostgreSQL Connection-Pool erstellt (%s)", settings.db_host)
        except Exception as e:
            logger.warning("DB-Pool konnte nicht erstellt werden: %s", e)
            raise
    return _pool


@contextmanager
def get_conn() -> Generator:
    """Context-Manager: holt eine Verbindung aus dem Pool und gibt sie zurück."""
    conn = None
    try:
        conn = get_pool().getconn()
        yield conn
        conn.commit()
    except Exception:
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            get_pool().putconn(conn)


def init_user_tables() -> None:
    """
    Erstellt die users- und user_profiles-Tabellen falls nicht vorhanden.
    Wird einmalig beim App-Start aufgerufen.
    """
    create_sql = """
    -- Nutzer-Tabelle: verknüpft Cognito-Sub mit Rolle
    CREATE TABLE IF NOT EXISTS users (
        id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        cognito_sub    TEXT UNIQUE NOT NULL,
        email          TEXT UNIQUE NOT NULL,
        role           TEXT NOT NULL DEFAULT 'user',   -- 'user' | 'admin'
        created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        last_login_at  TIMESTAMPTZ
    );

    CREATE INDEX IF NOT EXISTS idx_users_cognito_sub ON users(cognito_sub);
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

    -- Nutzerprofil-Tabelle: Onboarding-Daten in der Cloud
    CREATE TABLE IF NOT EXISTS user_profiles (
        user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        age            INT,
        gender         TEXT,          -- 'male' | 'female' | 'diverse'
        sport_level    TEXT,          -- 'none' | 'light' | 'moderate' | 'intense'
        conditions     TEXT[] DEFAULT '{}',
        medications    TEXT[] DEFAULT '{}',
        is_pregnant    BOOLEAN NOT NULL DEFAULT FALSE,
        updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(create_sql)
        logger.info("User-Tabellen bereit.")
    except Exception as e:
        logger.warning("User-Tabellen konnten nicht initialisiert werden: %s", e)


def init_community_tables() -> None:
    """
    Erstellt die supplement_checkins-Tabelle für anonyme Community-Insights.
    Speichert Check-in-Daten pro (anonymer Nutzer, Supplement, Tag).
    Kein personenbezogenes Datum — nur device_id (UUID, lokal generiert).
    """
    create_sql = """
    CREATE TABLE IF NOT EXISTS supplement_checkins (
        id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        device_id       TEXT NOT NULL,            -- anonyme Geräte-UUID
        supplement_name TEXT NOT NULL,            -- normalisierter Name (lowercase)
        checkin_date    DATE NOT NULL,
        sleep_score     SMALLINT CHECK (sleep_score BETWEEN 1 AND 5),
        energy_score    SMALLINT CHECK (energy_score BETWEEN 1 AND 5),
        focus_score     SMALLINT CHECK (focus_score BETWEEN 1 AND 5),
        mood_score      SMALLINT CHECK (mood_score BETWEEN 1 AND 5),
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (device_id, supplement_name, checkin_date)
    );

    CREATE INDEX IF NOT EXISTS idx_sc_supplement ON supplement_checkins(supplement_name);
    CREATE INDEX IF NOT EXISTS idx_sc_device     ON supplement_checkins(device_id);
    CREATE INDEX IF NOT EXISTS idx_sc_date       ON supplement_checkins(checkin_date);
    """
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(create_sql)
        logger.info("Community-Tabellen bereit.")
    except Exception as e:
        logger.warning("Community-Tabellen konnten nicht initialisiert werden: %s", e)
