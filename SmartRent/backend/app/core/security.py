"""
Security utilities for wallet-based authentication.

Provides helper functions for JWT token handling and
authentication dependencies for FastAPI routes.
"""

from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import HTTPException, Request, status

from app.core.siwe_auth import verify_jwt_token, get_address_from_token


def extract_bearer_token(authorization_header: Optional[str]) -> str:
    """
    Parse a Bearer token from the Authorization header.
    
    Args:
        authorization_header: Full Authorization header value
        
    Returns:
        Token string
        
    Raises:
        HTTPException: If header is missing or malformed
    """
    if not authorization_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Authorization header missing",
            headers={"WWW-Authenticate": "Bearer"}
        )

    parts = authorization_header.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Invalid authorization header format. Use: Bearer <token>",
            headers={"WWW-Authenticate": "Bearer"}
        )

    token = parts[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"}
        )
    return token


async def get_current_user(request: Request) -> Dict[str, Any]:
    """
    FastAPI dependency to get the current authenticated user.
    
    Uses middleware-attached state if available, otherwise
    verifies token from Authorization header.
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Dict with user info (address, etc.)
        
    Raises:
        HTTPException: If not authenticated
    """
    # Check if middleware already verified the token
    if hasattr(request.state, 'is_authenticated') and request.state.is_authenticated:
        return {
            "address": request.state.wallet_address,
            "payload": request.state.token_payload
        }
    
    # Try to verify from header
    authorization = request.headers.get("authorization")
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated. Please sign in with your wallet.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    try:
        token = extract_bearer_token(authorization)
        payload = verify_jwt_token(token)
        
        if not payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
                headers={"WWW-Authenticate": "Bearer"}
            )
        
        return {
            "address": payload.get("address"),
            "payload": payload
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token verification failed: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"}
        )


def get_optional_user(request: Request) -> Optional[Dict[str, Any]]:
    """
    FastAPI dependency that optionally gets current user.
    
    Returns None if not authenticated (doesn't raise error).
    Useful for endpoints that work differently for auth/unauth users.
    """
    if hasattr(request.state, 'is_authenticated') and request.state.is_authenticated:
        return {
            "address": request.state.wallet_address,
            "payload": request.state.token_payload
        }
    return None


def require_wallet_address(request: Request) -> str:
    """
    FastAPI dependency that requires authenticated wallet.
    
    Returns just the wallet address (not full user dict).
    Raises HTTPException if not authenticated.
    """
    if hasattr(request.state, 'is_authenticated') and request.state.is_authenticated:
        return request.state.wallet_address
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Wallet authentication required",
        headers={"WWW-Authenticate": "Bearer"}
    )
