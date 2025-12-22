"""
Blockchain Read-Only API Routes
Query blockchain data for assets, ownership, and rentals
"""
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.services.blockchain_reader import get_blockchain_reader

router = APIRouter()


# ========== Response Models ==========

class TokenBalanceResponse(BaseModel):
    """Token balance response"""
    owner_address: str
    token_id: int
    balance: int
    total_supply: int
    ownership_percentage: float  # Percentage (0-100)


class AssetOnChainResponse(BaseModel):
    """On-chain asset data"""
    token_id: int
    exists: bool
    total_supply: int
    metadata_uri: Optional[str] = None


class RentPaymentResponse(BaseModel):
    """Rent payment response"""
    payer: str
    amount_wei: int
    amount_eth: float
    timestamp: int


class RentStatsResponse(BaseModel):
    """Rent statistics for an asset"""
    asset_id: int
    total_rent_collected_wei: int
    total_rent_collected_eth: float
    payment_count: int
    payments: List[RentPaymentResponse]


class MarketplaceInfoResponse(BaseModel):
    """Marketplace contract info"""
    platform_fee_percentage: float  # 2.5 means 2.5%
    fee_recipient: str


# ========== Ownership & Balance Routes ==========

@router.get("/ownership/{token_id}/{owner_address}", response_model=TokenBalanceResponse)
async def get_ownership(token_id: int, owner_address: str):
    """
    Get ownership information for a specific owner and asset
    
    Returns balance, total supply, and ownership percentage
    """
    try:
        reader = get_blockchain_reader()
        
        # Check if token exists
        if not reader.token_exists(token_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asset token {token_id} does not exist on blockchain"
            )
        
        # Get balance and total supply
        balance = reader.get_token_balance(owner_address, token_id)
        total_supply = reader.get_total_supply(token_id)
        
        # Get ownership percentage (in basis points)
        ownership_bps = reader.get_ownership_percentage(owner_address, token_id)
        ownership_percentage = ownership_bps / 100  # Convert bps to percentage
        
        return TokenBalanceResponse(
            owner_address=owner_address,
            token_id=token_id,
            balance=balance,
            total_supply=total_supply,
            ownership_percentage=ownership_percentage
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch ownership data: {str(e)}"
        )


@router.get("/balance/{owner_address}")
async def get_wallet_balance(owner_address: str):
    """Get ETH balance for a wallet address"""
    try:
        reader = get_blockchain_reader()
        balance_wei = reader.get_eth_balance(owner_address)
        balance_eth = reader.wei_to_eth(balance_wei)
        
        return {
            "address": owner_address,
            "balance_wei": balance_wei,
            "balance_eth": balance_eth
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch balance: {str(e)}"
        )


# ========== Asset Routes ==========

@router.get("/assets/{token_id}", response_model=AssetOnChainResponse)
async def get_asset_on_chain(token_id: int):
    """
    Get on-chain asset data
    
    Returns token existence, supply, and metadata URI
    """
    try:
        reader = get_blockchain_reader()
        
        exists = reader.token_exists(token_id)
        
        if not exists:
            return AssetOnChainResponse(
                token_id=token_id,
                exists=False,
                total_supply=0,
                metadata_uri=None
            )
        
        total_supply = reader.get_total_supply(token_id)
        metadata_uri = reader.get_asset_metadata_uri(token_id)
        
        return AssetOnChainResponse(
            token_id=token_id,
            exists=True,
            total_supply=total_supply,
            metadata_uri=metadata_uri if metadata_uri else None
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch asset data: {str(e)}"
        )


@router.get("/assets/{token_id}/owners")
async def get_asset_owners(token_id: int):
    """
    Get all owners of an asset token
    
    Note: This requires event querying or off-chain indexing
    Returns asset initialized event for now
    """
    try:
        reader = get_blockchain_reader()
        
        # Check if token exists
        if not reader.token_exists(token_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asset token {token_id} does not exist"
            )
        
        # Get AssetInitialized event
        events = reader.get_asset_initialized_events(token_id=token_id)
        
        if not events:
            return {
                "token_id": token_id,
                "initial_owner": None,
                "message": "Asset exists but no initialization event found"
            }
        
        # Return initial owner (first event)
        initial_event = events[0]
        
        return {
            "token_id": token_id,
            "initial_owner": initial_event.get('args', {}).get('initialOwner'),
            "total_supply": initial_event.get('args', {}).get('totalSupply'),
            "block_number": initial_event.get('blockNumber'),
            "transaction_hash": initial_event.get('transactionHash').hex() if initial_event.get('transactionHash') else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch asset owners: {str(e)}"
        )


# ========== Rental Routes ==========

@router.get("/rentals/{asset_id}/stats", response_model=RentStatsResponse)
async def get_rental_stats(asset_id: int, include_payments: bool = True):
    """
    Get rental statistics for an asset
    
    Returns total rent collected and payment history
    """
    try:
        reader = get_blockchain_reader()
        
        # Check if asset exists
        if not reader.token_exists(asset_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asset {asset_id} does not exist"
            )
        
        # Get total rent collected
        total_rent_wei = reader.get_total_rent_collected(asset_id)
        total_rent_eth = reader.wei_to_eth(total_rent_wei)
        
        # Get payment count
        payment_count = reader.get_rent_payment_count(asset_id)
        
        # Get all payments if requested
        payments = []
        if include_payments and payment_count > 0:
            all_payments = reader.get_all_rent_payments(asset_id)
            payments = [
                RentPaymentResponse(
                    payer=p['payer'],
                    amount_wei=p['amount'],
                    amount_eth=reader.wei_to_eth(p['amount']),
                    timestamp=p['timestamp']
                )
                for p in all_payments
            ]
        
        return RentStatsResponse(
            asset_id=asset_id,
            total_rent_collected_wei=total_rent_wei,
            total_rent_collected_eth=total_rent_eth,
            payment_count=payment_count,
            payments=payments
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch rental stats: {str(e)}"
        )


# ========== Marketplace Routes ==========

@router.get("/marketplace/info", response_model=MarketplaceInfoResponse)
async def get_marketplace_info():
    """Get marketplace contract information"""
    try:
        reader = get_blockchain_reader()
        
        fee_bps = reader.get_platform_fee_bps()
        fee_percentage = fee_bps / 100  # Convert basis points to percentage
        fee_recipient = reader.get_fee_recipient()
        
        return MarketplaceInfoResponse(
            platform_fee_percentage=fee_percentage,
            fee_recipient=fee_recipient
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch marketplace info: {str(e)}"
        )


# ========== Transaction & Block Routes ==========

@router.get("/transaction/{tx_hash}")
async def get_transaction(tx_hash: str):
    """Get transaction details by hash"""
    try:
        reader = get_blockchain_reader()
        
        # Get transaction
        tx = reader.get_transaction(tx_hash)
        
        # Get receipt if available
        receipt = reader.get_transaction_receipt(tx_hash)
        
        return {
            "transaction": tx,
            "receipt": receipt,
            "transaction_hash": tx_hash
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch transaction: {str(e)}"
        )


@router.get("/block/latest")
async def get_latest_block():
    """Get latest block number"""
    try:
        reader = get_blockchain_reader()
        block_number = reader.get_block_number()
        
        return {
            "block_number": block_number,
            "network": "Sepolia"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch block number: {str(e)}"
        )


# ========== Event Query Routes ==========

@router.get("/events/asset-initialized")
async def get_asset_initialized_events(
    token_id: Optional[int] = None,
    from_block: int = 0,
    to_block: str = 'latest'
):
    """
    Query AssetInitialized events
    
    Optional filters: token_id, from_block, to_block
    """
    try:
        reader = get_blockchain_reader()
        events = reader.get_asset_initialized_events(token_id, from_block, to_block)
        
        # Format events for response
        formatted_events = []
        for event in events:
            formatted_events.append({
                "token_id": event.get('args', {}).get('tokenId'),
                "initial_owner": event.get('args', {}).get('initialOwner'),
                "total_supply": event.get('args', {}).get('totalSupply'),
                "metadata_uri": event.get('args', {}).get('metadataURI'),
                "block_number": event.get('blockNumber'),
                "transaction_hash": event.get('transactionHash').hex() if event.get('transactionHash') else None,
                "log_index": event.get('logIndex')
            })
        
        return {
            "count": len(formatted_events),
            "events": formatted_events
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch events: {str(e)}"
        )


@router.get("/events/rent-paid")
async def get_rent_paid_events(
    asset_id: Optional[int] = None,
    from_block: int = 0,
    to_block: str = 'latest'
):
    """
    Query RentPaid events
    
    Optional filters: asset_id, from_block, to_block
    """
    try:
        reader = get_blockchain_reader()
        events = reader.get_rent_paid_events(asset_id, from_block, to_block)
        
        # Format events
        formatted_events = []
        for event in events:
            amount_wei = event.get('args', {}).get('amount', 0)
            formatted_events.append({
                "asset_id": event.get('args', {}).get('assetId'),
                "payer": event.get('args', {}).get('payer'),
                "amount_wei": amount_wei,
                "amount_eth": reader.wei_to_eth(amount_wei),
                "timestamp": event.get('args', {}).get('timestamp'),
                "block_number": event.get('blockNumber'),
                "transaction_hash": event.get('transactionHash').hex() if event.get('transactionHash') else None
            })
        
        return {
            "count": len(formatted_events),
            "events": formatted_events
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch events: {str(e)}"
        )


@router.get("/events/share-traded")
async def get_share_traded_events(
    token_id: Optional[int] = None,
    from_block: int = 0,
    to_block: str = 'latest'
):
    """
    Query ShareTraded events from Marketplace
    
    Optional filters: token_id, from_block, to_block
    """
    try:
        reader = get_blockchain_reader()
        events = reader.get_share_traded_events(token_id, from_block, to_block)
        
        # Format events
        formatted_events = []
        for event in events:
            eth_amount = event.get('args', {}).get('ethAmount', 0)
            formatted_events.append({
                "token_id": event.get('args', {}).get('tokenId'),
                "buyer": event.get('args', {}).get('buyer'),
                "seller": event.get('args', {}).get('seller'),
                "share_amount": event.get('args', {}).get('shareAmount'),
                "eth_amount_wei": eth_amount,
                "eth_amount": reader.wei_to_eth(eth_amount),
                "timestamp": event.get('args', {}).get('timestamp'),
                "block_number": event.get('blockNumber'),
                "transaction_hash": event.get('transactionHash').hex() if event.get('transactionHash') else None
            })
        
        return {
            "count": len(formatted_events),
            "events": formatted_events
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch events: {str(e)}"
        )

