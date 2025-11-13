"""
Authentication-related dependencies to secure API routes.
"""

from __future__ import annotations

from typing import Any, Dict, Optional
from uuid import UUID

import anyio
import httpx
from fastapi import Depends, Header, HTTPException, Request, status

from app.core.config import settings
from app.core.security import extract_bearer_token, verify_supabase_jwt
from app.core.supabase_client import get_supabase_client


async def _call_supabase(func, *args, **kwargs):
    try:
        return await anyio.to_thread.run_sync(lambda: func(*args, **kwargs))
    except Exception as exc:  # pragma: no cover - SDK raises varied errors
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


async def _fetch_profile(user_id: UUID) -> Optional[Dict[str, Any]]:
    client = get_supabase_client()
    table = client.table("profiles")
    response = await _call_supabase(table.select("*").eq("id", str(user_id)).limit(1).execute)
    data = getattr(response, "data", None)
    if not data:
        return None
    return data[0]


async def _fetch_supabase_user(access_token: str) -> Dict[str, Any]:
    if not settings.SUPABASE_URL:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Supabase URL not configured")
    api_key = settings.SUPABASE_ANON_KEY or settings.SUPABASE_SERVICE_ROLE_KEY
    if not api_key:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Supabase API key not configured")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "apikey": api_key,
    }
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(f"{settings.SUPABASE_URL}/auth/v1/user", headers=headers)
    if response.status_code >= 400:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unable to fetch Supabase user")
    return response.json()


async def get_current_claims(authorization: Optional[str] = Header(default=None)) -> Dict[str, Any]:
    """
    Validate Supabase JWT from Authorization header and return its claims.
    Raises 401 if the token is missing or invalid.
    """
    token = extract_bearer_token(authorization)
    claims = await verify_supabase_jwt(token)
    claims["_access_token"] = token
    return claims


async def get_current_user(
    request: Request,
    claims: Dict[str, Any] = Depends(get_current_claims),
) -> Dict[str, Any]:
    """
    Ensure the request is authenticated.
    Returns a dict containing user claims + optional profile data.
    """
    user_id = claims.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing subject claim")

    access_token = claims.get("_access_token")
    supabase_user = await _fetch_supabase_user(access_token) if access_token else {}

    profile_data = await _fetch_profile(UUID(user_id))
    if profile_data:
        claims["profile"] = profile_data
    if supabase_user:
        claims["email_confirmed_at"] = supabase_user.get("email_confirmed_at")
        claims["supabase_user"] = supabase_user

    # Attach to request state for middleware-friendly access
    request.state.supabase_claims = claims
    request.state.user_id = UUID(user_id)
    claims.pop("_access_token", None)
    return claims


async def require_verified_email(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    confirmed_at = current_user.get("email_confirmed_at")
    if not confirmed_at and current_user.get("supabase_user"):
        confirmed_at = current_user["supabase_user"].get("email_confirmed_at")
    if not confirmed_at:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Email verification required")
    return current_user

