#!/usr/bin/env python3
"""
Mint second NFT - Villa in Antalya
"""

import sys
import os
import asyncio

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.services.web3_service import Web3Service
from app.services.ipfs_service import IPFSService

async def main():
    print("🏖️  Minting Second SmartRent NFT - Antalya Villa...")
    print("=" * 60)
    
    web3_service = Web3Service()
    ipfs_service = IPFSService()
    
    asset_data = {
        "asset_id": 2,
        "name": "Luxury Villa - Antalya Belek",
        "description": "Stunning 5+2 villa with private pool and Mediterranean view in Belek, Antalya. Perfect for luxury living and vacation rental investment.",
        "image_url": "https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800&auto=format&fit=crop",
        "total_shares": 2000,  # More expensive property = more shares
        "attributes": {
            "location": "Belek, Antalya, Turkey",
            "size": "350 m²",
            "rooms": "5+2",
            "pool": "Private Pool",
            "year_built": "2024",
            "view": "Mediterranean Sea View",
            "parking": "3 spaces",
            "amenities": "Pool, Garden, BBQ Area"
        }
    }
    
    print(f"\n📋 Asset Details:")
    print(f"   Token ID: {asset_data['asset_id']}")
    print(f"   Name: {asset_data['name']}")
    print(f"   Total Shares: {asset_data['total_shares']}")
    print(f"   Location: {asset_data['attributes']['location']}")
    
    # Step 1: Upload to IPFS
    print(f"\n📤 Step 1: Uploading metadata to IPFS...")
    
    metadata_uri = ipfs_service.create_asset_metadata(
        asset_name=asset_data["name"],
        description=asset_data["description"],
        image_url=asset_data["image_url"],
        location=asset_data["attributes"]["location"],
        square_feet=3767,  # 350 m² = ~3767 sq ft
        bedrooms=5,
        property_type="Villa",
        total_shares=asset_data["total_shares"]
    )
    
    if not metadata_uri:
        print("   ❌ Failed to upload metadata")
        sys.exit(1)
        
    print(f"   ✅ Metadata uploaded: {metadata_uri}")
    
    # Step 2: Mint NFT
    print(f"\n⛓️  Step 2: Minting NFT on Polygon...")
    print(f"   Waiting for confirmation...")
    
    try:
        result = web3_service.mint_asset_nft(
            token_id=asset_data["asset_id"],
            owner_address=web3_service.account.address,
            total_shares=asset_data["total_shares"],
            metadata_uri=metadata_uri
        )
        
        if result.get("success"):
            print(f"\n🎉 SUCCESS! Villa NFT Minted!")
            print(f"=" * 60)
            print(f"📍 Transaction: {result['transaction_hash']}")
            print(f"🆔 Token ID: {result['token_id']}")
            print(f"📊 Total Shares: {asset_data['total_shares']}")
            print(f"📝 Metadata: {metadata_uri}")
            print(f"⛽ Gas Used: {result['gas_used']}")
            print(f"🏗️  Block: {result['block_number']}")
            print(f"\n🌐 PolygonScan:")
            print(f"   https://polygonscan.com/tx/{result['transaction_hash']}")
            print(f"\n🖼️  OpenSea (after 5-10 min):")
            print(f"   https://opensea.io/assets/matic/{web3_service.building_address}/{asset_data['asset_id']}")
            print(f"\n✅ NFT #2 is live on Polygon Mainnet!")
        else:
            print(f"\n❌ Error: {result.get('error', 'Unknown error')}")
            sys.exit(1)
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
