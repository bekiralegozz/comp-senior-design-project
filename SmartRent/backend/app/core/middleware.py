"""
Custom FastAPI middleware for wallet-based authentication.

Implements JWT verification for SIWE (Sign-In With Ethereum) tokens.
Attaches wallet address to request.state for downstream use.
"""

from __future__ import annotations

from typing import Optional

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.responses import Response

from app.core.siwe_auth import verify_jwt_token
from app.core.security import extract_bearer_token


class WalletAuthMiddleware(BaseHTTPMiddleware):
    """
    Best-effort middleware that validates SIWE JWT tokens.
    
    - If Authorization header present, verify JWT and attach wallet info
    - If absent or invalid, allow request to continue (route dependencies enforce auth)
    - Non-blocking: doesn't reject requests, lets route-level auth handle it
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        # Initialize request state
        request.state.wallet_address = None
        request.state.is_authenticated = False
        request.state.token_payload = None
        
        # Try to extract and verify token
        authorization: Optional[str] = request.headers.get("authorization")
        if authorization:
            try:
                token = extract_bearer_token(authorization)
                payload = verify_jwt_token(token)
                
                if payload:
                    request.state.wallet_address = payload.get("address")
                    request.state.is_authenticated = True
                    request.state.token_payload = payload
            except Exception:
                # Invalid token format or verification failed
                # Let route-level dependencies handle the error
                pass

        return await call_next(request)


# Backwards compatibility alias
SupabaseAuthMiddleware = WalletAuthMiddleware
