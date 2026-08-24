"""
Admin-Tenant-Router — Multi-Tenancy-Verwaltung (nur Admin).

Endpunkte:
  GET  /admin/tenants                — alle Tenants auflisten
  POST /admin/tenants                — neuen Tenant anlegen (inaktiv)
  PUT  /admin/tenants/{id}           — Name/Features/Branding bearbeiten
  POST /admin/tenants/{id}/publish   — Tenant aktivieren (sofort live für alle
                                        zugewiesenen Nutzer, kein neuer App-Build)
  POST /admin/tenants/{id}/unpublish — Tenant deaktivieren
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from database.tenant_repository import (
    TenantRow,
    create_tenant,
    get_tenant,
    list_tenants,
    set_tenant_active,
    update_tenant,
)
from database.user_repository import UserRow
from middleware.auth import require_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/admin/tenants", tags=["Admin — Tenants"])


class TenantRequest(BaseModel):
    id: str
    name: str
    features: dict = {}
    branding: dict = {}


class TenantUpdateRequest(BaseModel):
    name: str
    features: dict = {}
    branding: dict = {}


class TenantResponse(BaseModel):
    id: str
    name: str
    features: dict
    branding: dict
    is_active: bool


def _to_response(t: TenantRow) -> TenantResponse:
    return TenantResponse(
        id=t.id, name=t.name, features=t.features, branding=t.branding,
        is_active=t.is_active,
    )


@router.get("", response_model=list[TenantResponse], summary="Alle Tenants auflisten")
async def get_tenants(_admin: UserRow = Depends(require_admin)):
    return [_to_response(t) for t in list_tenants()]


@router.post("", response_model=TenantResponse, summary="Neuen Tenant anlegen")
async def create_new_tenant(
    body: TenantRequest,
    _admin: UserRow = Depends(require_admin),
):
    if get_tenant(body.id) is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Tenant '{body.id}' existiert bereits",
        )
    try:
        tenant = create_tenant(body.id, body.name, body.features, body.branding)
    except Exception as e:
        logger.error("Tenant anlegen fehlgeschlagen: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Tenant konnte nicht angelegt werden",
        )
    return _to_response(tenant)


@router.put("/{tenant_id}", response_model=TenantResponse, summary="Tenant bearbeiten")
async def edit_tenant(
    tenant_id: str,
    body: TenantUpdateRequest,
    _admin: UserRow = Depends(require_admin),
):
    tenant = update_tenant(tenant_id, body.name, body.features, body.branding)
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant nicht gefunden")
    return _to_response(tenant)


@router.post("/{tenant_id}/publish", summary="Tenant veröffentlichen (sofort live)")
async def publish_tenant(tenant_id: str, _admin: UserRow = Depends(require_admin)):
    if get_tenant(tenant_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant nicht gefunden")
    set_tenant_active(tenant_id, True)
    return {"ok": True, "tenant_id": tenant_id, "is_active": True}


@router.post("/{tenant_id}/unpublish", summary="Tenant deaktivieren")
async def unpublish_tenant(tenant_id: str, _admin: UserRow = Depends(require_admin)):
    if get_tenant(tenant_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant nicht gefunden")
    set_tenant_active(tenant_id, False)
    return {"ok": True, "tenant_id": tenant_id, "is_active": False}
