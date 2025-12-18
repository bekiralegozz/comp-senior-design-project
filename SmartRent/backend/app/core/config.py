"""
Configuration management for SmartRent Backend

MIGRATION NOTE (Dec 2025):
- Database/Supabase dependencies are being removed
- Moving to wallet-based authentication (SIWE)
- Backend will be blockchain-first
"""

import os
from typing import List, Optional
from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # Application
    APP_NAME: str = "SmartRent"
    ENVIRONMENT: str = Field(default="development", env="ENVIRONMENT")
    DEBUG: bool = Field(default=True, env="DEBUG")
    
    # API
    API_V1_STR: str = "/api/v1"
    ALLOWED_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8080", "http://localhost:8081", "http://127.0.0.1:8080", "http://127.0.0.1:8081"],
        env="ALLOWED_ORIGINS"
    )
    
    # ============================================================
    # DEPRECATED: Database (no longer used - blockchain is source of truth)
    # ============================================================
    # DATABASE_URL: str = Field(
    #     default="postgresql://smartrent:password@localhost:5432/smartrent_db",
    #     env="DATABASE_URL"
    # )
    
    # Blockchain/Web3 - Polygon Mainnet
    WEB3_PROVIDER_URL: str = Field(
        default="https://polygon-rpc.com",
        env="WEB3_PROVIDER_URL"
    )
    POLYGON_CHAIN_ID: int = Field(default=137, env="POLYGON_CHAIN_ID")
    WALLET_PRIVATE_KEY: str = Field(default="", env="WALLET_PRIVATE_KEY")
    CONTRACT_OWNER_ADDRESS: str = Field(default="", env="CONTRACT_OWNER_ADDRESS")
    
    # Smart Contract Addresses (from deployment)
    BUILDING1122_CONTRACT_ADDRESS: str = Field(default="", env="BUILDING1122_CONTRACT_ADDRESS")
    MARKETPLACE_CONTRACT_ADDRESS: str = Field(default="", env="MARKETPLACE_CONTRACT_ADDRESS")
    RENTAL_MANAGER_CONTRACT_ADDRESS: str = Field(default="", env="RENTAL_MANAGER_CONTRACT_ADDRESS")
    
    # Legacy (keep for backwards compatibility)
    PRIVATE_KEY: str = Field(default="", env="PRIVATE_KEY")
    CONTRACT_ADDRESS_ASSET_TOKEN: str = Field(default="", env="CONTRACT_ADDRESS_ASSET_TOKEN")
    CONTRACT_ADDRESS_RENTAL_AGREEMENT: str = Field(default="", env="CONTRACT_ADDRESS_RENTAL_AGREEMENT")
    
    # IPFS/Pinata Configuration
    PINATA_API_KEY: str = Field(default="", env="PINATA_API_KEY")
    PINATA_SECRET_KEY: str = Field(default="", env="PINATA_SECRET_KEY")
    
    # OpenSea
    OPENSEA_API_KEY: str = Field(default="", env="OPENSEA_API_KEY")

    # Alchemy (NFT indexing / enhanced RPC)
    # Used to list NFTs for an owner without relying on local caches or RPC log filters.
    ALCHEMY_API_KEY: str = Field(default="", env="ALCHEMY_API_KEY")
    
    # Security (for SIWE JWT tokens)
    SECRET_KEY: str = Field(
        default="your-secret-key-change-this-in-production",
        env="SECRET_KEY"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=1440, env="ACCESS_TOKEN_EXPIRE_MINUTES")  # 24 hours for wallet auth
    ALGORITHM: str = "HS256"

    # ============================================================
    # DEPRECATED: Supabase (no longer used - using wallet auth)
    # ============================================================
    # SUPABASE_URL: str = Field(default="", env="SUPABASE_URL")
    # SUPABASE_ANON_KEY: str = Field(default="", env="SUPABASE_ANON_KEY")
    # SUPABASE_SERVICE_ROLE_KEY: str = Field(default="", env="SUPABASE_SERVICE_ROLE_KEY")
    # SUPABASE_EMAIL_REDIRECT_TO: str = Field(default="", env="SUPABASE_EMAIL_REDIRECT_TO")
    # SUPABASE_JWT_AUDIENCE: str = Field(default="authenticated", env="SUPABASE_JWT_AUDIENCE")

    # ============================================================
    # DEPRECATED: Auth cookies (no longer used)
    # ============================================================
    # AUTH_REFRESH_TOKEN_COOKIE_NAME: str = Field(default="sb-refresh-token", env="AUTH_REFRESH_TOKEN_COOKIE_NAME")
    # AUTH_REFRESH_TOKEN_COOKIE_MAX_AGE: int = Field(default=60 * 60 * 24 * 30, env="AUTH_REFRESH_TOKEN_COOKIE_MAX_AGE")
    # AUTH_REFRESH_TOKEN_COOKIE_SECURE: bool = Field(default=True, env="AUTH_REFRESH_TOKEN_COOKIE_SECURE")
    # AUTH_REFRESH_TOKEN_COOKIE_SAMESITE: str = Field(default="lax", env="AUTH_REFRESH_TOKEN_COOKIE_SAMESITE")
    # AUTH_REFRESH_TOKEN_COOKIE_DOMAIN: Optional[str] = Field(default=None, env="AUTH_REFRESH_TOKEN_COOKIE_DOMAIN")
    
    # ============================================================
    # DEPRECATED: Redis (not needed for wallet-based auth)
    # ============================================================
    # REDIS_URL: str = Field(default="redis://localhost:6379", env="REDIS_URL")
    
    # File Storage
    UPLOAD_PATH: str = Field(default="./uploads", env="UPLOAD_PATH")
    MAX_FILE_SIZE: int = Field(default=10_000_000, env="MAX_FILE_SIZE")  # 10MB
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore deprecated env vars (SUPABASE_*, DATABASE_URL, etc.)


# Global settings instance
settings = Settings()


def get_settings() -> Settings:
    """Get application settings"""
    return settings

