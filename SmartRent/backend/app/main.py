"""
SmartRent Backend API
A blockchain-first rental and asset-sharing platform backend.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn

from app.core.config import settings
from app.core.middleware import WalletAuthMiddleware
from app.api.routes import blockchain, nft, wallet_auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    print("🚀 SmartRent Backend starting up...")
    print(f"📡 Environment: {settings.ENVIRONMENT}")
    print(f"🔗 Web3 Provider: {settings.WEB3_PROVIDER_URL}")
    print(f"✅ Active routes: /api/v1/auth, /api/v1/nft, /api/v1/blockchain")
    print(f"🔐 Auth: SIWE (Sign-In With Ethereum)")
    yield
    print("👋 SmartRent Backend shutting down...")


app = FastAPI(
    title="SmartRent API",
    description="Blockchain-first rental and asset-sharing platform",
    version="2.0.0",
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

app.add_middleware(WalletAuthMiddleware)


@app.get("/ping")
async def ping():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "SmartRent Backend is running",
        "version": "2.0.0",
        "environment": settings.ENVIRONMENT
    }


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to SmartRent API",
        "docs": "/docs",
        "health": "/ping"
    }


# API Routers
app.include_router(wallet_auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(nft.router, tags=["NFT & Fractional Ownership"])
app.include_router(blockchain.router, prefix="/api/v1/blockchain", tags=["Blockchain"])


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True if settings.ENVIRONMENT == "development" else False
    )
