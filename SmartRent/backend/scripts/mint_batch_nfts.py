#!/usr/bin/env python3
"""
Mint multiple NFTs - Batch minting script
"""

import sys
import os
import asyncio

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.services.web3_service import Web3Service
from app.services.ipfs_service import IPFSService

# Property portfolio to mint
PROPERTIES = [
    {
        "asset_id": 3,
        "name": "Modern Apartment - Izmir Karsiyaka",
        "description": "Contemporary 2+1 apartment near the sea in Karsiyaka, Izmir. Great for rental income and coastal living.",
        "image_url": "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&auto=format&fit=crop",
        "total_shares": 800,
        "location": "Karsiyaka, Izmir, Turkey",
        "size": "110 m²",
        "bedrooms": 2,
        "square_feet": 1184,
        "property_type": "Apartment"
    },
    {
        "asset_id": 4,
        "name": "Penthouse Suite - Ankara Cankaya",
        "description": "Exclusive penthouse in the heart of Ankara's diplomatic district. Premium location with panoramic city views.",
        "image_url": "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800&auto=format&fit=crop",
        "total_shares": 1500,
        "location": "Cankaya, Ankara, Turkey",
        "size": "220 m²",
        "bedrooms": 4,
        "square_feet": 2368,
        "property_type": "Penthouse"
    }
]

async def mint_property(web3_service, ipfs_service, property_data):
    """Mint a single property NFT"""
    
    print(f"\n{'='*60}")
    print(f"🏠 Minting: {property_data['name']}")
    print(f"{'='*60}")
    print(f"   Token ID: {property_data['asset_id']}")
    print(f"   Location: {property_data['location']}")
    print(f"   Total Shares: {property_data['total_shares']:,}")
    
    # Upload metadata to IPFS
    print(f"\n📤 Uploading to IPFS...")
    metadata_uri = ipfs_service.create_asset_metadata(
        asset_name=property_data["name"],
        description=property_data["description"],
        image_url=property_data["image_url"],
        location=property_data["location"],
        square_feet=property_data["square_feet"],
        bedrooms=property_data["bedrooms"],
        property_type=property_data["property_type"],
        total_shares=property_data["total_shares"]
    )
    
    if not metadata_uri:
        print(f"   ❌ Failed to upload metadata")
        return None
        
    print(f"   ✅ Metadata: {metadata_uri}")
    
    # Mint NFT
    print(f"\n⛓️  Minting on Polygon...")
    result = web3_service.mint_asset_nft(
        token_id=property_data["asset_id"],
        owner_address=web3_service.account.address,
        total_shares=property_data["total_shares"],
        metadata_uri=metadata_uri
    )
    
    if result.get("success"):
        print(f"\n✅ Success!")
        print(f"   TX: {result['transaction_hash']}")
        print(f"   Gas: {result['gas_used']:,}")
        print(f"   Block: {result['block_number']}")
        return result
    else:
        print(f"\n❌ Failed: {result.get('error', 'Unknown error')}")
        return None


async def main():
    print("\n🏘️  SmartRent Batch NFT Minting")
    print("="*60)
    print(f"Properties to mint: {len(PROPERTIES)}")
    
    web3_service = Web3Service()
    ipfs_service = IPFSService()
    
    results = []
    
    for property_data in PROPERTIES:
        result = await mint_property(web3_service, ipfs_service, property_data)
        if result:
            results.append({
                "token_id": property_data["asset_id"],
                "name": property_data["name"],
                "tx_hash": result["transaction_hash"]
            })
        
        # Small delay between mints
        if property_data != PROPERTIES[-1]:
            print(f"\n⏳ Waiting 3 seconds before next mint...")
            await asyncio.sleep(3)
    
    # Summary
    print(f"\n{'='*60}")
    print(f"📊 Batch Minting Complete!")
    print(f"{'='*60}")
    print(f"✅ Successfully minted: {len(results)}/{len(PROPERTIES)}")
    
    if results:
        print(f"\n📋 Minted NFTs:")
        for r in results:
            print(f"   • NFT #{r['token_id']}: {r['name']}")
            print(f"     TX: https://polygonscan.com/tx/{r['tx_hash']}")
            print(f"     OpenSea: https://opensea.io/assets/matic/{web3_service.building_address}/{r['token_id']}")
    
    print(f"\n🎉 All NFTs are live on Polygon Mainnet!")


if __name__ == "__main__":
    asyncio.run(main())
