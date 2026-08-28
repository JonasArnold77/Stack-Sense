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


def init_checkin_tables() -> None:
    """
    Erstellt die Tabellen für problemfeld-spezifische Tages-Check-ins.

    checkin_questions — statische Fragen pro Problemfeld (einmalig befüllt).
    daily_checkins    — tägliche Antworten pro (device_id, question_id, date).
    """
    create_sql = """
    -- Fragen pro Problemfeld
    CREATE TABLE IF NOT EXISTS checkin_questions (
        id               SERIAL PRIMARY KEY,
        problem_field_id TEXT   NOT NULL,   -- z.B. "Schlaf", "Energie"
        question_text    TEXT   NOT NULL,
        sort_order       SMALLINT NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_cq_field ON checkin_questions(problem_field_id);

    -- Tägliche Antworten (device_id = anonyme Geräte-UUID, kein Personenbezug)
    CREATE TABLE IF NOT EXISTS daily_checkins (
        id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        device_id    TEXT     NOT NULL,
        problem_field_id TEXT NOT NULL,
        question_id  INT      NOT NULL REFERENCES checkin_questions(id),
        score        SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
        date         DATE     NOT NULL,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (device_id, question_id, date)
    );
    CREATE INDEX IF NOT EXISTS idx_dc_device_field ON daily_checkins(device_id, problem_field_id);
    CREATE INDEX IF NOT EXISTS idx_dc_date         ON daily_checkins(date);
    """

    seed_sql = """
    INSERT INTO checkin_questions (problem_field_id, question_text, sort_order)
    SELECT v.field, v.text, v.ord
    FROM (VALUES
        ('Schlaf',      'Wie gut hast du geschlafen?',                      0),
        ('Schlaf',      'Wie lange hat das Einschlafen gedauert?',          1),
        ('Schlaf',      'Wie erholt hast du dich beim Aufwachen gefühlt?', 2),
        ('Schlaf',      'Wie war deine Energie am Vormittag?',              3),
        ('Energie',     'Wie war dein Energielevel heute?',                 0),
        ('Energie',     'Wie gut konntest du körperliche Aufgaben erfüllen?', 1),
        ('Energie',     'Hattest du einen Nachmittagstief?',                2),
        ('Energie',     'Wie erholt fühlst du dich insgesamt?',             3),
        ('Fokus',       'Wie gut konntest du dich konzentrieren?',          0),
        ('Fokus',       'Wie klar war dein Denken heute?',                  1),
        ('Fokus',       'Wie gut hast du Aufgaben zu Ende gebracht?',       2),
        ('Fokus',       'Wie war deine mentale Ausdauer?',                  3),
        ('Stimmung',    'Wie war deine allgemeine Stimmung heute?',         0),
        ('Stimmung',    'Wie motiviert hast du dich gefühlt?',              1),
        ('Stimmung',    'Wie gut konntest du mit Stress umgehen?',          2),
        ('Stimmung',    'Wie positiv war dein Ausblick auf den Tag?',       3),
        ('Sport',       'Wie war deine körperliche Leistung?',              0),
        ('Sport',       'Wie gut war deine Ausdauer?',                      1),
        ('Sport',       'Wie schnell hast du dich erholt?',                 2),
        ('Sport',       'Wie hoch war deine Motivation?',                   3),
        ('Immunsystem', 'Wie wohl hast du dich körperlich gefühlt?',        0),
        ('Immunsystem', 'Hattest du Anzeichen von Erkältung oder Unwohlsein?', 1),
        ('Immunsystem', 'Wie war deine allgemeine Widerstandsfähigkeit?',   2),
        ('Immunsystem', 'Wie gut hast du auf Stress reagiert?',             3),
        ('Verdauung',   'Wie gut war deine Verdauung heute?',               0),
        ('Verdauung',   'Hattest du Beschwerden nach dem Essen?',           1),
        ('Verdauung',   'Wie war dein Hunger- und Sättigungsgefühl?',       2),
        ('Verdauung',   'Wie war dein Energielevel nach den Mahlzeiten?',   3)
    ) AS v(field, text, ord)
    WHERE NOT EXISTS (SELECT 1 FROM checkin_questions LIMIT 1);
    """

    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(create_sql)
                cur.execute(seed_sql)
        logger.info("Check-in-Tabellen bereit.")
    except Exception as e:
        logger.warning("Check-in-Tabellen konnten nicht initialisiert werden: %s", e)


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


def init_tenant_tables() -> None:
    """
    Erstellt die tenants-Tabelle (Multi-Tenancy: Parteien mit eigenem
    Feature-/Branding-Konfiguration) und die tenant_id-Spalte auf users.
    Ein NULL tenant_id bedeutet unverändertes Standardverhalten (LifeLab).
    """
    create_sql = """
    CREATE TABLE IF NOT EXISTS tenants (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        features    JSONB NOT NULL DEFAULT '{}',
        branding    JSONB NOT NULL DEFAULT '{}',
        is_active   BOOLEAN NOT NULL DEFAULT FALSE,
        created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

    ALTER TABLE users ADD COLUMN IF NOT EXISTS tenant_id TEXT REFERENCES tenants(id);
    CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
    """
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(create_sql)
        logger.info("Tenant-Tabellen bereit.")
    except Exception as e:
        logger.warning("Tenant-Tabellen konnten nicht initialisiert werden: %s", e)


def init_recipe_tables() -> None:
    """
    Erstellt die Nährstoff-Infrastruktur für das Rezept-Feature:
    - fdc_ingredient_cache: Cache für USDA-FoodData-Central-Lookups pro Zutat,
      verhindert wiederholte Live-API-Calls bei jeder Rezeptgenerierung.
    - supplement_nutrients: kuratierte (nicht LLM-generierte) Referenzwerte,
      welcher Nährstoff in welcher Menge/Einheit in einem Supplement steckt.
    """
    create_sql = """
    CREATE TABLE IF NOT EXISTS fdc_ingredient_cache (
        id              SERIAL PRIMARY KEY,
        query_norm      TEXT UNIQUE NOT NULL,
        fdc_id          INTEGER,
        fdc_description TEXT,
        nutrients_json  JSONB NOT NULL,
        source          TEXT NOT NULL DEFAULT 'fdc',
        fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_fdc_cache_query ON fdc_ingredient_cache(query_norm);

    CREATE TABLE IF NOT EXISTS supplement_nutrients (
        id              SERIAL PRIMARY KEY,
        supplement_slug TEXT NOT NULL,
        nutrient_key    TEXT NOT NULL,
        amount          NUMERIC NOT NULL,
        unit            TEXT NOT NULL,
        source_note     TEXT,
        UNIQUE(supplement_slug, nutrient_key)
    );
    CREATE INDEX IF NOT EXISTS idx_suppl_nutrients_slug ON supplement_nutrients(supplement_slug);
    """
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(create_sql)
        logger.info("Rezept-Nährstoff-Tabellen bereit.")
    except Exception as e:
        logger.warning("Rezept-Nährstoff-Tabellen konnten nicht initialisiert werden: %s", e)
