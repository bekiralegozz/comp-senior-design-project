"""
Blockchain Reader Service
Read-only service to query blockchain data (contracts, events, balances)
"""
from typing import Optional, List, Dict, Any
from web3 import Web3
from web3.contract import Contract
from eth_typing import Address
import json
import os


class BlockchainReader:
    """
    Read-only blockchain service
    Queries Sepolia testnet for SmartRent contract data
    """
    
    def __init__(self, rpc_url: str = None):
        """Initialize blockchain reader with RPC connection"""
        # Default to Alchemy Sepolia RPC
        self.rpc_url = rpc_url or os.getenv(
            'SEPOLIA_RPC_URL',
            'https://eth-sepolia.g.alchemy.com/v2/e7KBw7Uhu7r1meEBJRPyZ'
        )
        
        # Initialize Web3
        self.w3 = Web3(Web3.HTTPProvider(self.rpc_url))
        
        if not self.w3.is_connected():
            raise ConnectionError(f"Failed to connect to Sepolia RPC: {self.rpc_url}")
        
        # Contract addresses
        self.building1122_address = os.getenv(
            'BUILDING1122_ADDRESS',
            '0xeFbfFC198FfA373C26E64a426E8866B132d08ACB'
        )
        self.rental_manager_address = os.getenv(
            'RENTAL_MANAGER_ADDRESS',
            '0x57044386A0C5Fb623315Dd5b8eeEA6078Bb9193C'
        )
        self.marketplace_address = os.getenv(
            'MARKETPLACE_ADDRESS',
            '0x2fFCd104D50c99D24d76Acfc3Ef1dfb550127A1f'
        )
        
        # Load ABIs and create contract instances
        self._load_contracts()
    
    def _load_contracts(self):
        """Load contract ABIs and create contract instances"""
        # Get ABI directory path
        abi_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            '..',
            'blockchain',
            'abis'
        )
        
        # Load Building1122 contract
        with open(os.path.join(abi_dir, 'Building1122.json'), 'r') as f:
            building1122_abi = json.load(f)
        self.building1122 = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.building1122_address),
            abi=building1122_abi
        )
        
        # Load RentalManager contract
        with open(os.path.join(abi_dir, 'RentalManager.json'), 'r') as f:
            rental_manager_abi = json.load(f)
        self.rental_manager = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.rental_manager_address),
            abi=rental_manager_abi
        )
        
        # Load Marketplace contract
        with open(os.path.join(abi_dir, 'Marketplace.json'), 'r') as f:
            marketplace_abi = json.load(f)
        self.marketplace = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.marketplace_address),
            abi=marketplace_abi
        )
    
    # ========== Building1122 Contract Methods ==========
    
    def get_token_balance(self, owner_address: str, token_id: int) -> int:
        """
        Get token balance for an owner
        
        Args:
            owner_address: Wallet address of the owner
            token_id: Asset token ID
            
        Returns:
            Balance as integer (number of shares)
        """
        balance = self.building1122.functions.balanceOf(
            Web3.to_checksum_address(owner_address),
            token_id
        ).call()
        return balance
    
    def get_total_supply(self, token_id: int) -> int:
        """
        Get total supply for a token
        
        Args:
            token_id: Asset token ID
            
        Returns:
            Total supply as integer
        """
        return self.building1122.functions.totalSupply(token_id).call()
    
    def get_ownership_percentage(self, owner_address: str, token_id: int) -> int:
        """
        Get ownership percentage (basis points: 10000 = 100%)
        
        Args:
            owner_address: Wallet address of the owner
            token_id: Asset token ID
            
        Returns:
            Percentage in basis points (e.g., 2500 = 25%)
        """
        percentage_bps = self.building1122.functions.getOwnershipPercentage(
            Web3.to_checksum_address(owner_address),
            token_id
        ).call()
        return percentage_bps
    
    def token_exists(self, token_id: int) -> bool:
        """
        Check if a token has been initialized
        
        Args:
            token_id: Asset token ID
            
        Returns:
            True if token exists, False otherwise
        """
        return self.building1122.functions.exists(token_id).call()
    
    def get_asset_metadata_uri(self, token_id: int) -> str:
        """
        Get metadata URI for an asset
        
        Args:
            token_id: Asset token ID
            
        Returns:
            Metadata URI string
        """
        return self.building1122.functions.assetMetadataURI(token_id).call()
    
    # ========== RentalManager Contract Methods ==========
    
    def get_total_rent_collected(self, asset_id: int) -> int:
        """
        Get total rent collected for an asset (in wei)
        
        Args:
            asset_id: Asset token ID
            
        Returns:
            Total rent in wei
        """
        return self.rental_manager.functions.getTotalRentCollected(asset_id).call()
    
    def get_rent_payment_count(self, asset_id: int) -> int:
        """
        Get number of rent payments for an asset
        
        Args:
            asset_id: Asset token ID
            
        Returns:
            Number of payments
        """
        return self.rental_manager.functions.getRentPaymentCount(asset_id).call()
    
    def get_rent_payment(self, asset_id: int, index: int) -> Dict[str, Any]:
        """
        Get a specific rent payment by index
        
        Args:
            asset_id: Asset token ID
            index: Payment index
            
        Returns:
            Dict with payer, amount, timestamp
        """
        payment = self.rental_manager.functions.getRentPayment(asset_id, index).call()
        return {
            "payer": payment[0],
            "amount": payment[1],  # Wei
            "timestamp": payment[2]
        }
    
    def get_all_rent_payments(self, asset_id: int) -> List[Dict[str, Any]]:
        """
        Get all rent payments for an asset
        
        Args:
            asset_id: Asset token ID
            
        Returns:
            List of payment dicts
        """
        count = self.get_rent_payment_count(asset_id)
        payments = []
        
        for i in range(count):
            payment = self.get_rent_payment(asset_id, i)
            payments.append(payment)
        
        return payments
    
    # ========== Marketplace Contract Methods ==========
    
    def get_platform_fee_bps(self) -> int:
        """
        Get current platform fee in basis points
        
        Returns:
            Fee in basis points (e.g., 250 = 2.5%)
        """
        return self.marketplace.functions.platformFeeBps().call()
    
    def get_fee_recipient(self) -> str:
        """
        Get fee recipient address
        
        Returns:
            Address receiving platform fees
        """
        return self.marketplace.functions.feeRecipient().call()
    
    # ========== Utility Methods ==========
    
    def get_eth_balance(self, address: str) -> int:
        """
        Get ETH balance for an address (in wei)
        
        Args:
            address: Wallet address
            
        Returns:
            Balance in wei
        """
        return self.w3.eth.get_balance(Web3.to_checksum_address(address))
    
    def wei_to_eth(self, wei_amount: int) -> float:
        """Convert wei to ETH"""
        return self.w3.from_wei(wei_amount, 'ether')
    
    def eth_to_wei(self, eth_amount: float) -> int:
        """Convert ETH to wei"""
        return self.w3.to_wei(eth_amount, 'ether')
    
    def get_block_number(self) -> int:
        """Get current block number"""
        return self.w3.eth.block_number
    
    def get_transaction(self, tx_hash: str) -> Dict[str, Any]:
        """
        Get transaction details
        
        Args:
            tx_hash: Transaction hash
            
        Returns:
            Transaction dict
        """
        tx = self.w3.eth.get_transaction(tx_hash)
        return dict(tx)
    
    def get_transaction_receipt(self, tx_hash: str) -> Optional[Dict[str, Any]]:
        """
        Get transaction receipt
        
        Args:
            tx_hash: Transaction hash
            
        Returns:
            Receipt dict or None if not found
        """
        try:
            receipt = self.w3.eth.get_transaction_receipt(tx_hash)
            return dict(receipt)
        except Exception:
            return None
    
    # ========== Event Querying ==========
    
    def get_asset_initialized_events(
        self,
        token_id: Optional[int] = None,
        from_block: int = 0,
        to_block: str = 'latest'
    ) -> List[Dict[str, Any]]:
        """
        Get AssetInitialized events
        
        Args:
            token_id: Filter by token ID (optional)
            from_block: Starting block number
            to_block: Ending block ('latest' or number)
            
        Returns:
            List of event dicts
        """
        event_filter = self.building1122.events.AssetInitialized.create_filter(
            fromBlock=from_block,
            toBlock=to_block
        )
        
        if token_id is not None:
            event_filter.args = {'tokenId': token_id}
        
        events = event_filter.get_all_entries()
        return [dict(event) for event in events]
    
    def get_rent_paid_events(
        self,
        asset_id: Optional[int] = None,
        from_block: int = 0,
        to_block: str = 'latest'
    ) -> List[Dict[str, Any]]:
        """
        Get RentPaid events
        
        Args:
            asset_id: Filter by asset ID (optional)
            from_block: Starting block number
            to_block: Ending block ('latest' or number)
            
        Returns:
            List of event dicts
        """
        event_filter = self.rental_manager.events.RentPaid.create_filter(
            fromBlock=from_block,
            toBlock=to_block
        )
        
        if asset_id is not None:
            event_filter.args = {'assetId': asset_id}
        
        events = event_filter.get_all_entries()
        return [dict(event) for event in events]
    
    def get_share_traded_events(
        self,
        token_id: Optional[int] = None,
        from_block: int = 0,
        to_block: str = 'latest'
    ) -> List[Dict[str, Any]]:
        """
        Get ShareTraded events from Marketplace
        
        Args:
            token_id: Filter by token ID (optional)
            from_block: Starting block number
            to_block: Ending block ('latest' or number)
            
        Returns:
            List of event dicts
        """
        event_filter = self.marketplace.events.ShareTraded.create_filter(
            fromBlock=from_block,
            toBlock=to_block
        )
        
        if token_id is not None:
            event_filter.args = {'tokenId': token_id}
        
        events = event_filter.get_all_entries()
        return [dict(event) for event in events]


# Singleton instance
_blockchain_reader: Optional[BlockchainReader] = None


def get_blockchain_reader() -> BlockchainReader:
    """Get or create BlockchainReader singleton instance"""
    global _blockchain_reader
    if _blockchain_reader is None:
        _blockchain_reader = BlockchainReader()
    return _blockchain_reader

