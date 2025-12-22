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

from app.core.config import settings

logger = logging.getLogger(__name__)


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
                "owners": list(asset[4]) if len(asset) > 4 else []
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
                # ListingWithAsset struct from contract
                listings.append({
                    "listing_id": listing[0],
                    "token_id": listing[1],
                    "seller": listing[2],
                    "shares_for_sale": listing[3],
                    "shares_remaining": listing[4],
                    "price_per_share": listing[5],
                    "is_active": listing[6],
                    "created_at": listing[7],
                    # Price in POL (wei to ether)
                    "price_per_share_pol": float(self.w3.from_wei(listing[5], 'ether'))
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
            
            return {
                "listing_id": listing[0],
                "token_id": listing[1],
                "seller": listing[2],
                "shares_for_sale": listing[3],
                "shares_remaining": listing[4],
                "price_per_share": listing[5],
                "is_active": listing[6],
                "created_at": listing[7],
                "price_per_share_pol": float(self.w3.from_wei(listing[5], 'ether'))
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
                listings.append({
                    "listing_id": listing[0],
                    "token_id": listing[1],
                    "seller": listing[2],
                    "shares_for_sale": listing[3],
                    "shares_remaining": listing[4],
                    "price_per_share": listing[5],
                    "is_active": listing[6],
                    "created_at": listing[7],
                    "price_per_share_pol": float(self.w3.from_wei(listing[5], 'ether'))
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
            
            # Encode function data
            function_data = self.contract.encodeABI(
                fn_name="createListing",
                args=[token_id, shares_for_sale, price_wei]
            )
            
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
            
            function_data = self.contract.encodeABI(
                fn_name="cancelListing",
                args=[listing_id]
            )
            
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
            
            function_data = self.contract.encodeABI(
                fn_name="buyFromListing",
                args=[listing_id, shares_to_buy]
            )
            
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
        """Fetch metadata from IPFS"""
        try:
            # Convert IPFS URI to HTTP gateway URL
            if metadata_uri.startswith("ipfs://"):
                http_url = metadata_uri.replace("ipfs://", "https://ipfs.io/ipfs/")
            else:
                http_url = metadata_uri
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(http_url)
                if response.status_code == 200:
                    return response.json()
            
            return None
            
        except Exception as e:
            logger.error(f"Error fetching metadata from {metadata_uri}: {e}")
            return None


# Singleton instance
smartrenthub_service = SmartRentHubService()

