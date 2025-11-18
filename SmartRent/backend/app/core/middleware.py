"""
Custom FastAPI middleware for Supabase session handling.
"""

from __future__ import annotations

from typing import Optional

from fastapi import Request
from jose import JWTError
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response

from app.core.security import extract_bearer_token, verify_supabase_jwt


class SupabaseAuthMiddleware(BaseHTTPMiddleware):
    """
    Best-effort middleware that validates Supabase JWTs on incoming requests.
    - If an Authorization header is present, verify it and attach user info to request.state.
    - If absent, allow the request to continue (route-level dependencies can enforce auth).
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        authorization: Optional[str] = request.headers.get("authorization")
        if authorization:
            try:
                token = extract_bearer_token(authorization)
                claims = await verify_supabase_jwt(token)
                request.state.supabase_claims = claims
                request.state.user_id = claims.get("sub")
            except JWTError:
                # jose.JWKError inside verify_supabase_jwt would surface as HTTPException,
                # but JWTError is caught defensively to avoid crashing middleware.
                pass
            except Exception:
                # Let downstream dependencies raise the proper HTTPException as needed.
                pass

        return await call_next(request)

