"""
RentalHub Service
Handles interaction with RentalHub contract for rental listing and booking operations

Architecture:
- Read rental listings from blockchain (view functions)
- Prepare transaction data for user to sign (via WalletConnect)
- No database - everything on blockchain
"""

from web3 import Web3
from typing import Dict, List, Optional
import json
from pathlib import Path
import logging
from datetime import datetime

from app.core.config import settings

logger = logging.getLogger(__name__)


class RentalHubService:
    """Service for interacting with RentalHub contract"""
    
    def __init__(self):
        # Connect to Polygon RPC via Infura
        self.w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
        
        # Load contract ABI
        self.abi = self._load_abi()
        
        # Contract address (will be set after deployment)
        self.contract_address = getattr(settings, 'RENTAL_HUB_CONTRACT_ADDRESS', None)
        
        # Building1122 and SmartRentHub addresses for reference
        self.building_address = getattr(settings, 'BUILDING1122_CONTRACT_ADDRESS', None)
        self.smartrenthub_address = getattr(settings, 'SMARTRENTHUB_CONTRACT_ADDRESS', None)
        
        if self.contract_address:
            self.contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.contract_address),
                abi=self.abi
            )
            logger.info(f"RentalHub service initialized: {self.contract_address}")
        else:
            self.contract = None
            logger.warning("RENTAL_HUB_CONTRACT_ADDRESS not set")
    
    def _load_abi(self) -> List:
        """Load RentalHub ABI from abis folder"""
        try:
            # First try backend/app/abis (for Railway deployment)
            abi_path = Path(__file__).parent.parent / "abis" / "RentalHub.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Fallback to blockchain/abis (for local development)
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "abis" / "RentalHub.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            logger.warning("RentalHub ABI not found")
            return []
        except Exception as e:
            logger.error(f"Error loading RentalHub ABI: {e}")
            return []
    
    # ==================== View Functions - Rental Listings ====================
    
    def get_all_rental_listings(self) -> List[Dict]:
        """
        Get all active rental listings from RentalHub with NFT metadata
        
        Returns: List of RentalListing structs with attributes
        """
        try:
            if not self.contract:
                return []
            
            # Call getActiveRentalListings() view function
            listings_raw = self.contract.functions.getActiveRentalListings().call()
            
            if not listings_raw or not hasattr(listings_raw, '__iter__'):
                return []
            
            # Get SmartRentHub contract for metadata
            smartrenthub_abi = self._load_smartrenthub_abi()
            if not smartrenthub_abi or not self.smartrenthub_address:
                logger.warning("SmartRentHub not available for metadata")
                smartrenthub_contract = None
            else:
                smartrenthub_contract = self.w3.eth.contract(
                    address=Web3.to_checksum_address(self.smartrenthub_address),
                    abi=smartrenthub_abi
                )
            
            listings = []
            for listing in listings_raw:
                # RentalListing struct: (listingId, tokenId, owner, pricePerNight, createdAt, isActive)
                if isinstance(listing, (list, tuple)) and len(listing) >= 6:
                    price_wei = listing[3]
                    token_id = listing[1]
                    
                    listing_dict = {
                        "listing_id": listing[0],
                        "token_id": token_id,
                        "owner": listing[2],
                        "price_per_night_wei": price_wei,
                        "price_per_night": str(float(self.w3.from_wei(price_wei, 'ether'))),
                        "price_per_night_pol": float(self.w3.from_wei(price_wei, 'ether')),
                        "created_at": listing[4],
                        "is_active": listing[5]
                    }
                    
                    # Fetch NFT metadata for attributes
                    if smartrenthub_contract:
                        try:
                            # AssetInfo struct: (tokenId, metadataURI, totalShares, createdAt, exists)
                            asset_info = smartrenthub_contract.functions.getAsset(token_id).call()
                            if asset_info and len(asset_info) >= 3:
                                metadata_uri = asset_info[1]  # metadataURI is at index 1
                                listing_dict['total_shares'] = asset_info[2]  # totalShares at index 2
                                
                                # Fetch full metadata for name, image, and attributes
                                if metadata_uri:
                                    try:
                                        # Convert IPFS to HTTP if needed
                                        if metadata_uri.startswith("ipfs://"):
                                            http_url = metadata_uri.replace("ipfs://", "https://ipfs.io/ipfs/")
                                        else:
                                            http_url = metadata_uri
                                        
                                        # Synchronous call for metadata
                                        import requests
                                        response = requests.get(http_url, timeout=5)
                                        if response.status_code == 200:
                                            metadata = response.json()
                                            listing_dict['property_name'] = metadata.get('name', f'Property #{token_id}')
                                            
                                            # Convert IPFS image URL to HTTP
                                            image_url = metadata.get('image', '')
                                            if image_url and image_url.startswith('ipfs://'):
                                                image_url = image_url.replace('ipfs://', 'https://ipfs.io/ipfs/')
                                            listing_dict['image_url'] = image_url
                                            
                                            # Parse attributes - can be array or dict
                                            attributes_raw = metadata.get('attributes', [])
                                            if isinstance(attributes_raw, list):
                                                # Convert array to dict for easier access
                                                attributes_dict = {}
                                                for attr in attributes_raw:
                                                    if isinstance(attr, dict) and 'trait_type' in attr and 'value' in attr:
                                                        # Normalize key to lowercase
                                                        key = attr['trait_type'].lower().replace(' ', '_')
                                                        attributes_dict[key] = attr['value']
                                                listing_dict['attributes'] = attributes_dict
                                            else:
                                                listing_dict['attributes'] = attributes_raw
                                        else:
                                            logger.warning(f"Metadata fetch failed for token {token_id}: status {response.status_code}")
                                            listing_dict['property_name'] = f'Property #{token_id}'
                                            listing_dict['image_url'] = ''
                                            listing_dict['attributes'] = {}
                                    except Exception as meta_err:
                                        logger.warning(f"Could not fetch metadata for token {token_id}: {meta_err}")
                                        listing_dict['property_name'] = f'Property #{token_id}'
                                        listing_dict['image_url'] = ''
                                        listing_dict['attributes'] = {}
                                else:
                                    listing_dict['property_name'] = f'Property #{token_id}'
                                    listing_dict['image_url'] = ''
                                    listing_dict['attributes'] = {}
                        except Exception as asset_err:
                            logger.warning(f"Could not fetch asset info for token {token_id}: {asset_err}")
                            listing_dict['property_name'] = f'Property #{token_id}'
                            listing_dict['image_url'] = ''
                            listing_dict['attributes'] = {}
                    
                    listings.append(listing_dict)
            
            return listings
            
        except Exception as e:
            logger.error(f"Error getting rental listings: {e}")
            return []
    
    def _load_smartrenthub_abi(self) -> List:
        """Load SmartRentHub ABI"""
        try:
            # First try backend/app/abis (for Railway deployment)
            abi_path = Path(__file__).parent.parent / "abis" / "SmartRentHub.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Fallback to blockchain/abis (for local development)
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "abis" / "SmartRentHub.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            return []
        except Exception as e:
            logger.error(f"Error loading SmartRentHub ABI: {e}")
            return []
    
    def get_rental_listing(self, listing_id: int) -> Optional[Dict]:
        """Get single rental listing by ID"""
        try:
            if not self.contract:
                return None
            
            listing = self.contract.functions.getRentalListing(listing_id).call()
            
            if not listing or listing[0] == 0:  # Check if listingId is 0 (doesn't exist)
                return None
            
            price_wei = listing[3]
            return {
                "listing_id": listing[0],
                "token_id": listing[1],
                "owner": listing[2],
                "price_per_night_wei": price_wei,
                "price_per_night_pol": float(self.w3.from_wei(price_wei, 'ether')),
                "created_at": listing[4],
                "is_active": listing[5]
            }
            
        except Exception as e:
            logger.error(f"Error getting rental listing {listing_id}: {e}")
            return None
    
    def get_rental_listings_by_asset(self, token_id: int) -> List[Dict]:
        """Get all active rental listings for a specific asset"""
        try:
            if not self.contract:
                return []
            
            listings_raw = self.contract.functions.getRentalListingsByAsset(token_id).call()
            
            listings = []
            for listing in listings_raw:
                if isinstance(listing, (list, tuple)) and len(listing) >= 6:
                    price_wei = listing[3]
                    listings.append({
                        "listing_id": listing[0],
                        "token_id": listing[1],
                        "owner": listing[2],
                        "price_per_night_wei": price_wei,
                        "price_per_night_pol": float(self.w3.from_wei(price_wei, 'ether')),
                        "created_at": listing[4],
                        "is_active": listing[5]
                    })
            
            return listings
            
        except Exception as e:
            logger.error(f"Error getting rental listings for asset {token_id}: {e}")
            return []
    
    def check_dates_available(
        self, 
        listing_id: int, 
        check_in_date: int, 
        check_out_date: int
    ) -> bool:
        """
        Check if dates are available for a rental listing
        
        Args:
            listing_id: The rental listing ID
            check_in_date: Unix timestamp for check-in
            check_out_date: Unix timestamp for check-out
        
        Returns: True if available, False if booked
        """
        try:
            if not self.contract:
                return False
            
            available = self.contract.functions.areDatesAvailable(
                listing_id,
                check_in_date,
                check_out_date
            ).call()
            
            return available
            
        except Exception as e:
            logger.error(f"Error checking date availability for listing {listing_id}: {e}")
            return False
    
    def get_booked_dates(self, listing_id: int) -> List[int]:
        """
        Get all booked dates for a rental listing
        
        Returns: List of Unix timestamps (normalized to start of day)
        """
        try:
            if not self.contract:
                return []
            
            dates = self.contract.functions.getBookedDates(listing_id).call()
            return list(dates) if dates else []
            
        except Exception as e:
            logger.error(f"Error getting booked dates for listing {listing_id}: {e}")
            return []
    
    # ==================== View Functions - Rentals (Bookings) ====================
    
    def get_rental(self, rental_id: int) -> Optional[Dict]:
        """
        Get single rental booking by ID
        
        Returns: Rental struct
        """
        try:
            if not self.contract:
                return None
            
            rental = self.contract.functions.getRental(rental_id).call()
            
            if not rental or rental[0] == 0:  # Check if rentalId is 0
                return None
            
            # Rental struct: (rentalId, listingId, tokenId, renter, checkInDate, checkOutDate, totalPrice, createdAt, status)
            return {
                "rental_id": rental[0],
                "listing_id": rental[1],
                "token_id": rental[2],
                "renter": rental[3],
                "check_in_date": rental[4],
                "check_out_date": rental[5],
                "total_price_wei": rental[6],
                "total_price_pol": float(self.w3.from_wei(rental[6], 'ether')),
                "created_at": rental[7],
                "status": rental[8]  # 0=Active, 1=Completed, 2=Cancelled
            }
            
        except Exception as e:
            logger.error(f"Error getting rental {rental_id}: {e}")
            return None
    
    def get_rentals_by_renter(self, renter_address: str) -> List[Dict]:
        """Get all rentals made by a specific renter"""
        try:
            if not self.contract:
                return []
            
            # Returns array of rental IDs
            rental_ids = self.contract.functions.getRentalsByRenter(
                Web3.to_checksum_address(renter_address)
            ).call()
            
            # Fetch full rental data for each ID
            rentals = []
            for rental_id in rental_ids:
                rental = self.get_rental(rental_id)
                if rental:
                    rentals.append(rental)
            
            return rentals
            
        except Exception as e:
            logger.error(f"Error getting rentals for renter {renter_address}: {e}")
            return []
    
    def get_rentals_by_asset(self, token_id: int) -> List[Dict]:
        """Get all rentals for a specific asset"""
        try:
            if not self.contract:
                return []
            
            rental_ids = self.contract.functions.getRentalsByAsset(token_id).call()
            
            rentals = []
            for rental_id in rental_ids:
                rental = self.get_rental(rental_id)
                if rental:
                    rentals.append(rental)
            
            return rentals
            
        except Exception as e:
            logger.error(f"Error getting rentals for asset {token_id}: {e}")
            return []
    
    # ==================== Majority Shareholder Check ====================
    
    def is_majority_shareholder(self, address: str, token_id: int) -> bool:
        """
        Check if address is the TOP SHAREHOLDER (has the most shares)
        
        This does NOT require >50% ownership!
        The top shareholder is whoever has the highest balance.
        
        Example: 40-30-30 distribution -> 40% holder is the top shareholder
        
        This requires:
        1. Getting all owners from SmartRentHub
        2. Getting their balances from Building1122
        3. Finding who has the most shares
        
        Returns: True if address has the highest balance among all owners
        """
        try:
            if not self.building_address or not self.smartrenthub_address:
                logger.error("Building1122 or SmartRentHub address not set")
                return False
            
            # Load SmartRentHub ABI
            smartrenthub_abi = self._load_smartrenthub_abi()
            if not smartrenthub_abi:
                return False
            
            smartrenthub_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.smartrenthub_address),
                abi=smartrenthub_abi
            )
            
            # Get all owners for this asset
            owners = smartrenthub_contract.functions.getAssetOwners(token_id).call()
            
            if not owners:
                return False
            
            # Load Building1122 to get balances
            building_abi = self._load_building_abi()
            building_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=building_abi
            )
            
            # Find owner with highest balance
            max_balance = 0
            top_owner = None
            
            address_checksum = Web3.to_checksum_address(address)
            
            for owner in owners:
                balance = building_contract.functions.balanceOf(owner, token_id).call()
                if balance > max_balance:
                    max_balance = balance
                    top_owner = owner
            
            # Check if input address is the top owner
            return top_owner and Web3.to_checksum_address(top_owner) == address_checksum
            
        except Exception as e:
            logger.error(f"Error checking top shareholder for {address}, token {token_id}: {e}")
            return False

    
    def get_majority_shareholder(self, token_id: int) -> Optional[str]:
        """
        Get the address of the majority shareholder for an asset
        
        This is gas-intensive, so we do it off-chain:
        1. Get all owners from SmartRentHub
        2. Get their balances
        3. Find who has the most
        
        Returns: Address of majority shareholder or None
        """
        try:
            if not self.building_address or not self.smartrenthub_address:
                return None
            
            # Load SmartRentHub ABI
            smartrenthub_abi = self._load_smartrenthub_abi()
            if not smartrenthub_abi:
                return None
            
            smartrenthub_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.smartrenthub_address),
                abi=smartrenthub_abi
            )
            
            # Get all owners for this asset
            owners = smartrenthub_contract.functions.getAssetOwners(token_id).call()
            
            if not owners:
                return None
            
            # Load Building1122 to get balances
            building_abi = self._load_building_abi()
            building_contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=building_abi
            )
            
            # Find owner with highest balance
            max_balance = 0
            majority_owner = None
            
            for owner in owners:
                balance = building_contract.functions.balanceOf(owner, token_id).call()
                if balance > max_balance:
                    max_balance = balance
                    majority_owner = owner
            
            return majority_owner
            
        except Exception as e:
            logger.error(f"Error getting majority shareholder for token {token_id}: {e}")
            return None
    
    # ==================== Transaction Preparation ====================
    
    def prepare_create_rental_listing(
        self,
        token_id: int,
        price_per_night_pol: float
    ) -> Dict:
        """
        Prepare createRentalListing transaction data for user to sign
        
        Args:
            token_id: Asset token ID
            price_per_night_pol: Price per night in POL
        
        Returns: Dict with contract address and encoded function data
        """
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Convert POL to wei
            price_wei = self.w3.to_wei(price_per_night_pol, 'ether')
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.createRentalListing(
                token_id, 
                price_wei
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.015 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing createRentalListing: {e}")
            return {"success": False, "error": str(e)}
    
    def prepare_cancel_rental_listing(self, listing_id: int) -> Dict:
        """Prepare cancelRentalListing transaction data"""
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.cancelRentalListing(
                listing_id
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.005 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing cancelRentalListing: {e}")
            return {"success": False, "error": str(e)}
    
    def prepare_rent_asset(
        self,
        listing_id: int,
        check_in_date: int,
        check_out_date: int,
        price_per_night_wei: int
    ) -> Dict:
        """
        Prepare rentAsset (booking) transaction data
        
        Args:
            listing_id: The rental listing ID
            check_in_date: Check-in date (Unix timestamp)
            check_out_date: Check-out date (Unix timestamp)
            price_per_night_wei: Price per night in wei
        
        Returns: Dict with contract address, function data, and value to send
        """
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Calculate number of nights
            nights = (check_out_date - check_in_date) // 86400  # 86400 = 1 day in seconds
            if nights <= 0:
                return {"success": False, "error": "Invalid date range"}
            
            # Calculate total value to send
            total_value_wei = nights * price_per_night_wei
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.rentAsset(
                listing_id, 
                check_in_date, 
                check_out_date
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "value_wei": str(total_value_wei),
                "value_pol": float(self.w3.from_wei(total_value_wei, 'ether')),
                "nights": nights,
                "gas_estimate": "0.025 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing rentAsset: {e}")
            return {"success": False, "error": str(e)}
    
    def prepare_cancel_rental(self, rental_id: int) -> Dict:
        """Prepare cancelRental transaction data"""
        try:
            if not self.contract:
                return {"success": False, "error": "Contract not initialized"}
            
            # Encode function data using Web3.py's correct method
            function_data = self.contract.functions.cancelRental(
                rental_id
            )._encode_transaction_data()
            
            return {
                "success": True,
                "contract_address": self.contract_address,
                "function_data": function_data.hex() if isinstance(function_data, bytes) else function_data,
                "gas_estimate": "0.01 POL"
            }
            
        except Exception as e:
            logger.error(f"Error preparing cancelRental: {e}")
            return {"success": False, "error": str(e)}
    
    # ==================== Helper Methods ====================
    
    def _load_building_abi(self) -> List:
        """Load Building1122 ABI"""
        try:
            # First try backend/app/abis (for Railway deployment)
            abi_path = Path(__file__).parent.parent / "abis" / "Building1122.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            # Fallback to blockchain/abis (for local development)
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "abis" / "Building1122.json"
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            return []
        except Exception as e:
            logger.error(f"Error loading Building1122 ABI: {e}")
            return []
    
    def _load_smartrenthub_abi(self) -> List:
        """Load SmartRentHub ABI"""
        try:
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "abis" / "SmartRentHub.json"
            
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    if isinstance(contract_data, list):
                        return contract_data
                    return contract_data.get('abi', [])
            
            return []
        except Exception as e:
            logger.error(f"Error loading SmartRentHub ABI: {e}")
            return []
    
    def get_transaction_status(self, tx_hash: str) -> Dict:
        """
        Check if a transaction has been mined and was successful
        
        Returns: Dict with status information
        """
        try:
            receipt = self.w3.eth.get_transaction_receipt(tx_hash)
            
            if receipt is None:
                return {
                    "mined": False,
                    "pending": True
                }
            
            return {
                "mined": True,
                "success": receipt['status'] == 1,
                "block_number": receipt['blockNumber'],
                "gas_used": receipt['gasUsed'],
                "transaction_hash": receipt['transactionHash'].hex()
            }
            
        except Exception as e:
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


# Singleton instance
rental_hub_service = RentalHubService()

