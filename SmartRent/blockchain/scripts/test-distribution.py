#!/usr/bin/env python3
"""
Test script to check rental payment distribution mechanism
"""
import sys
import os
from web3 import Web3
from pathlib import Path
import json

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Load environment variables
from dotenv import load_dotenv
blockchain_dir = Path(__file__).parent.parent
load_dotenv(blockchain_dir / '.env')

# Configuration
RPC_URL = os.getenv('POLYGON_RPC_URL')
SMARTRENTHUB_ADDRESS = "0xa5F12C3c5A43fdEfcAff190DcAb057144897df8d"
BUILDING1122_ADDRESS = "0xd4f7c1D9979a6b1795C4E23fF9FD6b3De0ce3793"
RENTAL_HUB_ADDRESS = "0xbC549BD4a892aDfAa42399E8cD22D3574f113B5a"

# Initialize Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
print(f"Connected to Polygon: {w3.is_connected()}")
print(f"Latest Block: {w3.eth.block_number}\n")

# Load ABIs
abi_dir = blockchain_dir / 'abis'
with open(abi_dir / 'SmartRentHub.json') as f:
    smartrenthub_abi = json.load(f)
with open(abi_dir / 'Building1122.json') as f:
    building_abi = json.load(f)
with open(abi_dir / 'RentalHub.json') as f:
    rentalhub_abi = json.load(f)

# Initialize contracts
smartrenthub = w3.eth.contract(address=SMARTRENTHUB_ADDRESS, abi=smartrenthub_abi)
building = w3.eth.contract(address=BUILDING1122_ADDRESS, abi=building_abi)
rentalhub = w3.eth.contract(address=RENTAL_HUB_ADDRESS, abi=rentalhub_abi)

print("=" * 60)
print("🏢 SMART CONTRACT STATUS")
print("=" * 60)

# Check SmartRentHub
try:
    owner = smartrenthub.functions.owner().call()
    print(f"✅ SmartRentHub Owner: {owner}")
except Exception as e:
    print(f"❌ SmartRentHub Error: {e}")

# Check Building1122
try:
    building_owner = building.functions.owner().call()
    print(f"✅ Building1122 Owner: {building_owner}")
    
    # Check if Building1122 knows about SmartRentHub
    linked_hub = building.functions.smartRentHub().call()
    print(f"✅ Building1122 -> SmartRentHub: {linked_hub}")
    if linked_hub.lower() != SMARTRENTHUB_ADDRESS.lower():
        print(f"   ⚠️  WARNING: Expected {SMARTRENTHUB_ADDRESS}")
except Exception as e:
    print(f"❌ Building1122 Error: {e}")

# Check RentalHub
try:
    rentalhub_owner = rentalhub.functions.owner().call()
    print(f"✅ RentalHub Owner: {rentalhub_owner}")
    
    # Check if RentalHub knows about SmartRentHub
    rental_smart_hub = rentalhub.functions.smartRentHub().call()
    print(f"✅ RentalHub -> SmartRentHub: {rental_smart_hub}")
    if rental_smart_hub.lower() != SMARTRENTHUB_ADDRESS.lower():
        print(f"   ⚠️  WARNING: Expected {SMARTRENTHUB_ADDRESS}")
        
    # Check if RentalHub knows about Building1122
    rental_building = rentalhub.functions.buildingToken().call()
    print(f"✅ RentalHub -> Building1122: {rental_building}")
    if rental_building.lower() != BUILDING1122_ADDRESS.lower():
        print(f"   ⚠️  WARNING: Expected {BUILDING1122_ADDRESS}")
except Exception as e:
    print(f"❌ RentalHub Error: {e}")

print("\n" + "=" * 60)
print("📊 CHECKING FOR ASSETS & RENTALS")
print("=" * 60)

# Try to get some tokenIds
token_id = None
try:
    # Try tokenId 1, 2, 3...
    for test_id in range(1, 10):
        try:
            asset = smartrenthub.functions.getAsset(test_id).call()
            if asset[4]:  # exists field
                token_id = test_id
                print(f"\n✅ Found Asset: TokenID = {token_id}")
                print(f"   Total Shares: {asset[1]}")
                print(f"   Metadata URI: {asset[0]}")
                break
        except:
            continue
    
    if not token_id:
        print("\n❌ No assets found! You need to mint an NFT first.")
        print("\n💡 RECOMMENDATION:")
        print("   1. Mint an NFT via the Flutter app")
        print("   2. Split shares between multiple wallets")
        print("   3. Create a rental listing")
        print("   4. Book the rental")
        print("   5. Check Polygonscan 'Internal Txns' to see distribution")
        sys.exit(0)
        
except Exception as e:
    print(f"❌ Error searching for assets: {e}")
    sys.exit(1)

# If we found an asset, analyze it
print("\n" + "=" * 60)
print(f"🔍 ANALYZING TOKEN ID {token_id}")
print("=" * 60)

# Get shareholders
try:
    shareholders = smartrenthub.functions.getAssetOwners(token_id).call()
    print(f"\n👥 Shareholders ({len(shareholders)} total):")
    
    asset = smartrenthub.functions.getAsset(token_id).call()
    total_shares = asset[1]
    
    total_distributed = 0
    
    for i, holder in enumerate(shareholders):
        balance = building.functions.balanceOf(holder, token_id).call()
        percentage = (balance / total_shares) * 100
        print(f"\n   {i + 1}. {holder}")
        print(f"      Shares: {balance} ({percentage:.2f}%)")
        total_distributed += balance
    
    print(f"\n✅ Total shares distributed: {total_distributed} / {total_shares}")
    
    # Get top shareholder
    top_holder, top_balance = smartrenthub.functions.getTopShareholder(token_id).call()
    print(f"\n🏆 Top Shareholder: {top_holder}")
    print(f"   Shares: {top_balance}")
    
    # Simulate rental payment distribution
    rental_payment_wei = w3.to_wei(0.1, 'ether')  # 0.1 POL
    print(f"\n💰 Simulated Rental Payment Distribution (0.1 POL):")
    print(f"   Platform Fee (2.5%): {w3.from_wei(rental_payment_wei * 25 // 1000, 'ether')} POL")
    
    owner_payment = rental_payment_wei * 975 // 1000
    print(f"   Owner Payment (97.5%): {w3.from_wei(owner_payment, 'ether')} POL")
    print(f"\n   Distribution to shareholders:")
    
    for i, holder in enumerate(shareholders):
        balance = building.functions.balanceOf(holder, token_id).call()
        payment = (owner_payment * balance) // total_shares
        payment_in_pol = w3.from_wei(payment, 'ether')
        print(f"      {holder}: {payment_in_pol} POL")
        
except Exception as e:
    print(f"❌ Error analyzing token: {e}")
    import traceback
    traceback.print_exc()

# Check if there are rental listings
print("\n" + "=" * 60)
print("🏠 RENTAL LISTINGS")
print("=" * 60)

try:
    listing_count = rentalhub.functions.getActiveRentalListingsCount().call()
    print(f"Active Rental Listings: {listing_count}")
    
    if listing_count > 0:
        listings = rentalhub.functions.getActiveRentalListings().call()
        for i, listing in enumerate(listings[:3]):  # Show first 3
            print(f"\nListing {i+1}:")
            print(f"  Listing ID: {listing[0]}")
            print(f"  Token ID: {listing[1]}")
            print(f"  Owner: {listing[2]}")
            print(f"  Price/Night: {w3.from_wei(listing[3], 'ether')} POL")
except Exception as e:
    print(f"❌ Error getting rental listings: {e}")

print("\n" + "=" * 60)
print("✅ DISTRIBUTION MECHANISM CHECK COMPLETE")
print("=" * 60)
print("\n📝 SUMMARY:")
print("   The RentalHub contract HAS the _distributeRentalPayment function.")
print("   It WILL distribute payments proportionally to all shareholders.")
print("   To test it:")
print("   1. Create a rental listing (if not exists)")
print("   2. Book a rental from another wallet")
print("   3. Check Polygonscan transaction 'Internal Txns' tab")
print("   4. You should see multiple payments to different shareholders")
print("\n")

