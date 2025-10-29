"""
Users API routes
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
from sqlalchemy.orm import Session

# from app.db.database import get_db
# from app.db import models, schemas

router = APIRouter()


@router.post("/", status_code=201)
async def create_user():
    """Create a new user"""
    # TODO: Implement user creation
    return {"message": "User creation endpoint - TODO"}


@router.get("/{user_id}")
async def get_user(user_id: int):
    """Get user by ID"""
    # TODO: Implement get user
    return {"message": f"Get user {user_id} endpoint - TODO"}


@router.get("/wallet/{wallet_address}")
async def get_user_by_wallet(wallet_address: str):
    """Get user by wallet address"""
    # TODO: Implement get user by wallet
    return {"message": f"Get user by wallet {wallet_address} endpoint - TODO"}


@router.put("/{user_id}")
async def update_user(user_id: int):
    """Update user information"""
    # TODO: Implement user update
    return {"message": f"Update user {user_id} endpoint - TODO"}


@router.get("/")
async def list_users(skip: int = 0, limit: int = 20):
    """List all users"""
    # TODO: Implement list users
    return {"message": "List users endpoint - TODO", "skip": skip, "limit": limit}
