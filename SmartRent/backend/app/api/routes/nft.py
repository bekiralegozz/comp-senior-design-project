"""
NFT and Blockchain API Routes
Handles NFT minting, fractional ownership, and marketplace operations
"""

from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, Field
from typing import Optional, List
import logging

from app.services.web3_service import web3_service
from app.services.ipfs_service import ipfs_service
from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/nft", tags=["NFT"])


# ==================== Request/Response Models ====================

class MintNFTRequest(BaseModel):
    token_id: int = Field(..., description="Unique token ID for the asset")
    owner_address: str = Field(..., description="Ethereum address of the owner")
    total_shares: int = Field(default=1000, description="Total fractional shares")
    asset_name: str = Field(..., description="Name of the asset")
    description: str = Field(..., description="Description of the asset")
    image_url: str = Field(..., description="URL of the asset image")
    property_type: str = Field(default="Apartment", description="Type of property")
    bedrooms: Optional[int] = None
    location: Optional[str] = None
    square_feet: Optional[int] = None
    address: Optional[str] = None
    rental_yield: Optional[str] = None
    estimated_value: Optional[str] = None


class MintNFTResponse(BaseModel):
    success: bool
    token_id: int
    metadata_uri: str
    transaction_hash: str
    block_number: int
    opensea_url: str


class AssetInfoResponse(BaseModel):
    token_id: int
    total_supply: int
    metadata_uri: str
    exists: bool
    opensea_url: str


class OwnershipResponse(BaseModel):
    token_id: int
    address: str
    shares: int
    percentage: float
    total_supply: int


class BuySharesRequest(BaseModel):
    token_id: int
    seller_address: str
    share_amount: int
    price_in_matic: float


class DistributeRentRequest(BaseModel):
    token_id: int
    owner_addresses: List[str]
    total_rent_matic: float


class TransactionResponse(BaseModel):
    success: bool
    transaction_hash: str
    block_number: Optional[int] = None
    error: Optional[str] = None


class BlockchainStatusResponse(BaseModel):
    connected: bool
    chain_id: int
    account_address: Optional[str] = None
    account_balance: Optional[float] = None
    building_contract: Optional[str] = None
    marketplace_contract: Optional[str] = None
    rental_manager_contract: Optional[str] = None


# ==================== Endpoints ====================

@router.get("/status", response_model=BlockchainStatusResponse)
async def get_blockchain_status():
    """Get blockchain connection and contract status"""
    try:
        connected = web3_service.is_connected()
        
        account_address = None
        account_balance = None
        
        if web3_service.account:
            account_address = web3_service.account.address
            account_balance = web3_service.get_balance(account_address)
        
        return BlockchainStatusResponse(
            connected=connected,
            chain_id=web3_service.chain_id,
            account_address=account_address,
            account_balance=account_balance,
            building_contract=web3_service.building_address,
            marketplace_contract=web3_service.marketplace_address,
            rental_manager_contract=web3_service.rental_manager_address
        )
    except Exception as e:
        logger.error(f"Error getting blockchain status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/mint", response_model=MintNFTResponse)
async def mint_nft(request: MintNFTRequest):
    """
    Mint a new fractional NFT asset
    
    Steps:
    1. Upload image to IPFS
    2. Create and upload metadata to IPFS
    3. Mint NFT on blockchain
    4. Return OpenSea URL
    """
    try:
        logger.info(f"Minting NFT for asset: {request.asset_name}")
        
        # Step 1 & 2: Upload to IPFS
        metadata_uri = ipfs_service.create_asset_metadata(
            asset_name=request.asset_name,
            description=request.description,
            image_url=request.image_url,
            property_type=request.property_type,
            bedrooms=request.bedrooms,
            location=request.location,
            total_shares=request.total_shares,
            square_feet=request.square_feet,
            address=request.address,
            rental_yield=request.rental_yield,
            estimated_value=request.estimated_value
        )
        
        if not metadata_uri:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to upload metadata to IPFS"
            )
        
        logger.info(f"Metadata uploaded: {metadata_uri}")
        
        # Step 3: Mint NFT on blockchain
        result = web3_service.mint_asset_nft(
            token_id=request.token_id,
            owner_address=request.owner_address,
            total_shares=request.total_shares,
            metadata_uri=metadata_uri
        )
        
        if not result["success"]:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Blockchain minting failed: {result.get('error')}"
            )
        
        # Step 4: Generate OpenSea URL
        opensea_url = f"https://opensea.io/assets/matic/{web3_service.building_address}/{request.token_id}"
        
        logger.info(f"NFT minted successfully. Token ID: {request.token_id}")
        
        return MintNFTResponse(
            success=True,
            token_id=request.token_id,
            metadata_uri=metadata_uri,
            transaction_hash=result["transaction_hash"],
            block_number=result["block_number"],
            opensea_url=opensea_url
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error minting NFT: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/asset/{token_id}", response_model=AssetInfoResponse)
async def get_asset_info(token_id: int):
    """Get NFT asset information from blockchain"""
    try:
        asset_info = web3_service.get_asset_info(token_id)
        
        if not asset_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asset with token ID {token_id} not found"
            )
        
        opensea_url = f"https://opensea.io/assets/matic/{web3_service.building_address}/{token_id}"
        
        return AssetInfoResponse(
            **asset_info,
            opensea_url=opensea_url
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting asset info: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/ownership/{token_id}/{address}", response_model=OwnershipResponse)
async def get_ownership(token_id: int, address: str):
    """Get ownership information for an address"""
    try:
        shares = web3_service.get_share_balance(token_id, address)
        percentage = web3_service.get_ownership_percentage(token_id, address)
        
        asset_info = web3_service.get_asset_info(token_id)
        if not asset_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asset with token ID {token_id} not found"
            )
        
        return OwnershipResponse(
            token_id=token_id,
            address=address,
            shares=shares,
            percentage=percentage,
            total_supply=asset_info["total_supply"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting ownership: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/buy-shares", response_model=TransactionResponse)
async def buy_shares(request: BuySharesRequest):
    """Purchase fractional shares from marketplace"""
    try:
        result = web3_service.buy_shares(
            token_id=request.token_id,
            seller_address=request.seller_address,
            share_amount=request.share_amount,
            price_in_matic=request.price_in_matic
        )
        
        if not result["success"]:
            return TransactionResponse(
                success=False,
                transaction_hash="",
                error=result.get("error")
            )
        
        return TransactionResponse(
            success=True,
            transaction_hash=result["transaction_hash"],
            block_number=result.get("block_number")
        )
        
    except Exception as e:
        logger.error(f"Error buying shares: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/distribute-rent", response_model=TransactionResponse)
async def distribute_rent(request: DistributeRentRequest):
    """Distribute rent payment to fractional owners"""
    try:
        result = web3_service.distribute_rent(
            token_id=request.token_id,
            owner_addresses=request.owner_addresses,
            total_rent_matic=request.total_rent_matic
        )
        
        if not result["success"]:
            return TransactionResponse(
                success=False,
                transaction_hash="",
                error=result.get("error")
            )
        
        return TransactionResponse(
            success=True,
            transaction_hash=result["transaction_hash"],
            block_number=result.get("block_number")
        )
        
    except Exception as e:
        logger.error(f"Error distributing rent: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/transaction/{tx_hash}")
async def get_transaction(tx_hash: str):
    """Get transaction details"""
    try:
        receipt = web3_service.get_transaction_receipt(tx_hash)
        
        if not receipt:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transaction not found"
            )
        
        return receipt
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting transaction: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/ipfs/test")
async def test_ipfs():
    """Test IPFS/Pinata connection"""
    try:
        authenticated = ipfs_service.test_authentication()
        
        return {
            "success": authenticated,
            "message": "Pinata connection successful" if authenticated else "Pinata authentication failed"
        }
        
    except Exception as e:
        logger.error(f"Error testing IPFS: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
