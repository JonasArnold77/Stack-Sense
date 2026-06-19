"""
User-Router — Profil lesen/schreiben + Admin-Endpunkte.

Endpunkte:
  POST /users/login     — Token validieren, User in DB anlegen/updaten
  GET  /users/me        — eigenes Profil lesen
  PUT  /users/me/profile — Profil speichern / aktualisieren
  GET  /users/all       — alle User (nur Admin)
  PUT  /users/{id}/role — Rolle ändern (nur Admin)
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from database.user_repository import (
    UserProfileRow,
    UserRow,
    get_profile,
    list_all_users,
    set_user_role,
    upsert_profile,
)
from middleware.auth import get_current_user, require_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/users", tags=["Users"])


# ---------------------------------------------------------------------------
# Request / Response Modelle
# ---------------------------------------------------------------------------

class ProfileRequest(BaseModel):
    age: Optional[int] = Field(None, ge=16, le=100)
    gender: Optional[str] = None         # 'male' | 'female' | 'diverse'
    sport_level: Optional[str] = None    # 'none' | 'light' | 'moderate' | 'intense'
    conditions: list[str] = []
    medications: list[str] = []
    is_pregnant: bool = False


class ProfileResponse(BaseModel):
    user_id: str
    age: Optional[int]
    gender: Optional[str]
    sport_level: Optional[str]
    conditions: list[str]
    medications: list[str]
    is_pregnant: bool


class UserResponse(BaseModel):
    id: str
    email: str
    role: str


class RoleRequest(BaseModel):
    role: str  # 'user' | 'admin'


# ---------------------------------------------------------------------------
# Hilfsfunktion
# ---------------------------------------------------------------------------

def _profile_to_response(p: UserProfileRow) -> ProfileResponse:
    return ProfileResponse(
        user_id=p.user_id,
        age=p.age,
        gender=p.gender,
        sport_level=p.sport_level,
        conditions=p.conditions,
        medications=p.medications,
        is_pregnant=p.is_pregnant,
    )


# ---------------------------------------------------------------------------
# Endpunkte
# ---------------------------------------------------------------------------

@router.post("/login", response_model=UserResponse, summary="Token validieren & User anlegen")
async def login(user: UserRow = Depends(get_current_user)):
    """
    Wird beim App-Start aufgerufen nachdem Amplify den Token liefert.
    Legt den User in der DB an wenn er noch nicht existiert.
    """
    return UserResponse(id=user.id, email=user.email, role=user.role)


@router.get("/me", response_model=UserResponse, summary="Eigene Account-Daten")
async def get_me(user: UserRow = Depends(get_current_user)):
    return UserResponse(id=user.id, email=user.email, role=user.role)


@router.get(
    "/me/profile",
    response_model=Optional[ProfileResponse],
    summary="Eigenes Profil lesen",
)
async def get_my_profile(user: UserRow = Depends(get_current_user)):
    """Gibt das gespeicherte Onboarding-Profil zurück, oder null wenn noch keins existiert."""
    profile = get_profile(user.id)
    if profile is None:
        return None
    return _profile_to_response(profile)


@router.put(
    "/me/profile",
    response_model=ProfileResponse,
    summary="Profil speichern / aktualisieren",
)
async def update_my_profile(
    body: ProfileRequest,
    user: UserRow = Depends(get_current_user),
):
    """Wird nach dem Onboarding und bei Profil-Änderungen aufgerufen."""
    try:
        profile = upsert_profile(
            user_id=user.id,
            age=body.age,
            gender=body.gender,
            sport_level=body.sport_level,
            conditions=body.conditions,
            medications=body.medications,
            is_pregnant=body.is_pregnant,
        )
    except Exception as e:
        logger.error("Profil speichern fehlgeschlagen für %s: %s", user.id, e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Profil konnte nicht gespeichert werden",
        )
    return _profile_to_response(profile)


# ---------------------------------------------------------------------------
# Admin-Endpunkte
# ---------------------------------------------------------------------------

@router.get(
    "/all",
    response_model=list[UserResponse],
    summary="Alle User auflisten (nur Admin)",
)
async def get_all_users(_admin: UserRow = Depends(require_admin)):
    users = list_all_users()
    return [UserResponse(id=u.id, email=u.email, role=u.role) for u in users]


@router.put(
    "/{user_id}/role",
    summary="Rolle eines Users ändern (nur Admin)",
)
async def change_role(
    user_id: str,
    body: RoleRequest,
    _admin: UserRow = Depends(require_admin),
):
    if body.role not in ("user", "admin"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rolle muss 'user' oder 'admin' sein",
        )
    try:
        set_user_role(user_id, body.role)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )
    return {"ok": True, "user_id": user_id, "new_role": body.role}
