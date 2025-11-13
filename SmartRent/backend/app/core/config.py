"""
Configuration management for SmartRent Backend
"""

import os
from typing import List, Optional
from pydantic import BaseSettings, Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # Application
    APP_NAME: str = "SmartRent"
    ENVIRONMENT: str = Field(default="development", env="ENVIRONMENT")
    DEBUG: bool = Field(default=True, env="DEBUG")
    
    # API
    API_V1_STR: str = "/api/v1"
    ALLOWED_ORIGINS: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8080"],
        env="ALLOWED_ORIGINS"
    )
    
    # Database
    DATABASE_URL: str = Field(
        default="postgresql://smartrent:password@localhost:5432/smartrent_db",
        env="DATABASE_URL"
    )
    
    # Blockchain/Web3
    WEB3_PROVIDER_URL: str = Field(
        default="https://goerli.infura.io/v3/YOUR_INFURA_PROJECT_ID",
        env="WEB3_PROVIDER_URL"
    )
    PRIVATE_KEY: str = Field(default="", env="PRIVATE_KEY")
    CONTRACT_ADDRESS_ASSET_TOKEN: str = Field(default="", env="CONTRACT_ADDRESS_ASSET_TOKEN")
    CONTRACT_ADDRESS_RENTAL_AGREEMENT: str = Field(default="", env="CONTRACT_ADDRESS_RENTAL_AGREEMENT")
    
    # Security
    SECRET_KEY: str = Field(
        default="your-secret-key-change-this-in-production",
        env="SECRET_KEY"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    ALGORITHM: str = "HS256"

    # Supabase
    SUPABASE_URL: str = Field(default="", env="SUPABASE_URL")
    SUPABASE_ANON_KEY: str = Field(default="", env="SUPABASE_ANON_KEY")
    SUPABASE_SERVICE_ROLE_KEY: str = Field(default="", env="SUPABASE_SERVICE_ROLE_KEY")
    SUPABASE_EMAIL_REDIRECT_TO: str = Field(default="", env="SUPABASE_EMAIL_REDIRECT_TO")
    SUPABASE_JWT_AUDIENCE: str = Field(default="authenticated", env="SUPABASE_JWT_AUDIENCE")

    # Auth cookies
    AUTH_REFRESH_TOKEN_COOKIE_NAME: str = Field(default="sb-refresh-token", env="AUTH_REFRESH_TOKEN_COOKIE_NAME")
    AUTH_REFRESH_TOKEN_COOKIE_MAX_AGE: int = Field(default=60 * 60 * 24 * 30, env="AUTH_REFRESH_TOKEN_COOKIE_MAX_AGE")  # 30 days
    AUTH_REFRESH_TOKEN_COOKIE_SECURE: bool = Field(default=True, env="AUTH_REFRESH_TOKEN_COOKIE_SECURE")
    AUTH_REFRESH_TOKEN_COOKIE_SAMESITE: str = Field(default="lax", env="AUTH_REFRESH_TOKEN_COOKIE_SAMESITE")
    AUTH_REFRESH_TOKEN_COOKIE_DOMAIN: Optional[str] = Field(default=None, env="AUTH_REFRESH_TOKEN_COOKIE_DOMAIN")
    
    # Redis (for caching)
    REDIS_URL: str = Field(default="redis://localhost:6379", env="REDIS_URL")
    
    # File Storage
    UPLOAD_PATH: str = Field(default="./uploads", env="UPLOAD_PATH")
    MAX_FILE_SIZE: int = Field(default=10_000_000, env="MAX_FILE_SIZE")  # 10MB
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance
settings = Settings()


def get_settings() -> Settings:
    """Get application settings"""
    return settings

