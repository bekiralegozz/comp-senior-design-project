"""
Rentals API routes
"""

from datetime import datetime, date
from typing import Optional, Dict, Any
from uuid import UUID

import anyio
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps.auth import require_verified_email
from app.core.supabase_client import get_supabase_client
from app.api.routes.assets import _map_asset_from_db, _format_location

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


class CreateRentalRequest(BaseModel):
    """Request model for creating a rental"""
    asset_id: str  # UUID
    renter_id: str  # UUID - from frontend
    start_date: date
    end_date: date
    total_price_usd: Optional[float] = None
    payment_tx_hash: Optional[str] = None


@router.post("/", status_code=status.HTTP_410_GONE, deprecated=True)
async def create_rental(rental_request: CreateRentalRequest):
    """
    [DEPRECATED] Create a new rental agreement
    
    ⚠️ This endpoint is deprecated and will be removed.
    In decentralized architecture, rent payments happen directly on blockchain
    via mobile app wallet interaction.
    
    Use: Mobile App → WalletConnect → RentalManager.payRent()
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail={
            "error": "Endpoint deprecated",
            "message": "Rent payment now happens on blockchain via mobile app",
            "migration": "Use mobile app wallet to call RentalManager.payRent()",
            "contract": "0x57044386A0C5Fb623315Dd5b8eeEA6078Bb9193C"
        }
    )
    
    # Old implementation kept for reference
    supabase = get_supabase_client(use_service_role=True)
    
    # Validate dates
    if rental_request.start_date >= rental_request.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End date must be after start date"
        )
    
    # Check if asset exists and is available
    asset_response = await _call_supabase(
        supabase.table("assets")
        .select("*")
        .eq("id", rental_request.asset_id)
        .execute
    )
    
    if not asset_response.data or len(asset_response.data) == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asset not found"
        )
    
    asset = asset_response.data[0]
    if not asset.get("is_available", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Asset is not available for rent"
        )
    
    # Prepare rental data for database
    rental_data = {
        "asset_id": rental_request.asset_id,
        "renter_id": rental_request.renter_id,
        "start_date": rental_request.start_date.isoformat(),
        "end_date": rental_request.end_date.isoformat(),
        "status": "pending",
        "total_price_usd": rental_request.total_price_usd,
        "payment_tx_hash": rental_request.payment_tx_hash,
    }
    
    # Insert rental into database
    try:
        response = await _call_supabase(
            supabase.table("rentals").insert(rental_data).execute
        )
        
        if not response.data or len(response.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create rental"
            )
        
        created_rental = response.data[0]
        
        return {
            "rental": created_rental,
            "message": "Rental created successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create rental: {str(e)}"
        )


@router.get("/{rental_id}")
async def get_rental(rental_id: int):
    """Get rental by ID"""
    # TODO: Implement get rental
    return {"message": f"Get rental {rental_id} endpoint - TODO"}


@router.get("/")
async def list_rentals(
    skip: int = 0,
    limit: int = 20,
    status_filter: Optional[str] = None,
    renter_id: Optional[int] = None,
    asset_id: Optional[int] = None
):
    """List all rentals with optional filters"""
    # TODO: Implement list rentals
    return {
        "message": "List rentals endpoint - TODO",
        "skip": skip,
        "limit": limit,
        "status_filter": status_filter,
        "renter_id": renter_id,
        "asset_id": asset_id
    }


@router.get("/user/{user_id}")
async def get_rentals_by_user(user_id: str):
    """Get all rentals for a user (as renter)"""
    supabase = get_supabase_client(use_service_role=True)
    
    try:
        # Get rentals where user is the renter with asset and owner join
        response = await _call_supabase(
            supabase.table("rentals")
            .select("*, assets(*, profiles!assets_owner_id_fkey(*))")
            .eq("renter_id", user_id)
            .order("created_at", desc=True)
            .execute
        )
        
        if not response.data:
            return []
        
        # Format response - convert assets to camelCase format
        formatted_rentals = []
        for rental in response.data:
            formatted_rental = {
                "id": rental.get("id"),
                "asset_id": rental.get("asset_id"),
                "renter_id": rental.get("renter_id"),
                "start_date": rental.get("start_date"),
                "end_date": rental.get("end_date"),
                "status": rental.get("status"),
                "total_price_usd": rental.get("total_price_usd"),
                "payment_tx_hash": rental.get("payment_tx_hash"),
                "created_at": rental.get("created_at"),
                "updated_at": rental.get("updated_at"),
            }
            
            # Format asset data if present
            asset_data = rental.get("assets")
            if asset_data:
                # Extract owner data if joined
                owner_data = None
                if isinstance(asset_data, dict):
                    profiles = asset_data.get("profiles")
                    if profiles:
                        owner_data = profiles if isinstance(profiles, dict) else profiles[0] if isinstance(profiles, list) and profiles else None
                    # Remove profiles from asset_data before mapping
                    asset_data_clean = {k: v for k, v in asset_data.items() if k != "profiles"}
                else:
                    asset_data_clean = asset_data
                
                # Map asset to camelCase format
                formatted_asset = _map_asset_from_db(asset_data_clean, owner_data)
                formatted_rental["asset"] = formatted_asset.dict()
            
            formatted_rentals.append(formatted_rental)
        
        return formatted_rentals
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch rentals: {str(e)}"
        )


@router.post("/{rental_id}/activate", deprecated=True, status_code=status.HTTP_410_GONE)
async def activate_rental(rental_id: int):
    """
    [DEPRECATED] Activate/start a rental
    
    ⚠️ This endpoint is deprecated.
    Rental activation happens automatically on blockchain when rent is paid.
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail={
            "error": "Endpoint deprecated",
            "message": "Rental activation is automatic on blockchain",
            "migration": "Pay rent via RentalManager.payRent() to activate rental"
        }
    )


@router.post("/{rental_id}/complete", deprecated=True, status_code=status.HTTP_410_GONE)
async def complete_rental(rental_id: int):
    """
    [DEPRECATED] Complete a rental
    
    ⚠️ This endpoint is deprecated.
    Rental completion is tracked on blockchain via events.
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail={
            "error": "Endpoint deprecated",
            "message": "Rental completion tracked on blockchain",
            "migration": "Read rental status from blockchain events"
        }
    )


@router.post("/{rental_id}/cancel", deprecated=True, status_code=status.HTTP_410_GONE)
async def cancel_rental(rental_id: int):
    """
    [DEPRECATED] Cancel a rental
    
    ⚠️ This endpoint is deprecated.
    Rental cancellation should be handled on blockchain.
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail={
            "error": "Endpoint deprecated",
            "message": "Rental cancellation handled on blockchain",
            "migration": "Implement cancellation logic in smart contract if needed"
        }
    )
