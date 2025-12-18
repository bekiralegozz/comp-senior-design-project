"""
SmartRent Backend API
A blockchain-first rental and asset-sharing platform backend.

MIGRATION NOTE (Dec 2025):
- Supabase/Database dependencies have been removed
- Authentication is moving to wallet-based (SIWE)
- DB-dependent routes are temporarily disabled
- Active routes: blockchain, nft, iot_devices, health checks
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn

from app.core.config import settings
from app.core.middleware import WalletAuthMiddleware

# =============================================================================
# ACTIVE ROUTES (blockchain-based, no DB dependency)
# =============================================================================
from app.api.routes import blockchain, nft, wallet_auth

# IoT devices has heavy DB dependency, disabled for now
# from app.api.routes import iot_devices

# =============================================================================
# DEPRECATED ROUTES (DB-dependent, temporarily disabled)
# =============================================================================
# from app.api.routes import assets, auth, rentals, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    # Startup
    print("🚀 SmartRent Backend starting up...")
    print(f"📡 Environment: {settings.ENVIRONMENT}")
    print(f"🔗 Web3 Provider: {settings.WEB3_PROVIDER_URL}")
    print(f"⚠️  Migration Mode: Database routes disabled")
    print(f"✅ Active routes: /api/v1/auth, /api/v1/nft, /api/v1/blockchain")
    print(f"🔐 Auth: SIWE (Sign-In With Ethereum)")
    yield
    # Shutdown
    print("👋 SmartRent Backend shutting down...")


# Initialize FastAPI app
app = FastAPI(
    title="SmartRent API",
    description="Blockchain-first rental and asset-sharing platform (Migration in progress)",
    version="2.0.0-alpha",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Configure CORS
if settings.ENVIRONMENT == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"https?://localhost:\d+|https?://127\.0\.0\.1:\d+",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["*"],
    )

# Wallet auth middleware (placeholder for SIWE - Faz 2)
app.add_middleware(WalletAuthMiddleware)


# =============================================================================
# HEALTH CHECK ENDPOINTS
# =============================================================================

@app.get("/ping")
async def ping():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "SmartRent Backend is running",
        "version": "2.0.0-alpha",
        "environment": settings.ENVIRONMENT,
        "migration_status": "Phase 1 - DB disabled"
    }


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to SmartRent API",
        "docs": "/docs",
        "health": "/ping",
        "migration_note": "Database routes disabled. Use /api/v1/nft for blockchain operations."
    }


# =============================================================================
# ACTIVE API ROUTERS (blockchain-based)
# =============================================================================

# Wallet Authentication (SIWE)
app.include_router(wallet_auth.router, prefix="/api/v1", tags=["Authentication"])

# NFT & Fractional Ownership (main blockchain functionality)
app.include_router(nft.router, tags=["NFT & Fractional Ownership"])

# Blockchain read-only operations
app.include_router(blockchain.router, prefix="/api/v1/blockchain", tags=["Blockchain (Read-Only)"])

# IoT devices disabled - heavy DB dependency, will be refactored later
# app.include_router(iot_devices.router, prefix="/api/v1/iot", tags=["IoT Devices"])


# =============================================================================
# DEPRECATED ROUTES (commented out during migration)
# =============================================================================

# These routes require database and will be reimplemented with blockchain:
# app.include_router(auth.router)  # Will be replaced with SIWE auth (Faz 2)
# app.include_router(assets.router, prefix="/api/v1/assets", tags=["Assets"])  # Use NFT instead
# app.include_router(rentals.router, prefix="/api/v1/rentals", tags=["Rentals"])  # On-chain later
# app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])  # Wallet = identity


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True if settings.ENVIRONMENT == "development" else False
    )
