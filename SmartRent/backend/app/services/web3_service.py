"""
Web3 Service for Blockchain Interaction
Handles NFT minting, fractional ownership, and contract interactions
"""

from web3 import Web3
from eth_account import Account
from typing import Dict, Optional, List
import json
from pathlib import Path
import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


class Web3Service:
    """Service for interacting with Polygon blockchain and smart contracts"""
    
    def __init__(self):
        # Connect to Polygon RPC
        self.w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
        self.chain_id = 137  # Polygon Mainnet
        
        # Load deployer account
        self.account = None
        if hasattr(settings, 'WALLET_PRIVATE_KEY') and settings.WALLET_PRIVATE_KEY:
            # Check if it's a valid hex private key
            if len(settings.WALLET_PRIVATE_KEY) == 64 or (
                settings.WALLET_PRIVATE_KEY.startswith('0x') and len(settings.WALLET_PRIVATE_KEY) == 66
            ):
                try:
                    self.account = Account.from_key(settings.WALLET_PRIVATE_KEY)
                    logger.info(f"Web3 Service initialized with account: {self.account.address}")
                except Exception as e:
                    logger.warning(f"Invalid private key: {str(e)} - operating in read-only mode")
            else:
                logger.warning("WALLET_PRIVATE_KEY format invalid - operating in read-only mode")
        else:
            logger.warning("WALLET_PRIVATE_KEY not set - read-only mode")
        
        # Load contract ABIs
        self.building_abi = self._load_contract_abi("Building1122")
        self.marketplace_abi = self._load_contract_abi("Marketplace")
        self.rental_manager_abi = self._load_contract_abi("RentalManager")
        
        # Contract addresses (from deployment)
        self.building_address = getattr(settings, 'BUILDING1122_CONTRACT_ADDRESS', None)
        self.marketplace_address = getattr(settings, 'MARKETPLACE_CONTRACT_ADDRESS', None)
        self.rental_manager_address = getattr(settings, 'RENTAL_MANAGER_CONTRACT_ADDRESS', None)
    
    def _load_contract_abi(self, contract_name: str) -> List:
        """Load contract ABI from artifacts"""
        try:
            abi_path = Path(__file__).parent.parent.parent.parent / "blockchain" / "artifacts" / "contracts" / f"{contract_name}.sol" / f"{contract_name}.json"
            
            if abi_path.exists():
                with open(abi_path, 'r') as f:
                    contract_data = json.load(f)
                    return contract_data.get('abi', [])
            else:
                logger.warning(f"ABI file not found for {contract_name} at {abi_path}")
                return []
        except Exception as e:
            logger.error(f"Error loading ABI for {contract_name}: {str(e)}")
            return []
    
    def is_connected(self) -> bool:
        """Check if connected to blockchain"""
        try:
            return self.w3.is_connected()
        except Exception as e:
            logger.error(f"Connection check failed: {str(e)}")
            return False
    
    def get_balance(self, address: str) -> float:
        """Get MATIC balance of address"""
        try:
            balance_wei = self.w3.eth.get_balance(Web3.to_checksum_address(address))
            return float(self.w3.from_wei(balance_wei, 'ether'))
        except Exception as e:
            logger.error(f"Error getting balance: {str(e)}")
            return 0.0
    
    def get_gas_price(self) -> int:
        """Get current gas price"""
        try:
            return self.w3.eth.gas_price
        except Exception as e:
            logger.error(f"Error getting gas price: {str(e)}")
            return 35000000000  # 35 gwei default
    
    # ==================== Building1122 Contract Methods ====================
    
    def mint_asset_nft(
        self, 
        token_id: int,
        owner_address: str, 
        total_shares: int,
        metadata_uri: str
    ) -> Dict:
        """
        Mint a new fractional NFT asset
        
        Args:
            token_id: Unique identifier for the asset
            owner_address: Address that will receive the initial shares
            total_shares: Total number of fractional shares (e.g., 1000)
            metadata_uri: IPFS URI for NFT metadata
        
        Returns:
            Dict with transaction details or error
        """
        try:
            if not self.account:
                return {"success": False, "error": "No wallet configured"}
            
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=self.building_abi
            )
            
            # Build transaction
            nonce = self.w3.eth.get_transaction_count(self.account.address)
            
            transaction = contract.functions.mintInitialSupply(
                token_id,
                Web3.to_checksum_address(owner_address),
                total_shares,
                metadata_uri
            ).build_transaction({
                'from': self.account.address,
                'nonce': nonce,
                'gas': 500000,
                'gasPrice': self.get_gas_price(),
                'chainId': self.chain_id
            })
            
            # Sign and send
            signed_txn = self.w3.eth.account.sign_transaction(
                transaction, 
                private_key=self.account.key
            )
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            
            # Wait for receipt
            logger.info(f"NFT mint transaction sent: {tx_hash.hex()}")
            tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            
            return {
                "success": True,
                "token_id": token_id,
                "transaction_hash": tx_hash.hex(),
                "block_number": tx_receipt['blockNumber'],
                "gas_used": tx_receipt['gasUsed']
            }
            
        except Exception as e:
            logger.error(f"Error minting NFT: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_asset_info(self, token_id: int) -> Optional[Dict]:
        """Get NFT asset information from blockchain"""
        try:
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=self.building_abi
            )
            
            # Check if exists
            exists = contract.functions.exists(token_id).call()
            if not exists:
                return None
            
            # Get total supply
            total_supply = contract.functions.totalSupply(token_id).call()
            
            # Get metadata URI
            metadata_uri = contract.functions.uri(token_id).call()
            
            return {
                "token_id": token_id,
                "total_supply": total_supply,
                "metadata_uri": metadata_uri,
                "exists": True
            }
            
        except Exception as e:
            logger.error(f"Error getting asset info: {str(e)}")
            return None
    
    def get_ownership_percentage(self, token_id: int, address: str) -> float:
        """Get ownership percentage for an address"""
        try:
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=self.building_abi
            )
            
            percentage_bps = contract.functions.getOwnershipPercentage(
                Web3.to_checksum_address(address),
                token_id
            ).call()
            
            # Convert from basis points to percentage
            return percentage_bps / 100.0
            
        except Exception as e:
            logger.error(f"Error getting ownership percentage: {str(e)}")
            return 0.0
    
    def get_share_balance(self, token_id: int, address: str) -> int:
        """Get number of shares owned by address"""
        try:
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.building_address),
                abi=self.building_abi
            )
            
            balance = contract.functions.balanceOf(
                Web3.to_checksum_address(address),
                token_id
            ).call()
            
            return balance
            
        except Exception as e:
            logger.error(f"Error getting share balance: {str(e)}")
            return 0
    
    # ==================== Marketplace Contract Methods ====================
    
    def buy_shares(
        self,
        token_id: int,
        seller_address: str,
        share_amount: int,
        price_in_matic: float
    ) -> Dict:
        """Purchase fractional shares from marketplace"""
        try:
            if not self.account:
                return {"success": False, "error": "No wallet configured"}
            
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.marketplace_address),
                abi=self.marketplace_abi
            )
            
            price_wei = self.w3.to_wei(price_in_matic, 'ether')
            nonce = self.w3.eth.get_transaction_count(self.account.address)
            
            transaction = contract.functions.buyShare(
                token_id,
                Web3.to_checksum_address(seller_address),
                share_amount
            ).build_transaction({
                'from': self.account.address,
                'value': price_wei,
                'nonce': nonce,
                'gas': 300000,
                'gasPrice': self.get_gas_price(),
                'chainId': self.chain_id
            })
            
            signed_txn = self.w3.eth.account.sign_transaction(transaction, self.account.key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            
            logger.info(f"Share purchase transaction sent: {tx_hash.hex()}")
            tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            
            return {
                "success": True,
                "transaction_hash": tx_hash.hex(),
                "block_number": tx_receipt['blockNumber'],
                "gas_used": tx_receipt['gasUsed']
            }
            
        except Exception as e:
            logger.error(f"Error buying shares: {str(e)}")
            return {"success": False, "error": str(e)}
    
    # ==================== Rental Manager Contract Methods ====================
    
    def distribute_rent(
        self,
        token_id: int,
        owner_addresses: List[str],
        total_rent_matic: float
    ) -> Dict:
        """Distribute rent payment to fractional owners"""
        try:
            if not self.account:
                return {"success": False, "error": "No wallet configured"}
            
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.rental_manager_address),
                abi=self.rental_manager_abi
            )
            
            rent_wei = self.w3.to_wei(total_rent_matic, 'ether')
            nonce = self.w3.eth.get_transaction_count(self.account.address)
            
            # Convert addresses to checksum format
            owners = [Web3.to_checksum_address(addr) for addr in owner_addresses]
            
            transaction = contract.functions.payRent(
                token_id,
                owners
            ).build_transaction({
                'from': self.account.address,
                'value': rent_wei,
                'nonce': nonce,
                'gas': 400000,
                'gasPrice': self.get_gas_price(),
                'chainId': self.chain_id
            })
            
            signed_txn = self.w3.eth.account.sign_transaction(transaction, self.account.key)
            tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
            
            logger.info(f"Rent distribution transaction sent: {tx_hash.hex()}")
            tx_receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            
            return {
                "success": True,
                "transaction_hash": tx_hash.hex(),
                "block_number": tx_receipt['blockNumber'],
                "gas_used": tx_receipt['gasUsed']
            }
            
        except Exception as e:
            logger.error(f"Error distributing rent: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def get_total_rent_collected(self, token_id: int) -> float:
        """Get total rent collected for an asset"""
        try:
            contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.rental_manager_address),
                abi=self.rental_manager_abi
            )
            
            total_wei = contract.functions.totalRentCollected(token_id).call()
            return float(self.w3.from_wei(total_wei, 'ether'))
            
        except Exception as e:
            logger.error(f"Error getting rent collected: {str(e)}")
            return 0.0
    
    # ==================== Utility Methods ====================
    
    def get_transaction_receipt(self, tx_hash: str) -> Optional[Dict]:
        """Get transaction receipt"""
        try:
            receipt = self.w3.eth.get_transaction_receipt(tx_hash)
            return {
                "transaction_hash": receipt['transactionHash'].hex(),
                "block_number": receipt['blockNumber'],
                "gas_used": receipt['gasUsed'],
                "status": receipt['status'],
                "from": receipt['from'],
                "to": receipt['to']
            }
        except Exception as e:
            logger.error(f"Error getting transaction receipt: {str(e)}")
            return None
    
    def estimate_gas(self, token_id: int, operation: str = "mint") -> int:
        """Estimate gas for operations"""
        estimates = {
            "mint": 500000,
            "transfer": 100000,
            "buy": 300000,
            "rent": 400000
        }
        return estimates.get(operation, 200000)


# Singleton instance
web3_service = Web3Service()
