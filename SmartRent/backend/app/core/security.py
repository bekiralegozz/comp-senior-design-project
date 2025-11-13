"""
Supabase authentication helpers: JWT verification, token utilities.
"""

from __future__ import annotations

import time
from typing import Any, Dict, Optional

import httpx
from fastapi import HTTPException, status
from jose import jwk, jwt
from jose.utils import base64url_decode

from app.core.config import settings
from app.core.supabase_client import SupabaseConfigurationError

_JWKS_CACHE: Dict[str, Any] = {}
_JWKS_CACHE_EXPIRY: float = 0.0


async def _fetch_jwks() -> Dict[str, Any]:
    """Retrieve and cache Supabase JWKS for token verification."""
    global _JWKS_CACHE, _JWKS_CACHE_EXPIRY
    now = time.time()
    if _JWKS_CACHE and now < _JWKS_CACHE_EXPIRY:
        return _JWKS_CACHE

    if not settings.SUPABASE_URL:
        raise SupabaseConfigurationError("SUPABASE_URL is not configured")

    jwks_url = f"{settings.SUPABASE_URL}/auth/v1/jwks"
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(jwks_url)
    response.raise_for_status()

    _JWKS_CACHE = response.json()
    _JWKS_CACHE_EXPIRY = now + 60 * 60  # cache for 1 hour
    return _JWKS_CACHE


def _decode_unverified_claims(token: str) -> Dict[str, Any]:
    try:
        return jwt.get_unverified_claims(token)
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid JWT") from exc


async def verify_supabase_jwt(token: str) -> Dict[str, Any]:
    """Verify Supabase-issued JWT signature and expiry, returning its claims."""
    try:
        header = jwt.get_unverified_header(token)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token header") from exc

    kid = header.get("kid")
    if not kid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing key id in token")

    jwks = await _fetch_jwks()
    key_data = next((key for key in jwks.get("keys", []) if key.get("kid") == kid), None)
    if not key_data:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Signing key not found for token")

    public_key = jwk.construct(key_data)
    message, encoded_sig = token.rsplit(".", 1)
    decoded_sig = base64url_decode(encoded_sig.encode())

    if not public_key.verify(message.encode(), decoded_sig):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token signature")

    claims = _decode_unverified_claims(token)

    exp = claims.get("exp")
    if exp and exp < time.time():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")

    audience = claims.get("aud")
    expected_aud = settings.SUPABASE_JWT_AUDIENCE or "authenticated"
    if audience:
        if isinstance(audience, (list, tuple, set)):
            if expected_aud not in audience:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token audience")
        elif audience != expected_aud:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token audience")

    return claims


def extract_bearer_token(authorization_header: Optional[str]) -> str:
    """Parse a Bearer token from the Authorization header."""
    if not authorization_header:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authorization header missing")

    parts = authorization_header.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authorization header")

    token = parts[1].strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    return token

