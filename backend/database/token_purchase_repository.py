"""
Ledger echter Token-Käufe (RevenueCat-Webhook).
Kein ORM, direktes psycopg2 für Konsistenz mit dem restlichen Code.
"""
import logging

from database.db import get_conn

logger = logging.getLogger(__name__)


def record_purchase(user_id: str, product_id: str, event_id: str, tokens: int) -> bool:
    """
    Trägt einen Kauf ins Ledger ein. Gibt True zurück wenn es ein NEUER
    Eintrag war (→ Tokens gutschreiben), False bei einem Duplikat (gleiche
    revenuecat_event_id bereits vorhanden → RevenueCat hat den Webhook
    erneut zugestellt, NICHT nochmal gutschreiben).
    """
    sql = """
    INSERT INTO token_purchases (user_id, product_id, revenuecat_event_id, tokens_credited)
    VALUES (%s, %s, %s, %s)
    ON CONFLICT (revenuecat_event_id) DO NOTHING
    RETURNING id
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (user_id, product_id, event_id, tokens))
            row = cur.fetchone()
    return row is not None
