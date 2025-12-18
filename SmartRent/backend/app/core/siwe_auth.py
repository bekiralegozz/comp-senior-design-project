"""
SIWE (Sign-In With Ethereum) Authentication Service

Implements EIP-4361 standard for wallet-based authentication.
https://eips.ethereum.org/EIPS/eip-4361

Flow:
1. Client requests nonce: GET /auth/nonce?address=0x...
2. Backend generates nonce and message
3. Client signs message with wallet (no gas fee)
4. Client sends signature: POST /auth/verify {message, signature}
5. Backend verifies signature, extracts address, returns JWT
6. Client uses JWT for protected endpoints
"""

import secrets
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

import jwt
from eth_account import Account
from eth_account.messages import encode_defunct

from app.core.config import settings


# =============================================================================
# NONCE STORAGE (In-memory for simplicity, use Redis in production)
# =============================================================================

# Format: {nonce: {"address": "0x...", "created_at": timestamp, "used": False}}
_nonce_store: Dict[str, Dict[str, Any]] = {}

# Nonce expiry time in seconds (5 minutes)
NONCE_EXPIRY_SECONDS = 300

# JWT expiry time (from config, default 24 hours)
JWT_EXPIRY_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES


def _cleanup_expired_nonces():
    """Remove expired nonces from store."""
    current_time = time.time()
    expired = [
        nonce for nonce, data in _nonce_store.items()
        if current_time - data["created_at"] > NONCE_EXPIRY_SECONDS
    ]
    for nonce in expired:
        del _nonce_store[nonce]


# =============================================================================
# NONCE GENERATION
# =============================================================================

def generate_nonce(address: str) -> Dict[str, str]:
    """
    Generate a unique nonce for wallet authentication.
    
    Args:
        address: Ethereum wallet address (0x...)
        
    Returns:
        dict with nonce and formatted message for signing
    """
    _cleanup_expired_nonces()
    
    # Generate random nonce
    nonce = secrets.token_hex(16)
    
    # Create timestamp
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    # Create SIWE-style message
    message = create_siwe_message(
        address=address,
        nonce=nonce,
        timestamp=timestamp
    )
    
    # Store nonce
    _nonce_store[nonce] = {
        "address": address.lower(),
        "created_at": time.time(),
        "used": False,
        "message": message
    }
    
    return {
        "nonce": nonce,
        "message": message,
        "expires_in": NONCE_EXPIRY_SECONDS
    }


def create_siwe_message(address: str, nonce: str, timestamp: str) -> str:
    """
    Create a SIWE-compliant message for signing.
    
    Args:
        address: Wallet address
        nonce: Unique nonce
        timestamp: ISO timestamp
        
    Returns:
        Formatted message string
    """
    domain = "smartrent.app"
    uri = "https://smartrent.app"
    version = "1"
    chain_id = settings.POLYGON_CHAIN_ID
    
    message = f"""{domain} wants you to sign in with your Ethereum account:
{address}

Sign in to SmartRent - Decentralized Real Estate Platform

URI: {uri}
Version: {version}
Chain ID: {chain_id}
Nonce: {nonce}
Issued At: {timestamp}"""
    
    return message


# =============================================================================
# SIGNATURE VERIFICATION
# =============================================================================

def verify_signature(message: str, signature: str) -> Optional[str]:
    """
    Verify an Ethereum signature and recover the signer's address.
    
    Args:
        message: The original message that was signed
        signature: The signature (0x prefixed hex string)
        
    Returns:
        Recovered wallet address if valid, None if invalid
    """
    try:
        # Encode message for verification
        message_encoded = encode_defunct(text=message)
        
        # Recover address from signature
        recovered_address = Account.recover_message(
            message_encoded,
            signature=signature
        )
        
        return recovered_address.lower()
    except Exception as e:
        print(f"Signature verification failed: {e}")
        return None


def verify_nonce_and_signature(
    message: str, 
    signature: str, 
    nonce: str
) -> Dict[str, Any]:
    """
    Verify signature and validate nonce.
    
    Args:
        message: The signed message
        signature: The signature
        nonce: The nonce from the message
        
    Returns:
        dict with success status and address/error
    """
    # Check nonce exists and not expired
    if nonce not in _nonce_store:
        return {"success": False, "error": "Invalid or expired nonce"}
    
    nonce_data = _nonce_store[nonce]
    
    # Check if nonce already used
    if nonce_data["used"]:
        return {"success": False, "error": "Nonce already used"}
    
    # Check if nonce expired
    if time.time() - nonce_data["created_at"] > NONCE_EXPIRY_SECONDS:
        del _nonce_store[nonce]
        return {"success": False, "error": "Nonce expired"}
    
    # Verify signature
    recovered_address = verify_signature(message, signature)
    
    if recovered_address is None:
        return {"success": False, "error": "Invalid signature"}
    
    # Check address matches
    expected_address = nonce_data["address"]
    if recovered_address != expected_address:
        return {
            "success": False, 
            "error": f"Address mismatch: expected {expected_address}, got {recovered_address}"
        }
    
    # Mark nonce as used
    _nonce_store[nonce]["used"] = True
    
    return {
        "success": True,
        "address": recovered_address
    }


# =============================================================================
# JWT TOKEN MANAGEMENT
# =============================================================================

def create_jwt_token(address: str) -> Dict[str, Any]:
    """
    Create a JWT token for authenticated wallet.
    
    Args:
        address: Verified wallet address
        
    Returns:
        dict with token and expiry info
    """
    now = datetime.utcnow()
    expires_at = now + timedelta(minutes=JWT_EXPIRY_MINUTES)
    
    payload = {
        "sub": address.lower(),  # Subject = wallet address
        "address": address.lower(),
        "iat": now,  # Issued at
        "exp": expires_at,  # Expiry
        "type": "access",
        "auth_method": "siwe"
    }
    
    token = jwt.encode(
        payload,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_at": expires_at.isoformat() + "Z",
        "expires_in": JWT_EXPIRY_MINUTES * 60,  # seconds
        "address": address.lower()
    }


def verify_jwt_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Verify and decode a JWT token.
    
    Args:
        token: JWT token string
        
    Returns:
        Token payload if valid, None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def get_address_from_token(token: str) -> Optional[str]:
    """
    Extract wallet address from JWT token.
    
    Args:
        token: JWT token string
        
    Returns:
        Wallet address if valid, None if invalid
    """
    payload = verify_jwt_token(token)
    if payload:
        return payload.get("address")
    return None

