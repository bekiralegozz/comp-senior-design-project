"""
NFT and Blockchain API Routes
Handles NFT minting, fractional ownership, and marketplace operations
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, List, Set
import logging
import json
from pathlib import Path

from app.services.web3_service import web3_service
from app.services.ipfs_service import ipfs_service
from app.services.alchemy_service import alchemy_service

# DEPRECATED: Supabase auth removed, SIWE coming in Faz 2
# from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/nft", tags=["NFT"])

# Token cache file path
TOKEN_CACHE_FILE = Path(__file__).parent.parent.parent.parent / "data" / "minted_tokens.json"

# Helper functions for token caching
def _load_minted_tokens() -> Set[int]:
    """Load minted token IDs from cache file"""
    try:
        if TOKEN_CACHE_FILE.exists():
            with open(TOKEN_CACHE_FILE, 'r') as f:
                data = json.load(f)
                return set(data.get('token_ids', []))
        return set()
    except Exception as e:
        logger.warning(f"Failed to load token cache: {e}")
        return set()

def _save_minted_token(token_id: int):
    """Add a token ID to the cache"""
    try:
        # Create data directory if it doesn't exist
        TOKEN_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing tokens
        tokens = _load_minted_tokens()
        tokens.add(token_id)
        
        # Save updated list
        with open(TOKEN_CACHE_FILE, 'w') as f:
            json.dump({'token_ids': sorted(list(tokens))}, f, indent=2)
        
        logger.info(f"Added token {token_id} to cache")
    except Exception as e:
        logger.error(f"Failed to save token to cache: {e}")


# ==================== Request/Response Models ====================

class PrepareMintRequest(BaseModel):
    """Request to prepare NFT mint (IPFS upload, validation)"""
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


class PrepareMintResponse(BaseModel):
    """Response from prepare mint (ready for user to sign)"""
    success: bool
    token_id: int
    metadata_uri: str
    contract_address: str
    function_data: str
    gas_estimate: str
    ipfs_image_url: str
    message: str


class ConfirmMintRequest(BaseModel):
    """Request to confirm mint after user signs transaction"""
    token_id: int = Field(..., description="Token ID that was minted")
    transaction_hash: str = Field(..., description="Transaction hash from blockchain")
    owner_address: str = Field(..., description="Owner's wallet address")


class MintNFTRequest(BaseModel):
    """DEPRECATED: Use PrepareMintRequest + ConfirmMintRequest for user-signed transactions"""
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


@router.post("/prepare-mint", response_model=PrepareMintResponse)
async def prepare_mint(request: PrepareMintRequest):
    """
    Prepare NFT mint (User will sign the transaction)
    
    Steps:
    1. Upload image to IPFS
    2. Create and upload metadata to IPFS
    3. Prepare transaction data (ABI encoded)
    4. Return data for user to sign in their wallet
    
    User flow:
    - Frontend calls this endpoint
    - Backend uploads to IPFS and prepares transaction
    - Frontend uses WalletConnect to get user signature
    - Frontend calls /confirm-mint with transaction hash
    """
    try:
        logger.info(f"Preparing NFT mint for asset: {request.asset_name}")
        
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
            address=request.address
        )
        
        if not metadata_uri:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to upload metadata to IPFS"
            )
        
        logger.info(f"Metadata uploaded: {metadata_uri}")
        
        # Get IPFS image URL for preview
        ipfs_image_url = ipfs_service.get_last_uploaded_image_url() or request.image_url
        
        # Step 3: Prepare transaction data (ABI encoded)
        # Function: mintInitialSupply(uint256 tokenId, address initialOwner, uint256 amount, string metadataURI)
        from web3 import Web3
        
        contract = web3_service.w3.eth.contract(
            address=Web3.to_checksum_address(web3_service.building_address),
            abi=web3_service.building_abi
        )
        
        # Encode function data
        function_data = contract.encodeABI(
            fn_name="mintInitialSupply",
            args=[
                request.token_id,
                Web3.to_checksum_address(request.owner_address),
                request.total_shares,
                metadata_uri
            ]
        )
        
        # Estimate gas
        gas_estimate = "0.05 POL"  # Rough estimate, actual will be calculated by wallet
        
        return PrepareMintResponse(
            success=True,
            token_id=request.token_id,
            metadata_uri=metadata_uri,
            contract_address=web3_service.building_address,
            function_data=function_data.hex() if isinstance(function_data, bytes) else function_data,
            gas_estimate=gas_estimate,
            ipfs_image_url=ipfs_image_url,
            message="Metadata uploaded to IPFS. Ready for user to sign transaction."
        )
        
    except Exception as e:
        logger.error(f"Error preparing NFT mint: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to prepare mint: {str(e)}"
        )


@router.post("/confirm-mint")
async def confirm_mint(request: ConfirmMintRequest):
    """
    Confirm NFT mint after user signs transaction
    
    This endpoint is called after the user signs and broadcasts
    the transaction from their wallet. It records the mint in
    our system for indexing and tracking.
    """
    try:
        logger.info(f"Confirming NFT mint: token_id={request.token_id}, tx={request.transaction_hash}")
        
        # Wait for transaction to be mined (with timeout)
        try:
            tx_receipt = web3_service.w3.eth.wait_for_transaction_receipt(
                request.transaction_hash, 
                timeout=120  # Wait up to 2 minutes
            )
        except Exception as wait_error:
            logger.warning(f"Transaction not mined yet: {wait_error}")
            # Save token to cache even if pending
            _save_minted_token(request.token_id)
            # Return success anyway - transaction is submitted
            return {
                "success": True,
                "token_id": request.token_id,
                "transaction_hash": request.transaction_hash,
                "opensea_url": f"https://opensea.io/assets/matic/{web3_service.building_address}/{request.token_id}",
                "message": "Transaction submitted! It may take a few moments to appear on blockchain.",
                "pending": True
            }
        
        if not tx_receipt or tx_receipt.status != 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Transaction failed or not found on blockchain"
            )
        
        # Get block number
        block_number = tx_receipt.blockNumber
        
        # Generate OpenSea URL
        opensea_url = f"https://opensea.io/assets/matic/{web3_service.building_address}/{request.token_id}"
        
        # Save token to cache for indexing
        _save_minted_token(request.token_id)
        
        return {
            "success": True,
            "token_id": request.token_id,
            "transaction_hash": request.transaction_hash,
            "block_number": block_number,
            "opensea_url": opensea_url,
            "message": "NFT mint confirmed successfully!"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error confirming NFT mint: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to confirm mint: {str(e)}"
        )


@router.post("/mint", response_model=MintNFTResponse)
async def mint_nft(request: MintNFTRequest):
    """
    DEPRECATED: Direct mint from backend (uses backend's private key)
    
    Use /prepare-mint + /confirm-mint for user-signed transactions instead.
    
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
            address=request.address
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


@router.get("/holdings/{wallet_address}")
async def get_user_holdings(wallet_address: str):
    """
    Get user's NFT holdings for Building1122 contract
    Uses Alchemy NFT API for reliable ownership data
    """
    try:
        response = await alchemy_service.get_nfts_for_owner(
            owner_address=wallet_address,
            contract_address=web3_service.building_address
        )
        
        # Alchemy returns {"ownedNfts": [...], "totalCount": ...}
        nfts = response.get("ownedNfts", [])
        
        # Transform to UserNftHolding format expected by Flutter
        holdings = []
        for nft in nfts:
            token_id = int(nft.get("tokenId", 0))
            balance = int(nft.get("balance", "1"))
            
            # Get metadata
            name = nft.get("name", "") or nft.get("title", "") or f"Asset #{token_id}"
            image_url = ""
            if nft.get("image"):
                image_url = nft["image"].get("cachedUrl") or nft["image"].get("originalUrl", "")
            elif nft.get("raw", {}).get("metadata", {}).get("image"):
                image_url = nft["raw"]["metadata"]["image"]
            
            # Get total supply from contract
            try:
                total_shares = web3_service.w3.eth.contract(
                    address=web3_service.building_address,
                    abi=web3_service.building_abi
                ).functions.totalSupply(token_id).call()
            except:
                total_shares = 1000  # Default
            
            holdings.append({
                "token_id": token_id,
                "name": name,
                "image_url": image_url,
                "shares": balance,
                "total_shares": total_shares,
                "ownership_percentage": (balance / total_shares * 100) if total_shares > 0 else 0,
                "estimated_value": "0"  # TODO: Add price oracle
            })
        
        return holdings
        
    except Exception as e:
        logger.error(f"Error fetching holdings: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch holdings: {str(e)}"
        )


@router.get("/assets")
async def list_assets(
    limit: int = 20,
    offset: int = 0,
    owner_address: Optional[str] = None
):
    """
    Get list of NFT assets
    
    If owner_address provided, returns assets owned by that address.
    Otherwise returns recent mints (from blockchain events).
    """
    try:
        # If owner filter exists, use Alchemy (reliable ownership, includes transfers)
        if owner_address:
            return await alchemy_service.owner_assets_smartrent_shape(
                owner_address=owner_address,
                contract_address=web3_service.building_address,
                limit=limit,
            )

        # No owner filter: this endpoint will be repurposed for Marketplace listings.
        # For now, return empty to avoid showing all minted tokens (as requested).
        return {
            "assets": [],
            "total": 0,
            "limit": limit,
            "offset": offset,
            "message": "Marketplace listings coming soon. Provide owner_address to list your NFTs.",
        }
            
    except Exception as e:
        logger.error(f"Error listing assets: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list assets: {str(e)}"
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
