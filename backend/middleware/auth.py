"""
Cognito JWT-Verifikation.

Jede geschützte Route ruft get_current_user() als FastAPI-Dependency auf.
Das Token kommt als Bearer-Token im Authorization-Header.

Ablauf:
  1. JWKs von Cognito laden (gecacht im Speicher)
  2. JWT-Header lesen → richtigen Public-Key wählen
  3. Token verifizieren (Signatur, Ablauf, Audience)
  4. Cognito-Sub + Email aus Claims extrahieren
  5. User in DB suchen / anlegen (upsert)
"""
import logging
import time
from typing import Optional

import requests
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode

from config.settings import settings
from database.user_repository import UserRow, upsert_user

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# JWK-Cache — Cognito Public Keys werden einmalig geladen und gecacht
# ---------------------------------------------------------------------------

_jwks_cache: dict = {}
_jwks_loaded_at: float = 0.0
_JWKS_TTL = 3600  # Sekunden — 1 Stunde

_security = HTTPBearer(auto_error=True)


def _jwks_url() -> str:
    return (
        f"https://cognito-idp.{settings.cognito_region}.amazonaws.com"
        f"/{settings.cognito_user_pool_id}/.well-known/jwks.json"
    )


def _get_jwks() -> dict:
    """Lädt die Cognito Public Keys und cached sie."""
    global _jwks_cache, _jwks_loaded_at
    now = time.time()
    if _jwks_cache and (now - _jwks_loaded_at) < _JWKS_TTL:
        return _jwks_cache

    try:
        resp = requests.get(_jwks_url(), timeout=5)
        resp.raise_for_status()
        _jwks_cache = {key["kid"]: key for key in resp.json()["keys"]}
        _jwks_loaded_at = now
        logger.info("Cognito JWKs geladen (%d Keys)", len(_jwks_cache))
    except Exception as e:
        logger.error("Cognito JWKs konnten nicht geladen werden: %s", e)
        if not _jwks_cache:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Auth-Service nicht erreichbar",
            )
    return _jwks_cache


# ---------------------------------------------------------------------------
# Token verifizieren
# ---------------------------------------------------------------------------

def _verify_token(token: str) -> dict:
    """
    Verifiziert ein Cognito-JWT und gibt die Claims zurück.
    Wirft HTTPException bei ungültigem Token.
    """
    if not settings.cognito_user_pool_id or not settings.cognito_client_id:
        # Auth noch nicht konfiguriert — Entwicklungsmodus
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Cognito noch nicht konfiguriert (cognito_user_pool_id fehlt)",
        )

    # Header lesen ohne zu verifizieren um kid zu bekommen
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Ungültiger Token-Header: {e}",
        )

    kid = header.get("kid")
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token hat kein kid",
        )

    jwks = _get_jwks()
    if kid not in jwks:
        # JWKs neu laden (Key Rotation)
        global _jwks_loaded_at
        _jwks_loaded_at = 0
        jwks = _get_jwks()
        if kid not in jwks:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Unbekannter Token-Key",
            )

    public_key = jwk.construct(jwks[kid])

    # Token verifizieren
    try:
        claims = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=settings.cognito_client_id,
            options={"verify_at_hash": False},
        )
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token ungültig: {e}",
        )

    # Token-Typ prüfen (id_token enthält email, access_token nicht)
    token_use = claims.get("token_use")
    if token_use not in ("id", "access"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Ungültiger token_use",
        )

    return claims


# ---------------------------------------------------------------------------
# FastAPI Dependencies
# ---------------------------------------------------------------------------

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_security),
) -> UserRow:
    """
    Dependency für geschützte Routen.
    Gibt den User aus der DB zurück (wird angelegt wenn noch nicht vorhanden).

    Verwendung:
        @router.get("/me")
        async def me(user: UserRow = Depends(get_current_user)):
            ...
    """
    token = credentials.credentials
    claims = _verify_token(token)

    cognito_sub = claims.get("sub", "")
    # id_token hat 'email', access_token hat 'username'
    email = claims.get("email") or claims.get("username") or cognito_sub

    try:
        user = upsert_user(cognito_sub=cognito_sub, email=email)
    except Exception as e:
        logger.error("User upsert fehlgeschlagen: %s", e)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Datenbank nicht erreichbar",
        )

    return user


async def require_admin(user: UserRow = Depends(get_current_user)) -> UserRow:
    """
    Dependency für Admin-Routen.
    Wirft 403 wenn der User kein Admin ist.
    """
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Nur Administratoren können diese Aktion ausführen",
        )
    return user


# ---------------------------------------------------------------------------
# Optionaler User (für Routen die Auth nicht zwingend brauchen)
# ---------------------------------------------------------------------------

_optional_security = HTTPBearer(auto_error=False)


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_security),
) -> Optional[UserRow]:
    """Gibt den User zurück wenn ein Token vorhanden ist, sonst None."""
    if not credentials:
        return None
    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None
