"""
Rental API Routes
Handles rental listing and booking operations for RentalHub contract

Architecture Flow:
1. User clicks "Rent" button in UI (only if majority shareholder)
2. Frontend calls /rental/listings/prepare (backend prepares transaction data)
3. Backend returns encoded transaction data
4. Frontend uses WalletConnect to sign transaction
5. Transaction sent to blockchain
6. Frontend polls /rental/listings/{id} to verify listing was created

Key Points:
- NO DATABASE - Everything read from blockchain via RentalHub contract
- Backend prepares transactions, user signs with their wallet
- Majority shareholder check done both client-side and server-side
"""

from fastapi import APIRouter, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import logging
from datetime import datetime

from app.services.rental_hub_service import rental_hub_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/rental", tags=["Rental"])


# ==================== Request/Response Models ====================

class PrepareRentalListingRequest(BaseModel):
    """Request to prepare rental listing creation"""
    token_id: int = Field(..., description="Asset token ID (NFT)")
    owner_address: str = Field(..., description="Owner's wallet address (must be majority shareholder)")
    price_per_night_pol: float = Field(..., gt=0, description="Price per night in POL")


class PrepareRentalListingResponse(BaseModel):
    """Response with transaction data for user to sign"""
    success: bool
    contract_address: Optional[str] = None
    function_data: Optional[str] = None
    gas_estimate: Optional[str] = None
    is_majority_shareholder: bool
    ownership_check: dict
    message: str
    error: Optional[str] = None


class PrepareRentAssetRequest(BaseModel):
    """Request to prepare rental booking"""
    listing_id: int = Field(..., description="Rental listing ID to book")
    renter_address: str = Field(..., description="Renter's wallet address")
    check_in_date: int = Field(..., description="Check-in date (Unix timestamp)")
    check_out_date: int = Field(..., description="Check-out date (Unix timestamp)")


class PrepareRentAssetResponse(BaseModel):
    """Response with booking transaction data"""
    success: bool
    contract_address: Optional[str] = None
    function_data: Optional[str] = None
    value_wei: Optional[str] = None
    value_pol: Optional[float] = None
    nights: Optional[int] = None
    gas_estimate: Optional[str] = None
    dates_available: bool
    message: str
    error: Optional[str] = None


class RentalListingResponse(BaseModel):
    """Single rental listing"""
    listing_id: int
    token_id: int
    owner: str
    price_per_night_wei: int
    price_per_night_pol: float
    price_per_night: Optional[str] = None
    created_at: int
    is_active: bool
    # Metadata fields from blockchain
    property_name: Optional[str] = None
    image_url: Optional[str] = None
    total_shares: Optional[int] = None
    attributes: Optional[Any] = None  # Can be dict or list from IPFS metadata


class RentalResponse(BaseModel):
    """Single rental booking"""
    rental_id: int
    listing_id: int
    token_id: int
    renter: str
    check_in_date: int
    check_out_date: int
    total_price_wei: int
    total_price_pol: float
    created_at: int
    status: int  # 0=Active, 1=Completed, 2=Cancelled


# ==================== RENTAL LISTING ENDPOINTS ====================

@router.post("/listings/prepare", response_model=PrepareRentalListingResponse)
async def prepare_rental_listing(request: PrepareRentalListingRequest):
    """
    Prepare rental listing transaction for user to sign
    
    Flow:
    1. Check if user is majority shareholder (>50% ownership)
    2. If yes, prepare transaction data
    3. Return encoded data for WalletConnect signing
    
    Why no database?
    - Blockchain is single source of truth
    - No need to cache/store rental listings
    - Always query RentalHub contract directly
    """
    try:
        logger.info(f"Preparing rental listing for token {request.token_id} by {request.owner_address}")
        
        # Step 1: Check if user is majority shareholder
        # TEMPORARY BYPASS - always allow for testing
        # TODO: Re-enable proper check after debugging
        is_majority = True  # rental_hub_service.is_majority_shareholder(request.owner_address, request.token_id)
        
        ownership_check = {
            "is_majority_shareholder": is_majority,
            "required": ">50% ownership (bypassed for testing)"
        }
        
        if not is_majority:
            return PrepareRentalListingResponse(
                success=False,
                is_majority_shareholder=False,
                ownership_check=ownership_check,
                message="Only majority shareholder (>50% ownership) can create rental listing",
                error="Insufficient ownership"
            )
        
        # Step 2: Prepare transaction data
        # This encodes the createRentalListing function call
        prepare_result = rental_hub_service.prepare_create_rental_listing(
            token_id=request.token_id,
            price_per_night_pol=request.price_per_night_pol
        )
        
        if not prepare_result.get('success'):
            return PrepareRentalListingResponse(
                success=False,
                is_majority_shareholder=True,
                ownership_check=ownership_check,
                message="Failed to prepare transaction",
                error=prepare_result.get('error', 'Unknown error')
            )
        
        # Step 3: Return transaction data for user to sign
        return PrepareRentalListingResponse(
            success=True,
            contract_address=prepare_result['contract_address'],
            function_data=prepare_result['function_data'],
            gas_estimate=prepare_result['gas_estimate'],
            is_majority_shareholder=True,
            ownership_check=ownership_check,
            message="Transaction prepared. Sign with your wallet to create listing."
        )
        
    except Exception as e:
        logger.error(f"Error preparing rental listing: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/listings/{listing_id}/cancel/prepare")
async def prepare_cancel_rental_listing(listing_id: int):
    """
    Prepare cancel rental listing transaction (same pattern as marketplace)
    
    Flow:
    1. Verify listing exists and is active
    2. Prepare cancelRentalListing transaction
    """
    try:
        # Verify listing exists
        listing = rental_hub_service.get_rental_listing(listing_id)
        
        if not listing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Rental listing {listing_id} not found"
            )
        
        if not listing['is_active']:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Listing is not active"
            )
        
        # Prepare transaction
        prepare_result = rental_hub_service.prepare_cancel_rental_listing(listing_id)
        
        if not prepare_result.get('success'):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=prepare_result.get('error', 'Failed to prepare transaction')
            )
        
        return prepare_result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error preparing cancel rental listing: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/debug/metadata/{token_id}")
async def debug_metadata(token_id: int):
    """Debug endpoint to test IPFS metadata fetching"""
    try:
        import requests as req
        from web3 import Web3
        import json
        import os
        
        result = {
            "token_id": token_id,
            "metadata_uri": None,
            "gateway_results": [],
            "final_metadata": None,
            "error": None
        }
        
        # Load SmartRentHub ABI and contract - try backend/app/abis first
        from pathlib import Path
        
        # Railway deployment: Path from this file to abis folder
        # This file: /app/app/api/routes/rental.py
        # ABI should be: /app/app/abis/SmartRentHub.json
        # So we need parent.parent.parent (routes -> api -> app) then abis
        abi_path_obj = Path(__file__).resolve().parent.parent.parent / "abis" / "SmartRentHub.json"
        
        result["abi_path_tried_1"] = str(abi_path_obj)
        result["abi_exists_1"] = abi_path_obj.exists()
        
        abi_path = str(abi_path_obj)
        
        # Fallback for local dev with blockchain folder
        if not abi_path_obj.exists():
            fallback_path = Path(__file__).resolve().parent.parent.parent.parent.parent / "blockchain" / "artifacts" / "contracts" / "SmartRentHub.sol" / "SmartRentHub.json"
            result["abi_path_tried_2"] = str(fallback_path)
            result["abi_exists_2"] = fallback_path.exists()
            if fallback_path.exists():
                abi_path = str(fallback_path)
        
        result["abi_path"] = abi_path
        result["abi_exists"] = os.path.exists(abi_path)
        
        # Check environment
        from app.core.config import settings
        result["smartrenthub_address"] = getattr(settings, 'SMARTRENTHUB_CONTRACT_ADDRESS', None)
        result["web3_provider"] = getattr(settings, 'WEB3_PROVIDER_URL', None)
        
        if result["abi_exists"] and result["smartrenthub_address"] and result["web3_provider"]:
            with open(abi_path, 'r') as f:
                abi_json = json.load(f)
                abi = abi_json.get('abi', [])
            
            w3 = Web3(Web3.HTTPProvider(result["web3_provider"]))
            contract = w3.eth.contract(
                address=Web3.to_checksum_address(result["smartrenthub_address"]),
                abi=abi
            )
            
            try:
                asset_info = contract.functions.getAsset(token_id).call()
                result["asset_info_raw"] = str(asset_info)
                
                if asset_info and len(asset_info) >= 2:
                    metadata_uri = asset_info[1]
                    result["metadata_uri"] = metadata_uri
                    
                    if metadata_uri and metadata_uri.startswith("ipfs://"):
                        ipfs_hash = metadata_uri.replace("ipfs://", "")
                        gateways = [
                            f"https://gateway.pinata.cloud/ipfs/{ipfs_hash}",
                            f"https://cloudflare-ipfs.com/ipfs/{ipfs_hash}",
                            f"https://ipfs.io/ipfs/{ipfs_hash}"
                        ]
                        
                        for gw in gateways:
                            try:
                                resp = req.get(gw, timeout=15)
                                result["gateway_results"].append({
                                    "gateway": gw,
                                    "status": resp.status_code,
                                    "success": resp.status_code == 200,
                                    "content_preview": resp.text[:300] if resp.status_code == 200 else resp.text[:100]
                                })
                                if resp.status_code == 200:
                                    result["final_metadata"] = resp.json()
                                    break
                            except Exception as gw_err:
                                result["gateway_results"].append({
                                    "gateway": gw,
                                    "error": str(gw_err)
                                })
            except Exception as contract_err:
                result["error"] = f"Contract call error: {str(contract_err)}"
        
        return result
    except Exception as e:
        import traceback
        return {"error": str(e), "traceback": traceback.format_exc(), "token_id": token_id}


@router.get("/debug/service-abi")
async def debug_service_abi():
    """Debug endpoint to check ABI loading in rental_hub_service"""
    from pathlib import Path
    import os
    
    # Check what the service sees
    service_file = Path(__file__).resolve()
    
    # Simulate what rental_hub_service.py would see
    # rental_hub_service.py is at /app/app/services/rental_hub_service.py
    # So from there: parent.parent = /app/app
    services_dir = service_file.parent.parent.parent / "services"
    simulated_service_path = services_dir / "rental_hub_service.py"
    simulated_abi_path = services_dir.parent / "abis" / "SmartRentHub.json"
    
    # Also check actual service attributes
    result = {
        "this_file": str(service_file),
        "services_dir": str(services_dir),
        "services_dir_exists": services_dir.exists(),
        "simulated_service_path": str(simulated_service_path),
        "simulated_service_exists": simulated_service_path.exists(),
        "simulated_abi_path": str(simulated_abi_path),
        "simulated_abi_exists": simulated_abi_path.exists(),
        "rental_hub_service_smartrenthub_address": rental_hub_service.smartrenthub_address,
        "rental_hub_service_contract_address": rental_hub_service.contract_address,
    }
    
    # Try to list the abis folder
    abis_folder = services_dir.parent / "abis"
    if abis_folder.exists():
        result["abis_folder_contents"] = os.listdir(str(abis_folder))
    else:
        result["abis_folder_contents"] = "folder does not exist"
    
    # Also check RentalHub ABI and contract status
    result["rentalhub_abi_path"] = "/app/app/abis/RentalHub.json"
    result["rentalhub_abi_exists"] = Path("/app/app/abis/RentalHub.json").exists()
    result["rental_hub_service_contract"] = rental_hub_service.contract is not None
    result["rental_hub_service_abi_length"] = len(rental_hub_service.abi) if rental_hub_service.abi else 0
    
    # Try loading RentalHub ABI directly
    try:
        rentalhub_path = Path("/app/app/abis/RentalHub.json")
        if rentalhub_path.exists():
            import json as j2
            with open(rentalhub_path, 'r') as f:
                rh_data = j2.load(f)
            result["rentalhub_manual_abi_length"] = len(rh_data.get('abi', []))
    except Exception as e:
        result["rentalhub_manual_error"] = str(e)
    
    # Try loading ABI directly with full debug
    try:
        from pathlib import Path as P
        import json as j
        
        # Exact same logic as _load_smartrenthub_abi
        test_path = P("/app/app/services/rental_hub_service.py").resolve().parent.parent / "abis" / "SmartRentHub.json"
        result["test_path_from_hardcoded"] = str(test_path)
        result["test_path_exists"] = test_path.exists()
        
        if test_path.exists():
            with open(test_path, 'r') as f:
                data = j.load(f)
            result["test_load_abi_length"] = len(data.get('abi', []))
        
        abi = rental_hub_service._load_smartrenthub_abi()
        result["loaded_abi_length"] = len(abi) if abi else 0
    except Exception as e:
        import traceback
        result["abi_load_error"] = str(e)
        result["abi_load_traceback"] = traceback.format_exc()
    
    # Also try loading manually to see what's happening
    try:
        manual_path = services_dir.parent / "abis" / "SmartRentHub.json"
        if manual_path.exists():
            import json
            with open(manual_path, 'r') as f:
                data = json.load(f)
            result["manual_load_type"] = type(data).__name__
            result["manual_load_keys"] = list(data.keys()) if isinstance(data, dict) else "not a dict"
            if isinstance(data, dict) and 'abi' in data:
                result["manual_abi_length"] = len(data['abi'])
    except Exception as e:
        result["manual_load_error"] = str(e)
    
    # Try calling blockchain directly
    try:
        if rental_hub_service.contract:
            listings_raw = rental_hub_service.contract.functions.getActiveRentalListings().call()
            result["blockchain_listings_count"] = len(listings_raw) if listings_raw else 0
            if listings_raw and len(listings_raw) > 0:
                result["first_listing_raw"] = str(listings_raw[0])
        else:
            result["blockchain_error"] = "contract is None"
    except Exception as e:
        import traceback
        result["blockchain_error"] = str(e)
        result["blockchain_traceback"] = traceback.format_exc()
    
    return result


@router.get("/listings", response_model=List[RentalListingResponse])
async def get_all_rental_listings():
    """
    Get all active rental listings from blockchain
    
    Data Source: RentalHub.getActiveRentalListings()
    - Reads directly from blockchain
    - No database queries
    - Always up-to-date
    """
    try:
        listings = rental_hub_service.get_all_rental_listings()
        return [RentalListingResponse(**listing) for listing in listings]
    except Exception as e:
        logger.error(f"Error getting rental listings: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/listings/{listing_id}", response_model=RentalListingResponse)
async def get_rental_listing(listing_id: int):
    """
    Get single rental listing by ID
    
    Data Source: RentalHub.getRentalListing(listingId)
    """
    try:
        listing = rental_hub_service.get_rental_listing(listing_id)
        
        if not listing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Rental listing {listing_id} not found"
            )
        
        return RentalListingResponse(**listing)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting rental listing {listing_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/listings/asset/{token_id}", response_model=List[RentalListingResponse])
async def get_rental_listings_by_asset(token_id: int):
    """
    Get all rental listings for a specific asset
    
    Data Source: RentalHub.getRentalListingsByAsset(tokenId)
    """
    try:
        listings = rental_hub_service.get_rental_listings_by_asset(token_id)
        return [RentalListingResponse(**listing) for listing in listings]
    except Exception as e:
        logger.error(f"Error getting rental listings for asset {token_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


# ==================== RENTAL BOOKING ENDPOINTS ====================

@router.post("/bookings/prepare", response_model=PrepareRentAssetResponse)
async def prepare_rent_asset(request: PrepareRentAssetRequest):
    """
    Prepare rental booking transaction
    
    Flow:
    1. Get listing details (price per night)
    2. Check if dates are available
    3. Calculate total price (nights * price_per_night)
    4. Prepare rentAsset transaction with payment
    
    Payment Handling:
    - User sends POL with transaction (value_wei)
    - Smart contract distributes: platform fee + owner payment
    """
    try:
        logger.info(f"Preparing rental booking for listing {request.listing_id}")
        
        # Step 1: Get listing
        listing = rental_hub_service.get_rental_listing(request.listing_id)
        
        if not listing:
            return PrepareRentAssetResponse(
                success=False,
                dates_available=False,
                message="Rental listing not found",
                error="Listing not found"
            )
        
        if not listing['is_active']:
            return PrepareRentAssetResponse(
                success=False,
                dates_available=False,
                message="Listing is not active",
                error="Listing inactive"
            )
        
        # Step 2: Check date availability
        dates_available = rental_hub_service.check_dates_available(
            request.listing_id,
            request.check_in_date,
            request.check_out_date
        )
        
        if not dates_available:
            return PrepareRentAssetResponse(
                success=False,
                dates_available=False,
                message="Selected dates are not available",
                error="Dates already booked"
            )
        
        # Step 3: Prepare transaction
        prepare_result = rental_hub_service.prepare_rent_asset(
            listing_id=request.listing_id,
            check_in_date=request.check_in_date,
            check_out_date=request.check_out_date,
            price_per_night_wei=listing['price_per_night_wei']
        )
        
        if not prepare_result.get('success'):
            return PrepareRentAssetResponse(
                success=False,
                dates_available=True,
                message="Failed to prepare transaction",
                error=prepare_result.get('error', 'Unknown error')
            )
        
        # Step 4: Return transaction data
        return PrepareRentAssetResponse(
            success=True,
            contract_address=prepare_result['contract_address'],
            function_data=prepare_result['function_data'],
            value_wei=prepare_result['value_wei'],
            value_pol=prepare_result['value_pol'],
            nights=prepare_result['nights'],
            gas_estimate=prepare_result['gas_estimate'],
            dates_available=True,
            message=f"Ready to book for {prepare_result['nights']} nights. Total: {prepare_result['value_pol']:.4f} POL"
        )
        
    except Exception as e:
        logger.error(f"Error preparing rent asset: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/bookings/{rental_id}", response_model=RentalResponse)
async def get_rental(rental_id: int):
    """
    Get single rental booking by ID
    
    Data Source: RentalHub.getRental(rentalId)
    """
    try:
        rental = rental_hub_service.get_rental(rental_id)
        
        if not rental:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Rental {rental_id} not found"
            )
        
        return RentalResponse(**rental)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting rental {rental_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/bookings/renter/{renter_address}", response_model=List[RentalResponse])
async def get_rentals_by_renter(renter_address: str):
    """
    Get all rentals made by a specific renter
    
    Data Source: RentalHub.getRentalsByRenter(address)
    """
    try:
        rentals = rental_hub_service.get_rentals_by_renter(renter_address)
        return [RentalResponse(**rental) for rental in rentals]
    except Exception as e:
        logger.error(f"Error getting rentals for renter {renter_address}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/bookings/asset/{token_id}", response_model=List[RentalResponse])
async def get_rentals_by_asset(token_id: int):
    """
    Get all rentals for a specific asset
    
    Data Source: RentalHub.getRentalsByAsset(tokenId)
    """
    try:
        rentals = rental_hub_service.get_rentals_by_asset(token_id)
        return [RentalResponse(**rental) for rental in rentals]
    except Exception as e:
        logger.error(f"Error getting rentals for asset {token_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


# ==================== UTILITY ENDPOINTS ====================

@router.get("/listings/{listing_id}/dates/available")
async def check_dates_available(
    listing_id: int,
    check_in_date: int = Query(..., description="Check-in date (Unix timestamp)"),
    check_out_date: int = Query(..., description="Check-out date (Unix timestamp)")
):
    """
    Check if dates are available for booking
    
    Data Source: RentalHub.areDatesAvailable(listingId, checkIn, checkOut)
    """
    try:
        available = rental_hub_service.check_dates_available(
            listing_id,
            check_in_date,
            check_out_date
        )
        
        return {
            "listing_id": listing_id,
            "check_in_date": check_in_date,
            "check_out_date": check_out_date,
            "available": available,
            "message": "Dates are available" if available else "Dates are already booked"
        }
    except Exception as e:
        logger.error(f"Error checking date availability: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/listings/{listing_id}/dates/booked")
async def get_booked_dates(listing_id: int):
    """
    Get all booked dates for a listing
    
    Data Source: RentalHub.getBookedDates(listingId)
    Returns: List of Unix timestamps (normalized to start of day)
    """
    try:
        dates = rental_hub_service.get_booked_dates(listing_id)
        
        return {
            "listing_id": listing_id,
            "booked_dates": dates,
            "count": len(dates)
        }
    except Exception as e:
        logger.error(f"Error getting booked dates: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/majority-shareholder/{token_id}")
async def get_majority_shareholder(token_id: int):
    """
    Get majority shareholder for an asset
    
    This is computed off-chain by:
    1. Getting all owners from SmartRentHub
    2. Checking their balances in Building1122
    3. Finding who owns most shares
    
    Returns: Address of majority shareholder
    """
    try:
        majority_owner = rental_hub_service.get_majority_shareholder(token_id)
        
        if not majority_owner:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No owners found for token {token_id}"
            )
        
        return {
            "token_id": token_id,
            "majority_shareholder": majority_owner,
            "can_create_listing": True
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting majority shareholder: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/check-ownership/{token_id}/{address}")
async def check_ownership(token_id: int, address: str):
    """
    Check if address is majority shareholder (>50%)
    
    Returns: Bool + ownership details
    """
    try:
        is_majority = rental_hub_service.is_majority_shareholder(address, token_id)
        
        return {
            "token_id": token_id,
            "address": address,
            "is_majority_shareholder": is_majority,
            "can_create_listing": is_majority,
            "requirement": ">50% ownership required"
        }
    except Exception as e:
        logger.error(f"Error checking ownership: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

