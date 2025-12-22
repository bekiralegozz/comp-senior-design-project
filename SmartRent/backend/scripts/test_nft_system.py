#!/usr/bin/env python3
"""
Quick test script for NFT functionality
Tests Web3 connection, IPFS, and basic operations
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.web3_service import web3_service
from app.services.ipfs_service import ipfs_service


def test_web3_connection():
    """Test blockchain connection"""
    print("\n🔗 Testing Web3 Connection...")
    print("=" * 50)
    
    connected = web3_service.is_connected()
    print(f"Connected: {connected}")
    
    if connected:
        print(f"Chain ID: {web3_service.chain_id}")
        
        if web3_service.account:
            print(f"Account: {web3_service.account.address}")
            balance = web3_service.get_balance(web3_service.account.address)
            print(f"Balance: {balance} MATIC")
        else:
            print("⚠️  No wallet configured (read-only mode)")
        
        gas_price = web3_service.get_gas_price()
        print(f"Gas Price: {web3_service.w3.from_wei(gas_price, 'gwei')} gwei")
        
        print(f"\n📋 Contract Addresses:")
        print(f"Building1122:  {web3_service.building_address or 'Not deployed'}")
        print(f"Marketplace:   {web3_service.marketplace_address or 'Not deployed'}")
        print(f"RentalManager: {web3_service.rental_manager_address or 'Not deployed'}")
    
    return connected


def test_ipfs_connection():
    """Test IPFS/Pinata connection"""
    print("\n📦 Testing IPFS/Pinata Connection...")
    print("=" * 50)
    
    if not ipfs_service.api_key:
        print("⚠️  Pinata not configured")
        return False
    
    authenticated = ipfs_service.test_authentication()
    print(f"Authenticated: {authenticated}")
    
    return authenticated


def test_asset_query(token_id: int = 1):
    """Test querying asset from blockchain"""
    print(f"\n🔍 Testing Asset Query (Token ID: {token_id})...")
    print("=" * 50)
    
    if not web3_service.building_address:
        print("⚠️  Building1122 contract not deployed")
        return
    
    asset_info = web3_service.get_asset_info(token_id)
    
    if asset_info:
        print(f"Token ID: {asset_info['token_id']}")
        print(f"Total Supply: {asset_info['total_supply']}")
        print(f"Metadata URI: {asset_info['metadata_uri']}")
        print(f"Exists: {asset_info['exists']}")
    else:
        print(f"Asset with token ID {token_id} not found")


def main():
    """Run all tests"""
    print("\n" + "=" * 50)
    print("🧪 SmartRent NFT System Tests")
    print("=" * 50)
    
    # Test Web3
    web3_ok = test_web3_connection()
    
    # Test IPFS
    ipfs_ok = test_ipfs_connection()
    
    # Test asset query if contracts deployed
    if web3_ok and web3_service.building_address:
        test_asset_query()
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 Test Summary")
    print("=" * 50)
    print(f"Web3 Connection: {'✅' if web3_ok else '❌'}")
    print(f"IPFS Connection: {'✅' if ipfs_ok else '❌'}")
    print("\n💡 Next Steps:")
    
    if not web3_ok:
        print("1. Check WEB3_PROVIDER_URL in .env")
        print("2. Verify Polygon RPC is accessible")
    
    if not ipfs_ok:
        print("1. Get Pinata API keys from https://pinata.cloud")
        print("2. Add PINATA_API_KEY and PINATA_SECRET_KEY to .env")
    
    if not web3_service.building_address:
        print("1. Deploy contracts using: cd ../blockchain && npx hardhat run scripts/deploy.js --network polygon")
        print("2. Add contract addresses to backend/.env")
    
    if not web3_service.account:
        print("1. Add WALLET_PRIVATE_KEY to .env")
    
    print("\n✨ Ready to mint NFTs when all systems are green!\n")


if __name__ == "__main__":
    main()
