#!/usr/bin/env python3
"""
Check all contract links
"""
import sys
import os
from web3 import Web3
from pathlib import Path
import json

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
print("🔗 CONTRACT LINK VERIFICATION")
print("=" * 70)

print(f"\n📍 Contract Addresses:")
print(f"   Building1122:  {BUILDING1122_ADDRESS}")
print(f"   SmartRentHub:  {SMARTRENTHUB_ADDRESS}")
print(f"   RentalHub:     {RENTAL_HUB_ADDRESS}")

print(f"\n{'─'*70}")
print("🔍 CHECKING LINKS...")
print(f"{'─'*70}")

all_good = True

# 1. Building1122 → SmartRentHub
print(f"\n1️⃣ Building1122 → SmartRentHub:")
try:
    building_to_hub = building.functions.smartRentHub().call()
    if building_to_hub.lower() == SMARTRENTHUB_ADDRESS.lower():
        print(f"   ✅ Correct: {building_to_hub}")
    else:
        print(f"   ❌ WRONG: {building_to_hub}")
        print(f"   Expected: {SMARTRENTHUB_ADDRESS}")
        all_good = False
except Exception as e:
    print(f"   ❌ ERROR: {e}")
    all_good = False

# 2. SmartRentHub → Building1122
print(f"\n2️⃣ SmartRentHub → Building1122:")
try:
    hub_to_building = smartrenthub.functions.buildingToken().call()
    if hub_to_building.lower() == BUILDING1122_ADDRESS.lower():
        print(f"   ✅ Correct: {hub_to_building}")
    else:
        print(f"   ❌ WRONG: {hub_to_building}")
        print(f"   Expected: {BUILDING1122_ADDRESS}")
        all_good = False
except Exception as e:
    print(f"   ❌ ERROR: {e}")
    all_good = False

# 3. SmartRentHub → RentalHub ⚠️ CRITICAL FOR BUG FIX
print(f"\n3️⃣ SmartRentHub → RentalHub: ⚠️  CRITICAL")
try:
    hub_to_rental = smartrenthub.functions.rentalHub().call()
    if hub_to_rental.lower() == RENTAL_HUB_ADDRESS.lower():
        print(f"   ✅ Correct: {hub_to_rental}")
    elif hub_to_rental == "0x0000000000000000000000000000000000000000":
        print(f"   ❌ NOT SET! Current: {hub_to_rental}")
        print(f"   Expected: {RENTAL_HUB_ADDRESS}")
        print(f"\n   🚨 THIS IS THE BUG!")
        print(f"   📝 SmartRentHub.updateOwnership cannot call RentalHub")
        print(f"   📝 onTopShareholderChanged is NEVER triggered!")
        all_good = False
    else:
        print(f"   ❌ WRONG: {hub_to_rental}")
        print(f"   Expected: {RENTAL_HUB_ADDRESS}")
        all_good = False
except Exception as e:
    print(f"   ❌ ERROR: {e}")
    all_good = False

# 4. RentalHub → SmartRentHub
print(f"\n4️⃣ RentalHub → SmartRentHub:")
try:
    rental_to_hub = rentalhub.functions.smartRentHub().call()
    if rental_to_hub.lower() == SMARTRENTHUB_ADDRESS.lower():
        print(f"   ✅ Correct: {rental_to_hub}")
    else:
        print(f"   ❌ WRONG: {rental_to_hub}")
        print(f"   Expected: {SMARTRENTHUB_ADDRESS}")
        all_good = False
except Exception as e:
    print(f"   ❌ ERROR: {e}")
    all_good = False

# 5. RentalHub → Building1122
print(f"\n5️⃣ RentalHub → Building1122:")
try:
    rental_to_building = rentalhub.functions.buildingToken().call()
    if rental_to_building.lower() == BUILDING1122_ADDRESS.lower():
        print(f"   ✅ Correct: {rental_to_building}")
    else:
        print(f"   ❌ WRONG: {rental_to_building}")
        print(f"   Expected: {BUILDING1122_ADDRESS}")
        all_good = False
except Exception as e:
    print(f"   ❌ ERROR: {e}")
    all_good = False

print(f"\n{'='*70}")

if all_good:
    print("✅ ALL LINKS CORRECT!")
else:
    print("❌ SOME LINKS ARE BROKEN!")
    print("\n💡 FIX:")
    print("   Call SmartRentHub.setRentalHub(RENTAL_HUB_ADDRESS)")
    print(f"   Address: {RENTAL_HUB_ADDRESS}")
    
print(f"{'='*70}\n")

