"""
Wallet-based Authentication Routes (SIWE)

Implements Sign-In With Ethereum (EIP-4361) authentication flow.
Replaces traditional email/password authentication with wallet signatures.

Endpoints:
- GET  /auth/nonce    - Get challenge nonce for signing
- POST /auth/verify   - Verify signature and get JWT token
- GET  /auth/me       - Get current user info (protected)
- POST /auth/logout   - Invalidate session (optional)
"""

from fastapi import APIRouter, HTTPException, status, Request, Depends
from pydantic import BaseModel, Field
from typing import Optional
import re

from app.core.siwe_auth import (
    generate_nonce,
    verify_nonce_and_signature,
    create_jwt_token,
    verify_jwt_token,
    get_address_from_token
)
from app.core.security import extract_bearer_token


router = APIRouter(prefix="/auth", tags=["Authentication"])


# =============================================================================
# REQUEST/RESPONSE MODELS
# =============================================================================

class NonceResponse(BaseModel):
    """Response for nonce request"""
    nonce: str = Field(..., description="Unique nonce for signing")
    message: str = Field(..., description="Message to sign with wallet")
    expires_in: int = Field(..., description="Nonce expiry in seconds")


class VerifyRequest(BaseModel):
    """Request to verify wallet signature"""
    message: str = Field(..., description="The signed message")
    signature: str = Field(..., description="Wallet signature (0x prefixed)")
    nonce: str = Field(..., description="Nonce from the message")


class TokenResponse(BaseModel):
    """Response with JWT token"""
    access_token: str = Field(..., description="JWT access token")
    token_type: str = Field(default="bearer")
    expires_at: str = Field(..., description="Token expiry timestamp")
    expires_in: int = Field(..., description="Token expiry in seconds")
    address: str = Field(..., description="Verified wallet address")


class UserResponse(BaseModel):
    """Current user info"""
    address: str = Field(..., description="Wallet address")
    is_authenticated: bool = Field(default=True)
    auth_method: str = Field(default="siwe")


class ErrorResponse(BaseModel):
    """Error response"""
    detail: str


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def validate_eth_address(address: str) -> bool:
    """Validate Ethereum address format."""
    if not address:
        return False
    # Basic validation: 0x prefix + 40 hex chars
    pattern = r'^0x[a-fA-F0-9]{40}$'
    return bool(re.match(pattern, address))


def get_current_wallet(request: Request) -> Optional[str]:
    """
    Extract wallet address from JWT token in request.
    
    Returns None if no valid token present (for optional auth).
    Raises HTTPException for invalid tokens.
    """
    authorization = request.headers.get("authorization")
    if not authorization:
        return None
    
    try:
        token = extract_bearer_token(authorization)
        address = get_address_from_token(token)
        return address
    except Exception:
        return None


def require_wallet(request: Request) -> str:
    """
    Dependency that requires valid wallet authentication.
    
    Raises HTTPException if not authenticated.
    """
    address = get_current_wallet(request)
    if not address:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated. Please sign in with your wallet.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    return address


# =============================================================================
# ENDPOINTS
# =============================================================================

@router.get(
    "/nonce",
    response_model=NonceResponse,
    summary="Get authentication nonce",
    description="Request a nonce and message for wallet signing. The message should be signed with the wallet to prove ownership."
)
async def get_nonce(address: str):
    """
    Generate a nonce for wallet authentication.
    
    Args:
        address: Ethereum wallet address (query parameter)
        
    Returns:
        Nonce and message to sign
    """
    # Validate address format
    if not validate_eth_address(address):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Ethereum address format. Must be 0x followed by 40 hex characters."
        )
    
    # Generate nonce and message
    result = generate_nonce(address)
    
    return NonceResponse(**result)


@router.post(
    "/verify",
    response_model=TokenResponse,
    summary="Verify signature and get token",
    description="Submit the signed message to verify wallet ownership and receive a JWT token."
)
async def verify_signature_endpoint(request: VerifyRequest):
    """
    Verify wallet signature and issue JWT token.
    
    Args:
        request: Signed message, signature, and nonce
        
    Returns:
        JWT token for authenticated requests
    """
    # Validate signature format
    if not request.signature.startswith("0x"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid signature format. Must be 0x prefixed."
        )
    
    # Verify signature and nonce
    result = verify_nonce_and_signature(
        message=request.message,
        signature=request.signature,
        nonce=request.nonce
    )
    
    if not result["success"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=result["error"]
        )
    
    # Create JWT token
    token_data = create_jwt_token(result["address"])
    
    return TokenResponse(**token_data)


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user",
    description="Get information about the currently authenticated wallet."
)
async def get_current_user(address: str = Depends(require_wallet)):
    """
    Get current authenticated user info.
    
    Requires valid JWT token in Authorization header.
    """
    return UserResponse(
        address=address,
        is_authenticated=True,
        auth_method="siwe"
    )


@router.post(
    "/logout",
    summary="Logout (optional)",
    description="Client-side logout. JWT tokens are stateless, so this is informational only."
)
async def logout():
    """
    Logout endpoint.
    
    Note: JWT tokens are stateless. This endpoint is provided for API completeness.
    Client should discard the token to "logout".
    """
    return {
        "message": "Logged out successfully",
        "note": "Please discard your JWT token on client side"
    }


# =============================================================================
# UTILITY ENDPOINTS
# =============================================================================

@router.get(
    "/status",
    summary="Auth system status",
    description="Check if authentication system is operational."
)
async def auth_status():
    """Get authentication system status."""
    return {
        "status": "operational",
        "auth_method": "SIWE (Sign-In With Ethereum)",
        "standard": "EIP-4361",
        "features": {
            "nonce_expiry_seconds": 300,
            "jwt_expiry_minutes": 1440,  # 24 hours
            "supported_chains": ["Polygon (137)"]
        }
    }

