"""
Admin-Upgrade-Router — löst den "Upgrade"-GitHub-Actions-Workflow aus
(.github/workflows/upgrade.yml: APK bauen + nach Google Drive hochladen,
Backend deployen). Der GitHub-Token bleibt serverseitig — die Admin-Seite
bekommt ihn nie zu Gesicht, anders als der Cognito-Login läuft dieser Call
nicht direkt vom Browser aus.
"""
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from config.settings import settings
from database.user_repository import UserRow
from middleware.auth import require_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/admin", tags=["Admin — Upgrade"])

_WORKFLOW_FILE = "upgrade.yml"


@router.post("/upgrade", summary="APK-Build + Backend-Deploy auslösen (nur Admin)")
async def trigger_upgrade(_admin: UserRow = Depends(require_admin)):
    if not settings.github_token:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GITHUB_TOKEN ist nicht konfiguriert — Upgrade-Workflow kann nicht ausgelöst werden.",
        )

    url = f"https://api.github.com/repos/{settings.github_repo}/actions/workflows/{_WORKFLOW_FILE}/dispatches"
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {settings.github_token}",
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                },
                json={"ref": "main"},
                timeout=15.0,
            )
    except Exception as e:
        logger.error("Upgrade-Dispatch fehlgeschlagen: %s", e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="GitHub konnte nicht erreicht werden.",
        )

    if resp.status_code != 204:
        logger.error("GitHub-Dispatch antwortete mit %s: %s", resp.status_code, resp.text)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"GitHub hat den Workflow-Start abgelehnt (HTTP {resp.status_code}).",
        )

    return {
        "ok": True,
        "actions_url": f"https://github.com/{settings.github_repo}/actions",
    }
