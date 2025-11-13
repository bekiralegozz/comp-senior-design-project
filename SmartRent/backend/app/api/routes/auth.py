"""
Authentication routes backed by Supabase Auth.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional
from uuid import UUID

import anyio
import httpx
from fastapi import APIRouter, Header, HTTPException, Request, Response, status
from pydantic import BaseModel, EmailStr, Field

from app.core.config import settings
from app.core.security import extract_bearer_token, verify_supabase_jwt
from app.core.supabase_client import SupabaseConfigurationError, get_supabase_client

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    full_name: Optional[str] = None
    referral_code: Optional[str] = None


class SignupResponse(BaseModel):
    user_id: UUID
    requires_email_verification: bool = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ProfilePayload(BaseModel):
    id: UUID
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    wallet_address: Optional[str] = None
    avatar_url: Optional[str] = None
    auth_provider: Optional[str] = None
    last_login_at: Optional[datetime] = None
    is_onboarded: Optional[bool] = None


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str
    expires_in: int
    user_id: UUID
    profile: Optional[ProfilePayload] = None


class MagicLinkRequest(BaseModel):
    email: EmailStr
    redirect_to: Optional[str] = None


class PasswordResetRequest(BaseModel):
    email: EmailStr
    redirect_to: Optional[str] = None


class PasswordResetConfirmRequest(BaseModel):
    access_token: str = Field(..., description="Token supplied in the password reset callback URL")
    new_password: str = Field(..., min_length=8, max_length=72)


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None


class StatusResponse(BaseModel):
    status: str


class RefreshRequest(BaseModel):
    refresh_token: Optional[str] = None


async def _call_supabase(func, *args, **kwargs):
    """Execute a blocking Supabase SDK call in a worker thread."""
    try:
        return await anyio.to_thread.run_sync(lambda: func(*args, **kwargs))
    except Exception as exc:  # pragma: no cover - SDK raises varied errors
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


async def _upsert_profile(user_id: UUID, email: str, full_name: Optional[str]) -> None:
    client = get_supabase_client()
    payload: Dict[str, Any] = {
        "id": str(user_id),
        "email": email,
        "full_name": full_name,
        "auth_provider": "email",
    }
    payload = {k: v for k, v in payload.items() if v is not None}
    table = client.table("profiles")
    await _call_supabase(table.upsert(payload, on_conflict="id").execute)


async def _fetch_profile(user_id: UUID) -> Optional[ProfilePayload]:
    client = get_supabase_client()
    table = client.table("profiles")
    response = await _call_supabase(table.select("*").eq("id", str(user_id)).limit(1).execute)
    data = getattr(response, "data", None)
    if not data:
        return None
    profile_data = data[0]
    for ts_field in ("created_at", "updated_at", "last_login_at"):
        if ts_field in profile_data and isinstance(profile_data[ts_field], str):
            try:
                profile_data[ts_field] = datetime.fromisoformat(profile_data[ts_field].replace("Z", "+00:00"))
            except ValueError:
                profile_data[ts_field] = None
    return ProfilePayload(
        id=UUID(str(profile_data["id"])),
        full_name=profile_data.get("full_name"),
        email=profile_data.get("email"),
        wallet_address=profile_data.get("wallet_address"),
        avatar_url=profile_data.get("avatar_url"),
        auth_provider=profile_data.get("auth_provider"),
        last_login_at=profile_data.get("last_login_at"),
        is_onboarded=profile_data.get("is_onboarded"),
    )


async def _update_last_login(user_id: UUID) -> None:
    client = get_supabase_client()
    table = client.table("profiles")
    await _call_supabase(
        table.update({"last_login_at": datetime.now(timezone.utc).isoformat()}).eq("id", str(user_id)).execute
    )


async def _issue_password_reset(email: str, redirect_to: Optional[str]) -> None:
    client = get_supabase_client()
    options: Dict[str, Any] = {}
    redirect_target = redirect_to or settings.SUPABASE_EMAIL_REDIRECT_TO
    if redirect_target:
        options["redirect_to"] = redirect_target
    if options:
        await _call_supabase(client.auth.reset_password_for_email, email, options)
    else:
        await _call_supabase(client.auth.reset_password_for_email, email)


async def _send_magic_link(email: str, redirect_to: Optional[str]) -> None:
    client = get_supabase_client()
    options: Dict[str, Any] = {}
    redirect_target = redirect_to or settings.SUPABASE_EMAIL_REDIRECT_TO
    if redirect_target:
        options["email_redirect_to"] = redirect_target
    payload: Dict[str, Any] = {"email": email}
    if options:
        payload["options"] = options
    await _call_supabase(client.auth.sign_in_with_otp, payload)


async def _update_password_with_access_token(access_token: str, new_password: str) -> None:
    if not settings.SUPABASE_URL:
        raise SupabaseConfigurationError("SUPABASE_URL is not configured")

    headers = {
        "Authorization": f"Bearer {access_token}",
        "apikey": settings.SUPABASE_ANON_KEY or settings.SUPABASE_SERVICE_ROLE_KEY,
    }
    if not headers["apikey"]:
        raise SupabaseConfigurationError("A Supabase API key is required to update the password")

    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.put(
            f"{settings.SUPABASE_URL}/auth/v1/user",
            json={"password": new_password},
            headers=headers,
        )
    if response.status_code >= 400:
        try:
            detail = response.json()
        except ValueError:
            detail = {"message": response.text}
        raise HTTPException(
            status_code=response.status_code,
            detail=detail.get("message", "Failed to update password"),
        )


@router.post("/signup", response_model=SignupResponse, status_code=status.HTTP_201_CREATED)
async def signup(payload: SignupRequest) -> SignupResponse:
    client = get_supabase_client()

    signup_payload: Dict[str, Any] = {
        "email": payload.email,
        "password": payload.password,
    }

    options: Dict[str, Any] = {}
    redirect_to = settings.SUPABASE_EMAIL_REDIRECT_TO
    if redirect_to:
        options["email_redirect_to"] = redirect_to
    if payload.full_name:
        options.setdefault("data", {})["full_name"] = payload.full_name
    if payload.referral_code:
        options.setdefault("data", {})["referral_code"] = payload.referral_code
    if options:
        signup_payload["options"] = options

    result = await _call_supabase(client.auth.sign_up, signup_payload)
    user = getattr(result, "user", None)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Supabase sign-up failed to return a user.",
        )

    user_id = UUID(str(getattr(user, "id", "")))

    await _upsert_profile(user_id, payload.email, payload.full_name)

    requires_verification = getattr(user, "email_confirmed_at", None) is None
    return SignupResponse(user_id=user_id, requires_email_verification=requires_verification)


@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, response: Response) -> LoginResponse:
    client = get_supabase_client()

    result = await _call_supabase(
        client.auth.sign_in_with_password,
        {"email": payload.email, "password": payload.password},
    )

    session = getattr(result, "session", None)
    user = getattr(result, "user", None)

    if not session or not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials or unverified email")

    access_token = getattr(session, "access_token", None)
    refresh_token = getattr(session, "refresh_token", None)
    expires_in = getattr(session, "expires_in", None)
    token_type = getattr(session, "token_type", "bearer")

    if not access_token or not refresh_token:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Supabase did not issue tokens")

    user_id = UUID(str(getattr(user, "id", "")))

    await _update_last_login(user_id)
    profile = await _fetch_profile(user_id)

    cookie_kwargs: Dict[str, Any] = {
        "httponly": True,
        "secure": settings.AUTH_REFRESH_TOKEN_COOKIE_SECURE,
        "samesite": settings.AUTH_REFRESH_TOKEN_COOKIE_SAMESITE,
        "max_age": settings.AUTH_REFRESH_TOKEN_COOKIE_MAX_AGE,
        "path": "/",
    }
    if settings.AUTH_REFRESH_TOKEN_COOKIE_DOMAIN:
        cookie_kwargs["domain"] = settings.AUTH_REFRESH_TOKEN_COOKIE_DOMAIN

    response.set_cookie(
        settings.AUTH_REFRESH_TOKEN_COOKIE_NAME,
        refresh_token,
        **cookie_kwargs,
    )

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type=token_type,
        expires_in=int(expires_in) if expires_in is not None else 0,
        user_id=user_id,
        profile=profile,
    )


@router.post("/magic-link", response_model=StatusResponse, status_code=status.HTTP_202_ACCEPTED)
async def request_magic_link(payload: MagicLinkRequest) -> StatusResponse:
    await _send_magic_link(payload.email, payload.redirect_to)
    return StatusResponse(status="sent")


async def _refresh_with_token(refresh_token: str) -> Dict[str, Any]:
    if not settings.SUPABASE_URL:
        raise SupabaseConfigurationError("SUPABASE_URL is not configured")
    api_key = settings.SUPABASE_ANON_KEY or settings.SUPABASE_SERVICE_ROLE_KEY
    if not api_key:
        raise SupabaseConfigurationError("Supabase API key is not configured")

    url = f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=refresh_token"
    payload = {"refresh_token": refresh_token}
    headers = {
        "apikey": api_key,
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(url, json=payload, headers=headers)
    if response.status_code >= 400:
        detail = None
        try:
            detail = response.json()
        except ValueError:
            detail = {"message": response.text}
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail.get("message", "Unable to refresh session"),
        )
    return response.json()


def _extract_refresh_token(request: Request, body_token: Optional[str]) -> str:
    if body_token:
        return body_token
    cookie_token = request.cookies.get(settings.AUTH_REFRESH_TOKEN_COOKIE_NAME)
    if cookie_token:
        return cookie_token
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token is required")


@router.post("/refresh", response_model=LoginResponse)
async def refresh_session(payload: RefreshRequest, request: Request, response: Response) -> LoginResponse:
    refresh_token = _extract_refresh_token(request, payload.refresh_token if payload else None)
    refresh_result = await _refresh_with_token(refresh_token)

    access_token = refresh_result.get("access_token")
    new_refresh_token = refresh_result.get("refresh_token")
    expires_in = refresh_result.get("expires_in", 0)
    token_type = refresh_result.get("token_type", "bearer")
    user_info = refresh_result.get("user") or {}
    user_id_value = user_info.get("id")

    if not access_token or not new_refresh_token or not user_id_value:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Supabase refresh returned incomplete data")

    user_id = UUID(str(user_id_value))
    await _update_last_login(user_id)
    profile = await _fetch_profile(user_id)

    cookie_kwargs: Dict[str, Any] = {
        "httponly": True,
        "secure": settings.AUTH_REFRESH_TOKEN_COOKIE_SECURE,
        "samesite": settings.AUTH_REFRESH_TOKEN_COOKIE_SAMESITE,
        "max_age": settings.AUTH_REFRESH_TOKEN_COOKIE_MAX_AGE,
        "path": "/",
    }
    if settings.AUTH_REFRESH_TOKEN_COOKIE_DOMAIN:
        cookie_kwargs["domain"] = settings.AUTH_REFRESH_TOKEN_COOKIE_DOMAIN

    response.set_cookie(
        settings.AUTH_REFRESH_TOKEN_COOKIE_NAME,
        new_refresh_token,
        **cookie_kwargs,
    )

    return LoginResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        token_type=token_type,
        expires_in=int(expires_in),
        user_id=user_id,
        profile=profile,
    )


@router.post("/password/reset", response_model=StatusResponse, status_code=status.HTTP_202_ACCEPTED)
async def request_password_reset(payload: PasswordResetRequest) -> StatusResponse:
    await _issue_password_reset(payload.email, payload.redirect_to)
    return StatusResponse(status="sent")


@router.post("/password/reset/confirm", response_model=StatusResponse)
async def confirm_password_reset(payload: PasswordResetConfirmRequest) -> StatusResponse:
    await _update_password_with_access_token(payload.access_token, payload.new_password)
    return StatusResponse(status="updated")


@router.post("/logout", response_model=StatusResponse)
async def logout(
    payload: LogoutRequest,
    response: Response,
    authorization: Optional[str] = Header(default=None),
) -> StatusResponse:
    refresh_token = payload.refresh_token

    if authorization:
        token = extract_bearer_token(authorization)
        claims = await verify_supabase_jwt(token)
        user_id = claims.get("sub")
        if user_id:
            client = get_supabase_client()
            admin_api = client.auth.admin
            if hasattr(admin_api, "invalidate_refresh_tokens"):
                try:
                    await _call_supabase(admin_api.invalidate_refresh_tokens, str(user_id))
                except HTTPException:
                    pass

    if refresh_token:
        client = get_supabase_client()
        admin_api = client.auth.admin
        if hasattr(admin_api, "delete_refresh_token"):
            try:
                await _call_supabase(admin_api.delete_refresh_token, refresh_token)
            except HTTPException:
                pass  # Token may already be invalid; suppress errors

    response.delete_cookie(
        settings.AUTH_REFRESH_TOKEN_COOKIE_NAME,
        path="/",
        domain=settings.AUTH_REFRESH_TOKEN_COOKIE_DOMAIN,
    )

    return StatusResponse(status="signed_out")

