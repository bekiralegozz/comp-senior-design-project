#!/usr/bin/env python3
"""
Mint the first NFT directly using Web3 and IPFS services
"""

import sys
import os
import asyncio

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.services.web3_service import Web3Service
from app.services.ipfs_service import IPFSService

async def main():
    print("🏠 Minting First SmartRent NFT to Polygon Mainnet...")
    print("=" * 60)
    
    # Initialize services
    web3_service = Web3Service()
    ipfs_service = IPFSService()
    
    # Asset details
    asset_data = {
        "asset_id": 1,
        "name": "Luxury Apartment - Istanbul Besiktas",
        "description": "Premium 3+1 apartment with stunning Bosphorus view in the heart of Besiktas, Istanbul. Features modern amenities, 24/7 security, and prime location.",
        "image_url": "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800&auto=format&fit=crop",
        "total_shares": 1000,
        "attributes": {
            "location": "Besiktas, Istanbul, Turkey",
            "size": "150 m²",
            "rooms": "3+1",
            "floor": "8th Floor",
            "year_built": "2023",
            "view": "Bosphorus Sea View",
            "parking": "2 spaces",
            "amenities": "Gym, Pool, Concierge"
        }
    }
    
    print(f"\n📋 Asset Details:")
    print(f"   Token ID: {asset_data['asset_id']}")
    print(f"   Name: {asset_data['name']}")
    print(f"   Total Shares: {asset_data['total_shares']}")
    print(f"   Location: {asset_data['attributes']['location']}")
    
    # Step 1: Upload metadata to IPFS
    print(f"\n📤 Step 1: Uploading metadata to IPFS/Pinata...")
    
    metadata_uri = ipfs_service.create_asset_metadata(
        asset_name=asset_data["name"],
        description=asset_data["description"],
        image_url=asset_data["image_url"],
        location=asset_data["attributes"]["location"],
        square_feet=1615,  # 150 m² = ~1615 sq ft
        bedrooms=3,
        total_shares=asset_data["total_shares"]
    )
    
    if not metadata_uri:
        print("   ❌ Failed to upload metadata to IPFS")
        sys.exit(1)
        
    print(f"   ✅ Metadata uploaded: {metadata_uri}")
    
    # Step 2: Mint NFT on blockchain
    print(f"\n⛓️  Step 2: Minting NFT on Polygon Mainnet...")
    print(f"   This will take about 30 seconds for confirmation...")
    
    try:
        result = web3_service.mint_asset_nft(
            token_id=asset_data["asset_id"],
            owner_address=web3_service.account.address,
            total_shares=asset_data["total_shares"],
            metadata_uri=metadata_uri
        )
        
        print(f"\n🎉 SUCCESS! NFT Minted!")
        print(f"=" * 60)
        print(f"📍 Transaction Hash: {result['transaction_hash']}")
        print(f"🆔 Token ID: {result['token_id']}")
        print(f"📊 Total Shares: {asset_data['total_shares']}")
        print(f"📝 Metadata URI: {metadata_uri}")
        print(f"⛽ Gas Used: {result['gas_used']}")
        print(f"🏗️  Block Number: {result['block_number']}")
        print(f"\n🌐 View on PolygonScan:")
        print(f"   https://polygonscan.com/tx/{result['transaction_hash']}")
        print(f"\n🖼️  View on OpenSea (after indexing, ~5-10 minutes):")
        print(f"   https://opensea.io/assets/matic/{web3_service.building_address}/{asset_data['asset_id']}")
        print(f"\n✅ Your NFT is now live on Polygon Mainnet!")
        
    except Exception as e:
        print(f"\n❌ Error minting NFT: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
