"""
Configuration management for SmartRent Backend
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
        default=["http://localhost:3000", "http://localhost:8080", "http://localhost:8081", "http://127.0.0.1:8080", "http://127.0.0.1:8081", "*"],
        env="ALLOWED_ORIGINS"
    )
    
    # Blockchain/Web3 - Polygon Mainnet
    WEB3_PROVIDER_URL: str = Field(
        default="https://polygon-rpc.com",
        env="WEB3_PROVIDER_URL"
    )
    POLYGON_CHAIN_ID: int = Field(default=137, env="POLYGON_CHAIN_ID")
    WALLET_PRIVATE_KEY: str = Field(default="", env="WALLET_PRIVATE_KEY")
    CONTRACT_OWNER_ADDRESS: str = Field(default="", env="CONTRACT_OWNER_ADDRESS")
    
    # Smart Contract Addresses
    SMARTRENTHUB_CONTRACT_ADDRESS: str = Field(default="", env="SMARTRENTHUB_CONTRACT_ADDRESS")
    BUILDING1122_CONTRACT_ADDRESS: str = Field(default="", env="BUILDING1122_CONTRACT_ADDRESS")
    RENTAL_MANAGER_CONTRACT_ADDRESS: str = Field(default="", env="RENTAL_MANAGER_CONTRACT_ADDRESS")
    RENTAL_HUB_CONTRACT_ADDRESS: str = Field(default="", env="RENTAL_HUB_CONTRACT_ADDRESS")
    MARKETPLACE_CONTRACT_ADDRESS: str = Field(default="", env="MARKETPLACE_CONTRACT_ADDRESS")
    
    # IPFS/Pinata Configuration
    PINATA_API_KEY: str = Field(default="", env="PINATA_API_KEY")
    PINATA_SECRET_KEY: str = Field(default="", env="PINATA_SECRET_KEY")
    
    # Alchemy (NFT indexing / enhanced RPC)
    ALCHEMY_API_KEY: str = Field(default="", env="ALCHEMY_API_KEY")
    
    # Security (for SIWE JWT tokens)
    SECRET_KEY: str = Field(
        default="your-secret-key-change-this-in-production",
        env="SECRET_KEY"
    )
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=1440, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    ALGORITHM: str = "HS256"
    
    # File Storage
    UPLOAD_PATH: str = Field(default="./uploads", env="UPLOAD_PATH")
    MAX_FILE_SIZE: int = Field(default=10_000_000, env="MAX_FILE_SIZE")
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


settings = Settings()


def get_settings() -> Settings:
    """Get application settings"""
    return settings
