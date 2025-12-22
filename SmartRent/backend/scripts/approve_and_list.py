#!/usr/bin/env python3
"""
Complete Fractional Share Sale Demo
1. Approve marketplace
2. List shares for sale
3. Simulate a purchase
"""

import sys
import os
import json

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from web3 import Web3
from eth_account import Account
from app.core.config import settings

def main():
    print("\n🎬 SmartRent Fractional Sale - Complete Demo")
    print("="*60)
    
    w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
    
    # Load contracts
    with open('../blockchain/artifacts/contracts/Building1122.sol/Building1122.json', 'r') as f:
        building_abi = json.load(f)['abi']
    
    building_contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.BUILDING1122_CONTRACT_ADDRESS),
        abi=building_abi
    )
    
    # Your account
    account = Account.from_key(settings.WALLET_PRIVATE_KEY)
    marketplace_address = Web3.to_checksum_address(settings.MARKETPLACE_CONTRACT_ADDRESS)
    
    print(f"📍 Owner: {account.address}")
    print(f"🏪 Marketplace: {marketplace_address}")
    
    # Check current approval status
    print(f"\n📋 ADIM 1: Approval Status Kontrolü")
    print("-"*60)
    
    is_approved = building_contract.functions.isApprovedForAll(
        account.address,
        marketplace_address
    ).call()
    
    print(f"Marketplace Approval: {'✅ Onaylı' if is_approved else '❌ Onay Gerekli'}")
    
    if not is_approved:
        print(f"\n⚙️  ADIM 2: Marketplace'e Approval Veriliyor...")
        print("-"*60)
        
        # Build approval transaction
        nonce = w3.eth.get_transaction_count(account.address)
        
        approval_tx = building_contract.functions.setApprovalForAll(
            marketplace_address,
            True
        ).build_transaction({
            'from': account.address,
            'nonce': nonce,
            'gas': 100000,
            'gasPrice': w3.eth.gas_price
        })
        
        # Sign and send
        signed_tx = w3.eth.account.sign_transaction(approval_tx, account.key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        
        print(f"📤 Transaction sent: {tx_hash.hex()}")
        print(f"⏳ Waiting for confirmation...")
        
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
        
        if receipt['status'] == 1:
            print(f"✅ Approval successful!")
            print(f"   Block: {receipt['blockNumber']}")
            print(f"   Gas Used: {receipt['gasUsed']:,}")
            print(f"   TX: https://polygonscan.com/tx/{tx_hash.hex()}")
        else:
            print(f"❌ Approval failed!")
            return
    else:
        print(f"✅ Marketplace zaten onaylı, devam ediyoruz!")
    
    # Show your shares
    print(f"\n📊 ADIM 3: Share Bilgileri")
    print("-"*60)
    
    token_id = 1  # NFT #1 (Istanbul Apartment)
    your_balance = building_contract.functions.balanceOf(account.address, token_id).call()
    total_supply = building_contract.functions.totalSupply(token_id).call()
    
    print(f"🏠 NFT #{token_id} - Istanbul Apartment")
    print(f"   Your Shares: {your_balance:,} / {total_supply:,}")
    print(f"   Ownership: {your_balance/total_supply*100:.2f}%")
    
    # Propose a sale
    shares_to_sell = 100  # Sell 100 shares (10%)
    price_per_share_matic = 0.01  # 0.01 MATIC per share
    total_price_matic = shares_to_sell * price_per_share_matic
    
    print(f"\n💰 ADIM 4: Satış Teklifi Oluşturma")
    print("-"*60)
    print(f"📦 Satılacak: {shares_to_sell} shares")
    print(f"💵 Share Fiyatı: {price_per_share_matic} MATIC")
    print(f"💰 Toplam Fiyat: {total_price_matic} MATIC (~${total_price_matic*0.90:.2f})")
    print(f"📉 Kalan Sahiplik: {(your_balance-shares_to_sell)/total_supply*100:.2f}%")
    
    print(f"\n{'='*60}")
    print(f"✅ Marketplace Approval Tamamlandı!")
    print(f"{'='*60}")
    
    print(f"""
🎯 Artık şunları yapabilirsiniz:

1️⃣  Backend API ile Listing:
   curl -X POST http://localhost:8000/api/v1/marketplace/list \\
     -H "Content-Type: application/json" \\
     -d '{{
       "token_id": {token_id},
       "amount": {shares_to_sell},
       "price_per_share": "{price_per_share_matic}"
     }}'

2️⃣  Flutter App ile:
   • Assets sayfasından NFT seçin
   • "Sell Shares" butonu
   • Miktar ve fiyat girin
   • Onaylayın

3️⃣  Direct Contract Call:
   • Alıcı safeTransferFrom() çağırır
   • ETH ile ödeme yapar
   • Share transfer olur

💡 NOT: Marketplace contract'ınız şu anda buyShare() 
   fonksiyonu ile direkt alım-satım yapabilir!
""")
    
    print(f"\n🔍 Marketplace Contract'ı İnceleyin:")
    print(f"   https://polygonscan.com/address/{marketplace_address}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
