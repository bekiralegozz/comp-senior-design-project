"""
SmartRentHub Service
Handles interaction with SmartRentHub contract for registry and marketplace operations
"""

from web3 import Web3
from typing import Dict, List, Optional
import json
from pathlib import Path
import logging
import httpx
import time
from functools import lru_cache

from app.core.config import settings

logger = logging.getLogger(__name__)

# Simple in-memory cache for metadata with TTL
_metadata_cache: Dict[str, tuple] = {}  # {uri: (data, timestamp)}
METADATA_CACHE_TTL = 300  # 5 minutes


def get_cached_metadata(uri: str) -> Optional[Dict]:
    """Get cached metadata if not expired"""
    if uri in _metadata_cache:
        data, timestamp = _metadata_cache[uri]
        if time.time() - timestamp < METADATA_CACHE_TTL:
            return data
        else:
            del _metadata_cache[uri]
    return None


def set_cached_metadata(uri: str, data: Dict):
    """Cache metadata with timestamp"""
    _metadata_cache[uri] = (data, time.time())


class SmartRentHubService:
    """Service for interacting with SmartRentHub contract"""
    
    def __init__(self):
        # Connect to Polygon RPC via Infura
        self.w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
        
        # Load contract ABI
        self.abi = self._load_abi()
        
        # Contract address
        self.contract_address = getattr(settings, 'SMARTRENTHUB_CONTRACT_ADDRESS', None)
        
        # Building1122 address for reference
        self.building_address = getattr(settings, 'BUILDING1122_CONTRACT_ADDRESS', None)
        
        if self.contract_address:
            self.contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.contract_address),
                abi=self.abi
            )
            logger.info(f"SmartRentHub service initialized: {self.contract_address}")
        else:
            self.contract = None
            logger.warning("SMARTRENTHUB_CONTRACT_ADDRESS not set")
    
    def _load_abi(self) -> List:
        """Load SmartRentHub ABI from abis folder"""
        try:
            # First try backend/app/abis (for Railway deployment)
            abi_path = Path(__file__).parent.parent / "abis" / "SmartRentHub.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Then try blockchain/abis (for local development)
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "abis" / "SmartRentHub.json"
            
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Fallback to artifacts
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "artifacts" / "contracts" / "SmartRentHub.sol" / "SmartRentHub.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    return contract_data.get('abi', [])
            
            logger.warning("SmartRentHub ABI not found")
            return []
        except Exception as e:
            logger.error(f"Error loading SmartRentHub ABI: {e}")
            return []
    
    # ==================== Registry Functions ====================
    
    def get_all_assets(self) -> List[Dict]:
        """
        Get all registered assets from SmartRentHub
        Returns: List of AssetInfo structs
        """
        try:
            if not self.contract:
                return []
            
            # Call getAllAssets() view function
            assets_raw = self.contract.functions.getAllAssets().call()
            
            # If empty or not iterable, return empty list
            if not assets_raw or not hasattr(assets_raw, '__iter__'):
                return []
            
            assets = []
            for asset in assets_raw:
                # AssetInfo struct: (tokenId, metadataURI, totalShares, createdAt, exists)
                # asset is a tuple: (uint256, string, uint256, uint256, bool)
                if isinstance(asset, (list, tuple)) and len(asset) >= 5:
                    assets.append({
                        "token_id": asset[0],
                        "metadata_uri": asset[1],
                        "total_shares": asset[2],
                        "created_at": asset[3],
                        "exists": asset[4]
                    })
            
            return assets
            
        except Exception as e:
            logger.error(f"Error getting all assets: {e}")
            return []
    
    def get_asset(self, token_id: int) -> Optional[Dict]:
        """Get single asset info"""
        try:
            if not self.contract:
                return None
            
            asset = self.contract.functions.getAsset(token_id).call()
            
            return {
                "token_id": asset[0],
                "metadata_uri": asset[1],
                "total_shares": asset[2],
                "created_at": asset[3],
                "exists": asset[4] if len(asset) > 4 else False
            }
            
        except Exception as e:
            logger.error(f"Error getting asset {token_id}: {e}")
            return None
    
    def get_assets_by_owner(self, owner_address: str) -> List[Dict]:
        """
        Get assets owned by address with their balances
        Returns: List of AssetWithBalance structs
        """
        try:
            if not self.contract:
                return []
            
            # Call getAssetsWithBalances(address) - returns AssetWithBalance[]
            # NOT getAssetsByOwner which only returns uint256[] (tokenIds)
            assets_raw = self.contract.functions.getAssetsWithBalances(
                Web3.to_checksum_address(owner_address)
            ).call()
            
            # If empty or not iterable, return empty list
            if not assets_raw or not hasattr(assets_raw, '__iter__'):
                return []
            
            assets = []
            for asset in assets_raw:
                # AssetWithBalance struct: (tokenId, metadataURI, totalShares, balance, createdAt)
                # Note: order is tokenId, metadataURI, totalShares, balance, createdAt
                if isinstance(asset, (list, tuple)) and len(asset) >= 5:
                    token_id = asset[0]
                    total_shares = asset[2]
                    balance = asset[3]
                    
                    assets.append({
                        "token_id": token_id,
                        "metadata_uri": asset[1],
                        "total_shares": total_shares,
                        "balance": balance,
                        "created_at": asset[4],
                        "ownership_percentage": (balance / total_shares * 100) if total_shares > 0 else 0
                    })
            
            return assets
            
        except Exception as e:
            logger.error(f"Error getting assets for owner {owner_address}: {e}")
            return []
    
    # ==================== Marketplace Functions ====================
    
    def get_active_listings(self) -> List[Dict]:
        """
        Get all active marketplace listings
        Returns: List of Listing structs
        """
        try:
            if not self.contract:
                return []
            
            # Call getActiveListings() view function
            listings_raw = self.contract.functions.getActiveListings().call()
            
            listings = []
            for listing in listings_raw:
                # Listing struct from contract (GAS OPTIMIZED - struct packing):
                # [0] uint64 listingId
                # [1] uint64 tokenId
                # [2] uint64 sharesForSale
                # [3] uint64 sharesRemaining
                # [4] address seller
                # [5] bool isActive
                # [6] uint128 pricePerShare
                # [7] uint64 createdAt
                listings.append({
                    "listing_id": int(listing[0]),
                    "token_id": int(listing[1]),
                    "shares_for_sale": int(listing[2]),
                    "shares_remaining": int(listing[3]),
                    "seller": listing[4],
                    "is_active": bool(listing[5]),
                    "price_per_share": int(listing[6]),
                    "created_at": int(listing[7]),
                    # Price in POL (wei to ether)
                    "price_per_share_pol": float(self.w3.from_wei(int(listing[6]), 'ether'))
                })
            
            return listings
            
        except Exception as e:
            logger.error(f"Error getting active listings: {e}")
            return []
    
    def get_listing(self, listing_id: int) -> Optional[Dict]:
        """Get single listing info"""
        try:
            if not self.contract:
                return None
            
            listing = self.contract.functions.getListing(listing_id).call()
            
            # Listing struct from contract (GAS OPTIMIZED - struct packing):
            # [0] uint64 listingId, [1] uint64 tokenId
            # [2] uint64 sharesForSale, [3] uint64 sharesRemaining
            # [4] address seller, [5] bool isActive
            # [6] uint128 pricePerShare, [7] uint64 createdAt
            return {
                "listing_id": int(listing[0]),
                "token_id": int(listing[1]),
                "shares_for_sale": int(listing[2]),
                "shares_remaining": int(listing[3]),
                "seller": listing[4],
                "is_active": bool(listing[5]),
                "price_per_share": int(listing[6]),
                "created_at": int(listing[7]),
                "price_per_share_pol": float(self.w3.from_wei(int(listing[6]), 'ether'))
            }
            
        except Exception as e:
            logger.error(f"Error getting listing {listing_id}: {e}")
            return None
    
    def get_listings_by_seller(self, seller_address: str) -> List[Dict]:
        """Get all active listings by a seller"""
        try:
            if not self.contract:
                return []
            
            listings_raw = self.contract.functions.getListingsBySeller(
                Web3.to_checksum_address(seller_address)
            ).call()
            
            listings = []
            for listing in listings_raw:
                # Listing struct from contract (GAS OPTIMIZED - struct packing)
                listings.append({
                    "listing_id": int(listing[0]),
                    "token_id": int(listing[1]),
                    "shares_for_sale": int(listing[2]),
                    "shares_remaining": int(listing[3]),
                    "seller": listing[4],
                    "is_active": bool(listing[5]),
                    "price_per_share": int(listing[6]),
                    "created_at": int(listing[7]),
                    "price_per_share_pol": float(self.w3.from_wei(int(listing[6]), 'ether'))
                })
            
            return listings
            
        except Exception as e:
            logger.error(f"Error getting listings for seller {seller_address}: {e}")
            return []
    
    # ==================== Transaction Preparation ====================
    
    def prepare_create_listing(
        self,
        token_id: int,
        shares_for_sale: int,
        price_per_share_pol: float
    ) -> Dict:
        """
        Prepare createListing transaction data for user to sign
        
        Returns: Dict with contract address and encoded function data
        """
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Convert POL to wei
            price_wei = self.w3.to_wei(price_per_share_pol, 'ether')
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.createListing(
                token_id, 
                shares_for_sale, 
                price_wei
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.01 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing createListing: {e}")
            return {"success": False, "error": str(e)}
    
    def prepare_cancel_listing(self, listing_id: int) -> Dict:
        """Prepare cancelListing transaction data"""
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.cancelListing(
                listing_id
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.005 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing cancelListing: {e}")
            return {"success": False, "error": str(e)}
    
    def prepare_buy_listing(
        self,
        listing_id: int,
        shares_to_buy: int,
        price_per_share_wei: int
    ) -> Dict:
        """
        Prepare buyFromListing transaction data
        
        Returns: Dict with contract address, function data, and value to send
        """
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Calculate total value to send
            total_value_wei = shares_to_buy * price_per_share_wei
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.buyFromListing(
                listing_id, 
                shares_to_buy
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "value_wei": str(total_value_wei),
                "value_pol": float(self.w3.from_wei(total_value_wei, 'ether')),
                "gas_estimate": "0.02 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing buyFromListing: {e}")
            return {"success": False, "error": str(e)}
    
    # ==================== Metadata Fetching ====================
    
    async def fetch_metadata(self, metadata_uri: str) -> Optional[Dict]:
        """Fetch metadata from IPFS with caching"""
        try:
            if not metadata_uri:
                return None
            
            # Check cache first
            cached = get_cached_metadata(metadata_uri)
            if cached:
                logger.debug(f"Cache hit for metadata: {metadata_uri}")
                return cached
            
            # Convert IPFS URI to HTTP gateway URL - use faster gateways
            if metadata_uri.startswith("ipfs://"):
                ipfs_hash = metadata_uri.replace("ipfs://", "")
                # Try Pinata first (faster), then fallback to ipfs.io
                gateways = [
                    f"https://gateway.pinata.cloud/ipfs/{ipfs_hash}",
                    f"https://cloudflare-ipfs.com/ipfs/{ipfs_hash}",
                    f"https://ipfs.io/ipfs/{ipfs_hash}"
                ]
            else:
                gateways = [metadata_uri]
            
            async with httpx.AsyncClient(timeout=15.0) as client:
                for gateway_url in gateways:
                    try:
                        response = await client.get(gateway_url)
                        if response.status_code == 200:
                            data = response.json()
                            # Cache the result
                            set_cached_metadata(metadata_uri, data)
                            return data
                    except Exception as e:
                        logger.warning(f"Gateway {gateway_url} failed: {e}")
                        continue
            
            return None
            
        except Exception as e:
            logger.error(f"Error fetching metadata from {metadata_uri}: {e}")
            return None
    
    # ==================== Approval Functions ====================
    
    def check_approval(self, owner_address: str) -> bool:
        """
        Check if owner has approved SmartRentHub to transfer their tokens
        
        Returns: True if approved, False otherwise
        """
        try:
            if not self.building_address:
                logger.error("Building1122 address not set")
                return False
            
            # Load Building1122 ABI
            building_abi = self._load_building_abi()
            if not building_abi:
                return False
            
            # Create Building1122 contract instance
            building_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=building_abi
            )
            
            # Check isApprovedForAll(owner, operator)
            is_approved = building_contract.functions.isApprovedForAll(
                Web3.to_checksum_address(owner_address),
                Web3.to_checksum_address(self.contract_address)
            ).call()
            
            return is_approved
            
        except Exception as e:
            logger.error(f"Error checking approval for {owner_address}: {e}")
            return False
    
    def prepare_approval(self, approved: bool = True) -> Dict:
        """
        Prepare setApprovalForAll transaction data
        
        Args:
            approved: True to approve, False to revoke
        
        Returns: Dict with contract address and encoded function data
        """
        try:
            if not self.building_address:
                return {"success": False, "error": "Building1122 address not set"}
            
            # Load Building1122 ABI
            building_abi = self._load_building_abi()
            if not building_abi:
                return {"success": False, "error": "Building1122 ABI not found"}
            
            # Create Building1122 contract instance
            building_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=building_abi
            )
            
            # Encode setApprovalForAll(operator, approved) using Web3.py's correct method
            function_data = building_contract.functions.setApprovalForAll(
                Web3.to_checksum_address(self.contract_address), 
                approved
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.building_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.005 POL",
                "approved": approved
            }
            
        except Exception as e:
            logger.error(f"Error preparing approval: {e}")
            return {"success": False, "error": str(e)}
    
    def _load_building_abi(self) -> List:
        """Load Building1122 ABI from abis folder"""
        try:
            # First try backend/app/abis (for Railway deployment)
            abi_path = Path(__file__).parent.parent / "abis" / "Building1122.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Then try blockchain/abis (for local development)
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "abis" / "Building1122.json"
            
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Fallback to artifacts
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "artifacts" / "contracts" / "Building1122.sol" / "Building1122.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    return contract_data.get('abi', [])
            
            logger.warning("Building1122 ABI not found")
            return []
        except Exception as e:
            logger.error(f"Error loading Building1122 ABI: {e}")
            return []
    
    def get_transaction_status(self, tx_hash: str) -> Dict:
        """
        Check if a transaction has been mined and was successful
        
        Returns: Dict with status information
        """
        try:
            # Get transaction receipt (returns None if not mined yet)
            receipt = self.w3.eth.get_transaction_receipt(tx_hash)
            
            if receipt is None:
                return {
                    "mined": False,
                    "pending": True
                }
            
            # Transaction mined, check success (status == 1)
            return {
                "mined": True,
                "success": receipt['status'] == 1,
                "block_number": receipt['blockNumber'],
                "gas_used": receipt['gasUsed'],
                "transaction_hash": receipt['transactionHash'].hex()
            }
            
        except Exception as e:
            # If transaction not found, it's still pending
            if "not found" in str(e).lower():
                return {
                    "mined": False,
                    "pending": True
                }
            logger.error(f"Error getting transaction status for {tx_hash}: {e}")
            return {
                "mined": False,
                "error": str(e)
            }
    
    def is_asset_registered(self, token_id: int) -> bool:
        """
        Check if a token is registered in SmartRentHub
        
        Returns: True if registered, False otherwise
        """
        try:
            if not self.contract:
                return False
            
            # Call getAsset(tokenId) - returns AssetInfo struct
            asset_info = self.contract.functions.getAsset(token_id).call()
            
            # AssetInfo struct: (tokenId, metadataURI, totalShares, createdAt, exists)
            # Check exists field (index 4)
            return asset_info[4] if isinstance(asset_info, (list, tuple)) and len(asset_info) > 4 else False
            
        except Exception as e:
            logger.error(f"Error checking if asset {token_id} is registered: {e}")
            return False
    
    def prepare_register_asset(self, token_id: int, owner: str) -> Dict:
        """
        Prepare registerAsset transaction for a token that exists in Building1122
        but not in SmartRentHub
        
        This requires calling Building1122 to get token details first
        """
        try:
            if not self.building_address:
                return {"success": False, "error": "Building1122 address not set"}
            
            # Load Building1122 ABI and contract
            building_abi = self._load_building_abi()
            if not building_abi:
                return {"success": False, "error": "Building1122 ABI not found"}
            
            building_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=building_abi
            )
            
            # Get token details from Building1122
            total_supply = building_contract.functions.totalSupply(token_id).call()
            metadata_uri = building_contract.functions.assetMetadataURI(token_id).call()
            
            if total_supply == 0:
                return {"success": False, "error": f"Token {token_id} does not exist in Building1122"}
            
            # Encode registerAsset(tokenId, initialOwner, totalShares, metadataURI) using Web3.py's correct method
            function_data = self.contract.functions.registerAsset(
                token_id, 
                Web3.to_checksum_address(owner), 
                total_supply, 
                metadata_uri
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.01 POL",
                "token_id": token_id,
                "total_supply": total_supply
            }
            
        except Exception as e:
            logger.error(f"Error preparing register asset for token {token_id}: {e}")
            return {"success": False, "error": str(e)}


# Singleton instance
smartrenthub_service = SmartRentHubService()

