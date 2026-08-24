"""
Tenant Repository — alle DB-Operationen für Multi-Tenancy (tenants +
users.tenant_id). Kein ORM, direktes psycopg2 für Konsistenz mit
user_repository.py.
"""
import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

from psycopg2.extras import Json

from database.db import get_conn

logger = logging.getLogger(__name__)


@dataclass
class TenantRow:
    id: str
    name: str
    features: dict
    branding: dict
    is_active: bool
    created_at: datetime
    updated_at: datetime


def _row_to_tenant(row) -> TenantRow:
    return TenantRow(
        id=row[0], name=row[1], features=row[2] or {}, branding=row[3] or {},
        is_active=row[4], created_at=row[5], updated_at=row[6],
    )


def create_tenant(id: str, name: str, features: dict, branding: dict) -> TenantRow:
    sql = """
    INSERT INTO tenants (id, name, features, branding)
    VALUES (%s, %s, %s, %s)
    RETURNING id, name, features, branding, is_active, created_at, updated_at
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (id, name, Json(features), Json(branding)))
            row = cur.fetchone()
    return _row_to_tenant(row)


def list_tenants() -> list[TenantRow]:
    sql = """
    SELECT id, name, features, branding, is_active, created_at, updated_at
    FROM tenants ORDER BY created_at DESC
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [_row_to_tenant(r) for r in rows]


def get_tenant(id: str) -> Optional[TenantRow]:
    sql = """
    SELECT id, name, features, branding, is_active, created_at, updated_at
    FROM tenants WHERE id = %s
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (id,))
            row = cur.fetchone()
    if row is None:
        return None
    return _row_to_tenant(row)


def update_tenant(id: str, name: str, features: dict, branding: dict) -> Optional[TenantRow]:
    sql = """
    UPDATE tenants
    SET name = %s, features = %s, branding = %s, updated_at = NOW()
    WHERE id = %s
    RETURNING id, name, features, branding, is_active, created_at, updated_at
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (name, Json(features), Json(branding), id))
            row = cur.fetchone()
    if row is None:
        return None
    return _row_to_tenant(row)


def set_tenant_active(id: str, active: bool) -> None:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE tenants SET is_active = %s, updated_at = NOW() WHERE id = %s",
                (active, id),
            )


def assign_user_tenant(user_id: str, tenant_id: Optional[str]) -> None:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE users SET tenant_id = %s WHERE id = %s",
                (tenant_id, user_id),
            )
