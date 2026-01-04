#!/usr/bin/env python3
"""
Debug ownership tracking and rental listing deactivation
"""
import sys
import os
from web3 import Web3
from pathlib import Path
import json
import requests

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
print(f"Connected: {w3.is_connected()}\n")

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

print("=" * 70)
print("🔍 GETTING RENTAL LISTINGS FROM BACKEND")
print("=" * 70)

# Get rental listings from backend
try:
    response = requests.get('http://localhost:8000/api/v1/rental/listings')
    listings = response.json()
    
    if not listings:
        print("❌ No rental listings found!")
        print("\n💡 Please create a rental listing first via the app.")
        sys.exit(0)
    
    print(f"\n✅ Found {len(listings)} rental listing(s)\n")
    
    for i, listing in enumerate(listings[:5]):  # Show first 5
        print(f"{'='*70}")
        print(f"📋 LISTING #{i+1}")
        print(f"{'='*70}")
        
        listing_id = listing['listing_id']
        token_id = listing['token_id']
        owner = listing['owner']
        is_active = listing['is_active']
        price = listing.get('price_per_night_pol', 0)
        
        print(f"Listing ID: {listing_id}")
        print(f"Token ID: {token_id}")
        print(f"Owner: {owner}")
        print(f"Price/Night: {price} POL")
        print(f"Is Active: {'✅ Yes' if is_active else '❌ No'}")
        
        # Get asset info from blockchain
        print(f"\n{'─'*70}")
        print(f"🔗 BLOCKCHAIN DATA FOR TOKEN {token_id}")
        print(f"{'─'*70}")
        
        try:
            # Get asset info
            asset = smartrenthub.functions.getAsset(token_id).call()
            # AssetInfo struct: [tokenId, metadataURI, totalShares, createdAt, exists]
            total_shares = asset[2]  # Index 2 is totalShares
            metadata_uri = asset[1]
            print(f"\nMetadata URI: {metadata_uri}")
            print(f"Total Shares: {total_shares}")
            
            # Get all shareholders from SmartRentHub
            shareholders = smartrenthub.functions.getAssetOwners(token_id).call()
            print(f"\n👥 Shareholders tracked in SmartRentHub: {len(shareholders)}")
            
            # Get actual balances from Building1122
            print(f"\n📊 ACTUAL BALANCES:")
            
            balances = []
            for holder in shareholders:
                balance = building.functions.balanceOf(holder, token_id).call()
                percentage = (balance / total_shares) * 100 if total_shares > 0 else 0
                balances.append((holder, balance, percentage))
                
                is_listing_owner = "👑 LISTING OWNER" if holder.lower() == owner.lower() else ""
                print(f"   {holder}: {balance} shares ({percentage:.2f}%) {is_listing_owner}")
            
            # Get top shareholder from contract
            print(f"\n🏆 TOP SHAREHOLDER (from contract):")
            top_holder, top_balance = smartrenthub.functions.getTopShareholder(token_id).call()
            top_percentage = (top_balance / total_shares) * 100 if total_shares > 0 else 0
            print(f"   Address: {top_holder}")
            print(f"   Balance: {top_balance} shares ({top_percentage:.2f}%)")
            
            # Check if listing owner is still top shareholder
            print(f"\n🔍 ANALYSIS:")
            
            if owner.lower() == top_holder.lower():
                print(f"   ✅ Listing owner IS the top shareholder (correct)")
            else:
                print(f"   ❌ Listing owner IS NOT the top shareholder!")
                print(f"   ⚠️  BUG: Listing should have been deactivated!")
                print(f"\n   Listing Owner: {owner}")
                print(f"   Top Shareholder: {top_holder}")
                
                # Check if listing is still active on blockchain
                try:
                    blockchain_listing = rentalhub.functions.getRentalListing(listing_id).call()
                    blockchain_active = blockchain_listing[6]  # isActive field
                    
                    print(f"\n   Backend says listing is active: {is_active}")
                    print(f"   Blockchain says listing is active: {blockchain_active}")
                    
                    if blockchain_active:
                        print(f"\n   ❌ CRITICAL BUG: onTopShareholderChanged was NOT called!")
                        print(f"   📝 The updateOwnership function did not trigger RentalHub!")
                    else:
                        print(f"\n   ⚠️  Backend is out of sync with blockchain")
                        print(f"   💡 Refresh the app to see updated status")
                        
                except Exception as e:
                    print(f"\n   ❌ Error checking blockchain listing: {e}")
            
            # Check distribution simulation
            print(f"\n💰 SIMULATED RENTAL PAYMENT DISTRIBUTION (0.1 POL):")
            rental_payment_wei = w3.to_wei(0.1, 'ether')
            platform_fee = rental_payment_wei * 25 // 1000  # 2.5%
            owner_payment = rental_payment_wei - platform_fee
            
            print(f"   Total Payment: 0.1 POL")
            print(f"   Platform Fee (2.5%): {w3.from_wei(platform_fee, 'ether')} POL")
            print(f"   Owner Payment (97.5%): {w3.from_wei(owner_payment, 'ether')} POL")
            print(f"\n   Distribution to shareholders:")
            
            total_distributed = 0
            for holder, balance, percentage in balances:
                payment = (owner_payment * balance) // total_shares
                payment_in_pol = w3.from_wei(payment, 'ether')
                is_listing_owner = "👑" if holder.lower() == owner.lower() else ""
                print(f"      {holder}: {payment_in_pol} POL ({percentage:.2f}%) {is_listing_owner}")
                total_distributed += payment
            
            # Check for rounding dust
            dust = owner_payment - total_distributed
            if dust > 0:
                print(f"\n   Dust (rounding): {w3.from_wei(dust, 'ether')} POL (goes to first shareholder)")
                
        except Exception as e:
            print(f"❌ Error analyzing token {token_id}: {e}")
            import traceback
            traceback.print_exc()
        
        print(f"\n")
        
except requests.exceptions.ConnectionError:
    print("❌ Backend not running! Start backend first:")
    print("   cd SmartRent/backend")
    print("   py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("=" * 70)
print("✅ DEBUG COMPLETE")
print("=" * 70)

