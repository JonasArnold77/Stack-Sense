"""
RevenueCat-Webhook — kreditiert Tokens nach einem verifizierten Apple/Google-Kauf.

RevenueCat übernimmt die eigentliche Beleg-Prüfung (StoreKit/Play Billing)
und schickt uns bei jedem Kaufereignis einen serverseitigen Webhook. Wir
vertrauen NUR Requests mit dem korrekten Authorization-Header (selbst
gewähltes Secret, identisch im RevenueCat-Dashboard hinterlegt) und schützen
uns zusätzlich per DB-Unique-Constraint gegen erneut zugestellte Webhooks
(siehe token_purchase_repository.record_purchase).
"""
import logging

from fastapi import APIRouter, Header, HTTPException, Request, status

from config.settings import settings
from database.token_purchase_repository import record_purchase
from database.token_repository import add_tokens
from database.user_repository import get_user_by_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/revenuecat", tags=["Purchases"])

# Produkt-ID -> Token-Menge. Muss 1:1 den in App Store Connect / Play Console
# angelegten Verbrauchsgüter-IDs entsprechen (siehe Flutter: purchase_provider.dart).
_PRODUCT_TOKEN_AMOUNTS = {
    "tokens_pack_s": 10_000,
    "tokens_pack_m": 50_000,
    "tokens_pack_l": 150_000,
}

# Consumables lösen bei RevenueCat diese Event-Typen aus — alle anderen
# (Renewals, Cancellations, Refunds etc.) betreffen Abos, nicht unsere
# Einmal-Käufe, und werden ignoriert.
_CREDIT_EVENT_TYPES = {"INITIAL_PURCHASE", "NON_RENEWING_PURCHASE"}


@router.post("/webhook")
async def revenuecat_webhook(request: Request, authorization: str | None = Header(None)):
    if not settings.revenuecat_webhook_secret or authorization != f"Bearer {settings.revenuecat_webhook_secret}":
        logger.warning("RevenueCat-Webhook mit ungültigem Authorization-Header abgelehnt")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    body = await request.json()
    event = body.get("event", {})
    event_type = event.get("type")
    if event_type not in _CREDIT_EVENT_TYPES:
        return {"ok": True}

    product_id = event.get("product_id", "")
    amount = _PRODUCT_TOKEN_AMOUNTS.get(product_id)
    event_id = event.get("id")
    app_user_id = event.get("app_user_id", "")

    if not amount or not event_id or not app_user_id:
        logger.warning(f"RevenueCat-Webhook unvollständig ignoriert: {body}")
        return {"ok": True}

    try:
        user = get_user_by_id(app_user_id)
    except Exception as e:
        logger.warning(f"RevenueCat-Webhook: app_user_id '{app_user_id}' ungültig: {e}")
        return {"ok": True}

    if user is None:
        logger.warning(f"RevenueCat-Webhook: kein User für app_user_id '{app_user_id}' gefunden")
        return {"ok": True}

    if record_purchase(user.id, product_id, event_id, amount):
        add_tokens(user.id, amount)
        logger.info(f"Kauf gutgeschrieben: user={user.id} product={product_id} tokens={amount}")
    else:
        logger.info(f"RevenueCat-Webhook-Duplikat ignoriert: event_id={event_id}")

    return {"ok": True}
