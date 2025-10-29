"""
Web3 utilities for blockchain interaction
"""

import json
from typing import Dict, Any, Optional
from web3 import Web3
from web3.exceptions import Web3Exception
from eth_account import Account

from app.core.config import settings


class Web3Manager:
    """Web3 connection and contract interaction manager"""
    
    def __init__(self):
        self.w3: Optional[Web3] = None
        self.account: Optional[Account] = None
        self._connect()
    
    def _connect(self) -> None:
        """Initialize Web3 connection"""
        try:
            self.w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
            
            if self.w3.is_connected():
                print(f"✅ Connected to Ethereum network")
                print(f"📊 Latest block: {self.w3.eth.block_number}")
                
                # Load account if private key is provided
                if settings.PRIVATE_KEY:
                    self.account = Account.from_key(settings.PRIVATE_KEY)
                    print(f"🔑 Account loaded: {self.account.address}")
            else:
                print("❌ Failed to connect to Ethereum network")
                
        except Exception as e:
            print(f"❌ Web3 connection error: {e}")
            self.w3 = None
    
    def is_connected(self) -> bool:
        """Check if Web3 is connected"""
        return self.w3 is not None and self.w3.is_connected()
    
    def get_balance(self, address: str) -> float:
        """Get ETH balance for an address"""
        if not self.is_connected():
            raise Web3Exception("Not connected to Web3")
        
        balance_wei = self.w3.eth.get_balance(address)
        return self.w3.from_wei(balance_wei, 'ether')
    
    def get_contract(self, address: str, abi: list) -> Any:
        """Get contract instance"""
        if not self.is_connected():
            raise Web3Exception("Not connected to Web3")
        
        return self.w3.eth.contract(address=address, abi=abi)
    
    def send_transaction(self, transaction: Dict[str, Any]) -> str:
        """Send a signed transaction"""
        if not self.is_connected() or not self.account:
            raise Web3Exception("Web3 not connected or account not loaded")
        
        # Add nonce and gas price if not provided
        if 'nonce' not in transaction:
            transaction['nonce'] = self.w3.eth.get_transaction_count(self.account.address)
        
        if 'gasPrice' not in transaction:
            transaction['gasPrice'] = self.w3.eth.gas_price
        
        # Sign and send transaction
        signed_txn = self.w3.eth.account.sign_transaction(transaction, self.account.key)
        tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
        
        return tx_hash.hex()
    
    def wait_for_transaction(self, tx_hash: str, timeout: int = 120) -> Dict[str, Any]:
        """Wait for transaction receipt"""
        if not self.is_connected():
            raise Web3Exception("Not connected to Web3")
        
        return self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=timeout)
    
    def estimate_gas(self, transaction: Dict[str, Any]) -> int:
        """Estimate gas for a transaction"""
        if not self.is_connected():
            raise Web3Exception("Not connected to Web3")
        
        return self.w3.eth.estimate_gas(transaction)


# Global Web3 manager instance
web3_manager = Web3Manager()


# Utility functions
def get_web3() -> Web3Manager:
    """Get Web3 manager instance"""
    return web3_manager


def wei_to_ether(wei_amount: int) -> float:
    """Convert Wei to Ether"""
    return Web3.from_wei(wei_amount, 'ether')


def ether_to_wei(ether_amount: float) -> int:
    """Convert Ether to Wei"""
    return Web3.to_wei(ether_amount, 'ether')


def is_valid_address(address: str) -> bool:
    """Validate Ethereum address"""
    return Web3.is_address(address)


def to_checksum_address(address: str) -> str:
    """Convert address to checksum format"""
    return Web3.to_checksum_address(address)

