"""
SmartRent Backend API
A blockchain-enabled rental and asset-sharing platform backend.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn

from app.core.config import settings
from app.core.middleware import SupabaseAuthMiddleware
from app.api.routes import assets, auth, rentals, users, iot_devices, blockchain


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    # Startup
    print("🚀 SmartRent Backend starting up...")
    print(f"📡 Environment: {settings.ENVIRONMENT}")
    print(f"🔗 Web3 Provider: {settings.WEB3_PROVIDER_URL}")
    yield
    # Shutdown
    print("👋 SmartRent Backend shutting down...")


# Initialize FastAPI app
app = FastAPI(
    title="SmartRent API",
    description="Blockchain-enabled rental and asset-sharing platform",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Configure CORS
# In development, allow all localhost origins (for Flutter web random ports)
if settings.ENVIRONMENT == "development":
    # Allow all localhost and 127.0.0.1 origins for development
    cors_kwargs = {
        "allow_origin_regex": r"http://localhost:\d+|http://127\.0\.0\.1:\d+",
        "allow_credentials": True,
        "allow_methods": ["*"],
        "allow_headers": ["*"],
    }
else:
    cors_kwargs = {
        "allow_origins": settings.ALLOWED_ORIGINS,
        "allow_credentials": True,
        "allow_methods": ["*"],
        "allow_headers": ["*"],
    }

app.add_middleware(
    CORSMiddleware,
    **cors_kwargs
)

# Attach Supabase auth middleware (non-blocking by default)
app.add_middleware(SupabaseAuthMiddleware)

# Health check endpoint
@app.get("/ping")
async def ping():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "SmartRent Backend is running",
        "version": "1.0.0",
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

# Include API routers
app.include_router(auth.router)
app.include_router(assets.router, prefix="/api/v1/assets", tags=["Assets"])
app.include_router(rentals.router, prefix="/api/v1/rentals", tags=["Rentals"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(iot_devices.router, prefix="/api/v1/iot", tags=["IoT Devices"])
app.include_router(blockchain.router, prefix="/api/v1/blockchain", tags=["Blockchain (Read-Only)"])


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True if settings.ENVIRONMENT == "development" else False
    )

