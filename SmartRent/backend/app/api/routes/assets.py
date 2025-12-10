"""
Assets API routes
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

import anyio
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.core.supabase_client import get_supabase_client

router = APIRouter()


# Helper function to call Supabase with error handling
async def _call_supabase(func, *args, **kwargs):
    """Execute a Supabase function and handle errors."""
    try:
        return await anyio.to_thread.run_sync(func, *args, **kwargs)
    except Exception as exc:
        error_str = str(exc)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Database error: {error_str}"
        ) from exc


# Response models
class AssetResponse(BaseModel):
    """Asset response model matching frontend expectations"""
    id: str  # UUID as string for frontend compatibility
    title: str
    description: Optional[str] = None
    category: str = "other"  # Default category since not in DB schema
    pricePerDay: float = 0.0  # Default since not in DB schema
    currency: str = "token"  # Default currency (blockchain token)
    location: Optional[str] = None
    ownerId: str  # UUID as string
    tokenId: Optional[int] = None
    contractAddress: Optional[str] = None
    isAvailable: bool
    iotDeviceId: Optional[str] = None
    imageUrl: Optional[str] = None  # Main image URL from database
    createdAt: datetime
    updatedAt: Optional[datetime] = None
    owner: Optional[Dict[str, Any]] = None


def _format_location(location_data: Any) -> Optional[str]:
    """Format location JSONB to string."""
    if not location_data:
        return None
    
    if isinstance(location_data, dict):
        # Try to build a readable location string
        parts = []
        if "address" in location_data:
            parts.append(location_data["address"])
        if "district" in location_data:
            parts.append(location_data["district"])
        if "city" in location_data:
            parts.append(location_data["city"])
        return ", ".join(parts) if parts else str(location_data)
    
    return str(location_data)


def _map_asset_from_db(asset_data: Dict[str, Any], owner_data: Optional[Dict[str, Any]] = None) -> AssetResponse:
    """Map database asset data to frontend-compatible format."""
    # Extract location string from JSONB
    location_str = _format_location(asset_data.get("location"))
    
    # Map owner data if available
    owner_dict = None
    if owner_data:
        # Handle created_at - it might be string or datetime
        created_at = owner_data.get("created_at")
        if created_at and hasattr(created_at, 'isoformat'):
            created_at_str = created_at.isoformat()
        elif created_at:
            created_at_str = str(created_at)
        else:
            created_at_str = None
            
        owner_dict = {
            "id": str(owner_data.get("id", "")),
            "email": owner_data.get("email"),
            "displayName": owner_data.get("full_name"),
            "walletAddress": owner_data.get("wallet_address"),
            "createdAt": created_at_str,
        }
    
    return AssetResponse(
        id=str(asset_data["id"]),
        title=asset_data.get("name", "Unnamed Asset"),
        description=asset_data.get("description"),
        category=asset_data.get("category", "other"),
        pricePerDay=float(asset_data.get("price_per_day", 0.0)),
        currency=asset_data.get("currency", "token"),
        location=location_str,
        ownerId=str(asset_data.get("owner_id", "")),
        tokenId=asset_data.get("token_id"),
        contractAddress=asset_data.get("asset_share_address"),
        isAvailable=asset_data.get("is_available", True),
        iotDeviceId=asset_data.get("iot_device_id"),
        imageUrl=asset_data.get("image_url") or asset_data.get("main_image_url"),
        createdAt=asset_data.get("created_at") or datetime.now(),
        updatedAt=asset_data.get("updated_at"),
        owner=owner_dict,
    )


@router.get("/", response_model=List[AssetResponse])
async def list_assets(
    skip: int = 0,
    limit: int = 20,
    category: Optional[str] = None,
    available_only: bool = True
):
    """List all assets with optional filters.
    
    Note: category filter is not implemented in database schema yet.
    available_only filters by active=true.
    """
    client = get_supabase_client(use_service_role=True)
    table = client.table("assets")
    
    # Build query
    query = table.select("*, profiles!assets_owner_id_fkey(*)")
    
    # Filter by active status if requested
    if available_only:
        query = query.eq("active", True)
    
    # Apply pagination
    query = query.range(skip, skip + limit - 1)
    
    # Order by created_at descending (newest first)
    query = query.order("created_at", desc=True)
    
    # Execute query
    response = await _call_supabase(query.execute)
    
    if not hasattr(response, "data") or not response.data:
        return []
    
    # Map results to response format
    assets = []
    for item in response.data:
        # Extract owner data if joined
        owner_data = None
        if "profiles" in item and item["profiles"]:
            owner_data = item["profiles"] if isinstance(item["profiles"], dict) else item["profiles"][0] if isinstance(item["profiles"], list) and item["profiles"] else None
        
        # Remove profiles from asset data
        asset_data = {k: v for k, v in item.items() if k != "profiles"}
        assets.append(_map_asset_from_db(asset_data, owner_data))
    
    return assets


@router.get("/{asset_id}", response_model=AssetResponse)
async def get_asset(asset_id: str):
    """Get asset by ID (UUID as string)"""
    try:
        asset_uuid = UUID(asset_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid asset ID format"
        )
    
    client = get_supabase_client(use_service_role=True)
    table = client.table("assets")
    
    # Query with owner join
    query = table.select("*, profiles!assets_owner_id_fkey(*)").eq("id", str(asset_uuid)).limit(1)
    response = await _call_supabase(query.execute)
    
    if not hasattr(response, "data") or not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Asset with ID {asset_id} not found"
        )
    
    item = response.data[0]
    
    # Extract owner data
    owner_data = None
    if "profiles" in item and item["profiles"]:
        owner_data = item["profiles"] if isinstance(item["profiles"], dict) else item["profiles"][0] if isinstance(item["profiles"], list) and item["profiles"] else None
    
    # Remove profiles from asset data
    asset_data = {k: v for k, v in item.items() if k != "profiles"}
    
    return _map_asset_from_db(asset_data, owner_data)


@router.get("/owner/{owner_id}", response_model=List[AssetResponse])
async def get_assets_by_owner(owner_id: str):
    """Get all assets owned by a user (UUID as string)"""
    try:
        owner_uuid = UUID(owner_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid owner ID format"
        )
    
    client = get_supabase_client(use_service_role=True)
    table = client.table("assets")
    
    # Query assets by owner with owner profile join
    query = table.select("*, profiles!assets_owner_id_fkey(*)").eq("owner_id", str(owner_uuid)).order("created_at", desc=True)
    response = await _call_supabase(query.execute)
    
    if not hasattr(response, "data") or not response.data:
        return []
    
    # Map results
    assets = []
    for item in response.data:
        owner_data = None
        if "profiles" in item and item["profiles"]:
            owner_data = item["profiles"] if isinstance(item["profiles"], dict) else item["profiles"][0] if isinstance(item["profiles"], list) and item["profiles"] else None
        
        asset_data = {k: v for k, v in item.items() if k != "profiles"}
        assets.append(_map_asset_from_db(asset_data, owner_data))
    
    return assets


@router.get("/categories/")
async def get_asset_categories():
    """Get all available asset categories.
    
    Note: Categories are not yet stored in database schema.
    Returning default categories for now.
    """
    return [
        "housing",
        "vehicles",
        "electronics",
        "tools",
        "furniture",
        "sports",
        "books",
        "clothing",
        "other"
    ]


class CreateAssetRequest(BaseModel):
    """Request model for creating a new asset"""
    name: str
    description: Optional[str] = None
    category: str = "other"
    price_per_day: float
    currency: str = "token"
    location: Optional[str] = None
    image_url: Optional[str] = None
    iot_device_id: Optional[str] = None
    owner_id: str  # UUID of the owner (from auth)


@router.post("/", status_code=status.HTTP_410_GONE, deprecated=True)
async def create_asset(asset_request: CreateAssetRequest):
    """
    [DEPRECATED] Create a new asset
    
    ⚠️ This endpoint is deprecated and will be removed.
    In decentralized architecture, assets are created directly on blockchain
    via mobile app wallet interaction.
    
    Use: Mobile App → WalletConnect → Building1122.mintInitialSupply()
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail={
            "error": "Endpoint deprecated",
            "message": "Asset creation now happens on blockchain via mobile app",
            "migration": "Use mobile app wallet to call Building1122.mintInitialSupply()",
            "contract": "0xeFbfFC198FfA373C26E64a426E8866B132d08ACB"
        }
    )
    
    # Old implementation kept for reference
    supabase = get_supabase_client()
    
    # Prepare location as JSONB if provided
    location_json = None
    if asset_request.location:
        location_json = {"address": asset_request.location}
    
    # Prepare asset data for insertion
    asset_data = {
        "owner_id": asset_request.owner_id,
        "name": asset_request.name,
        "description": asset_request.description,
        "category": asset_request.category,
        "price_per_day": asset_request.price_per_day,
        "currency": asset_request.currency,
        "location": location_json,
        "image_url": asset_request.image_url,
        "iot_device_id": asset_request.iot_device_id,
        "is_available": True,
        "active": True,
    }
    
    # Insert asset into database
    try:
        response = await _call_supabase(
            supabase.table("assets").insert(asset_data).execute
        )
        
        if not response.data or len(response.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create asset"
            )
        
        created_asset = response.data[0]
        
        # Fetch owner data
        owner_response = await _call_supabase(
            supabase.table("profiles")
            .select("*")
            .eq("id", asset_request.owner_id)
            .execute
        )
        
        owner_data = owner_response.data[0] if owner_response.data else None
        
        # Return formatted asset
        return _map_asset_from_db(created_asset, owner_data)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create asset: {str(e)}"
        )


@router.put("/{asset_id}")
async def update_asset(asset_id: str):
    """Update asset information"""
    # TODO: Implement asset update
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail=f"Update asset {asset_id} endpoint - TODO"
    )


@router.post("/{asset_id}/toggle-availability")
async def toggle_asset_availability(asset_id: str):
    """Toggle asset availability for rental"""
    # TODO: Implement toggle availability
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail=f"Toggle availability for asset {asset_id} endpoint - TODO"
    )
