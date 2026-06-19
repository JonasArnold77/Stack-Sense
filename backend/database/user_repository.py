"""
User Repository — alle DB-Operationen für users + user_profiles.
Kein ORM, direktes psycopg2 für Konsistenz mit dem restlichen Code.
"""
import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

from database.db import get_conn

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Datenklassen (wie Dart-Models auf Python-Seite)
# ---------------------------------------------------------------------------

@dataclass
class UserRow:
    id: str
    cognito_sub: str
    email: str
    role: str              # 'user' | 'admin'
    created_at: datetime
    last_login_at: Optional[datetime]


@dataclass
class UserProfileRow:
    user_id: str
    age: Optional[int]
    gender: Optional[str]
    sport_level: Optional[str]
    conditions: list[str]
    medications: list[str]
    is_pregnant: bool
    updated_at: datetime


# ---------------------------------------------------------------------------
# User CRUD
# ---------------------------------------------------------------------------

def upsert_user(cognito_sub: str, email: str) -> UserRow:
    """
    Legt einen User an oder aktualisiert last_login_at.
    Gibt den aktuellen User-Datensatz zurück.
    """
    sql = """
    INSERT INTO users (cognito_sub, email)
    VALUES (%s, %s)
    ON CONFLICT (cognito_sub) DO UPDATE
        SET last_login_at = NOW(),
            email = EXCLUDED.email
    RETURNING id, cognito_sub, email, role, created_at, last_login_at
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (cognito_sub, email))
            row = cur.fetchone()
    return UserRow(
        id=str(row[0]),
        cognito_sub=row[1],
        email=row[2],
        role=row[3],
        created_at=row[4],
        last_login_at=row[5],
    )


def get_user_by_sub(cognito_sub: str) -> Optional[UserRow]:
    """Sucht einen User anhand des Cognito Sub-Feldes."""
    sql = """
    SELECT id, cognito_sub, email, role, created_at, last_login_at
    FROM users WHERE cognito_sub = %s
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (cognito_sub,))
            row = cur.fetchone()
    if row is None:
        return None
    return UserRow(
        id=str(row[0]),
        cognito_sub=row[1],
        email=row[2],
        role=row[3],
        created_at=row[4],
        last_login_at=row[5],
    )


def list_all_users() -> list[UserRow]:
    """Gibt alle User zurück (nur für Admin-Endpoints)."""
    sql = """
    SELECT id, cognito_sub, email, role, created_at, last_login_at
    FROM users ORDER BY created_at DESC
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [
        UserRow(
            id=str(r[0]), cognito_sub=r[1], email=r[2],
            role=r[3], created_at=r[4], last_login_at=r[5],
        )
        for r in rows
    ]


def set_user_role(user_id: str, role: str) -> None:
    """Ändert die Rolle eines Users (nur Admin darf das)."""
    assert role in ("user", "admin"), "Ungültige Rolle"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE users SET role = %s WHERE id = %s",
                (role, user_id),
            )


# ---------------------------------------------------------------------------
# UserProfile CRUD
# ---------------------------------------------------------------------------

def get_profile(user_id: str) -> Optional[UserProfileRow]:
    """Lädt das Profil eines Users."""
    sql = """
    SELECT user_id, age, gender, sport_level, conditions, medications,
           is_pregnant, updated_at
    FROM user_profiles WHERE user_id = %s
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (user_id,))
            row = cur.fetchone()
    if row is None:
        return None
    return UserProfileRow(
        user_id=str(row[0]),
        age=row[1],
        gender=row[2],
        sport_level=row[3],
        conditions=list(row[4] or []),
        medications=list(row[5] or []),
        is_pregnant=row[6],
        updated_at=row[7],
    )


def upsert_profile(
    user_id: str,
    age: Optional[int],
    gender: Optional[str],
    sport_level: Optional[str],
    conditions: list[str],
    medications: list[str],
    is_pregnant: bool,
) -> UserProfileRow:
    """Legt ein Profil an oder aktualisiert es vollständig."""
    sql = """
    INSERT INTO user_profiles
        (user_id, age, gender, sport_level, conditions, medications, is_pregnant, updated_at)
    VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        age         = EXCLUDED.age,
        gender      = EXCLUDED.gender,
        sport_level = EXCLUDED.sport_level,
        conditions  = EXCLUDED.conditions,
        medications = EXCLUDED.medications,
        is_pregnant = EXCLUDED.is_pregnant,
        updated_at  = NOW()
    RETURNING user_id, age, gender, sport_level, conditions, medications,
              is_pregnant, updated_at
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                sql,
                (user_id, age, gender, sport_level, conditions, medications, is_pregnant),
            )
            row = cur.fetchone()
    return UserProfileRow(
        user_id=str(row[0]),
        age=row[1],
        gender=row[2],
        sport_level=row[3],
        conditions=list(row[4] or []),
        medications=list(row[5] or []),
        is_pregnant=row[6],
        updated_at=row[7],
    )
