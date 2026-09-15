"""
Token-Repository — Guthaben-Änderungen auf users.token_balance.
Kein ORM, direktes psycopg2 für Konsistenz mit dem restlichen Code.
"""
import logging

from database.db import get_conn

logger = logging.getLogger(__name__)


def deduct_tokens(user_id: str, amount: int) -> int:
    """Zieht `amount` Tokens vom Guthaben ab. Darf unter 0 fallen (die eine
    Anfrage, die das Konto überzieht, war ja noch erlaubt, da vorher > 0)."""
    sql = "UPDATE users SET token_balance = token_balance - %s WHERE id = %s RETURNING token_balance"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (amount, user_id))
            row = cur.fetchone()
    return row[0]


def add_tokens(user_id: str, amount: int) -> int:
    """Lädt `amount` Tokens aufs Guthaben — aktuell nur für den kostenlosen
    Test-Aufladen-Stub (kein echtes Payment)."""
    sql = "UPDATE users SET token_balance = token_balance + %s WHERE id = %s RETURNING token_balance"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (amount, user_id))
            row = cur.fetchone()
    return row[0]
