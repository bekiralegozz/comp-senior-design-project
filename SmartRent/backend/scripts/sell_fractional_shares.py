#!/usr/bin/env python3
"""
Fractional Share Selling Script
Lists your NFT shares on the marketplace for others to buy
"""

import sys
import os
import json
from decimal import Decimal

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from web3 import Web3
from app.core.config import settings

def list_shares_for_sale():
    """
    Fractional share satışı için 3 yöntem:
    
    1. Direct P2P Transfer: Bir alıcıya direkt transfer
    2. Marketplace Listing: Fiyat belirleyip marketplace'e koyma
    3. Partial Sale: Toplam share'inizin bir kısmını satma
    """
    
    w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
    
    # Load contract ABIs
    with open('../blockchain/artifacts/contracts/Building1122.sol/Building1122.json', 'r') as f:
        building_abi = json.load(f)['abi']
    
    with open('../blockchain/artifacts/contracts/Marketplace.sol/Marketplace.json', 'r') as f:
        marketplace_abi = json.load(f)['abi']
    
    # Contract instances
    building_contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.BUILDING1122_CONTRACT_ADDRESS),
        abi=building_abi
    )
    
    marketplace_contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.MARKETPLACE_CONTRACT_ADDRESS),
        abi=marketplace_abi
    )
    
    print("\n🏪 SmartRent Fractional Share Marketplace")
    print("="*60)
    
    # Your wallet
    wallet = settings.CONTRACT_OWNER_ADDRESS
    print(f"📍 Your Wallet: {wallet}")
    
    # Show your holdings
    print(f"\n💼 Your Current Holdings:")
    print("-"*60)
    
    holdings = []
    for token_id in [1, 2]:
        try:
            if building_contract.functions.tokenInitialized(token_id).call():
                total = building_contract.functions.totalSupply(token_id).call()
                balance = building_contract.functions.balanceOf(wallet, token_id).call()
                
                holdings.append({
                    'token_id': token_id,
                    'balance': balance,
                    'total': total,
                    'percentage': (balance/total*100)
                })
                
                print(f"\n🏠 NFT #{token_id}")
                print(f"   Your Shares: {balance:,} / {total:,}")
                print(f"   Ownership: {balance/total*100:.2f}%")
        except:
            pass
    
    if not holdings:
        print("\n❌ No NFTs found!")
        return
    
    print(f"\n{'='*60}")
    print("📋 FRACTIONAL SHARE SATIŞ YÖNTEMLERİ")
    print("="*60)
    
    print("""
🔹 YÖNTEM 1: Direct P2P Transfer (Ücretsiz, Hızlı)
   • Belirli bir alıcıya direkt transfer
   • Gas fee dışında maliyet yok
   • Fiyat off-chain anlaşılır
   • Komut: safeTransferFrom()
   
🔹 YÖNTEM 2: Marketplace'e Listing (Standart)
   • Fiyat belirleyip marketplace'e koyma
   • %2.5 platform ücreti
   • Herkes satın alabilir
   • Komut: setApprovalForAll() → Marketplace üzerinden işlem
   
🔹 YÖNTEM 3: Otomatik Fractional Sale (Otomasyonlu)
   • Smart contract ile otomatik fiyatlandırma
   • Share başına fiyat belirleme
   • Alıcı istediği kadar alabilir
   • Backend API ile yönetim

📌 ÖNERİLEN: Flutter app üzerinden veya Backend API'sinden
   yönetmek en pratik yöntemdir.
""")
    
    print("\n💡 Örnek Kullanım Senaryoları:")
    print("-"*60)
    
    for holding in holdings:
        token_id = holding['token_id']
        balance = holding['balance']
        
        print(f"\n🏠 NFT #{token_id} için öneriler:")
        
        # Scenario 1: Sell 10%
        sell_10_percent = int(balance * 0.1)
        print(f"   • %10 Satış: {sell_10_percent:,} shares")
        print(f"     Kalan: {balance - sell_10_percent:,} shares ({(balance - sell_10_percent)/holding['total']*100:.1f}%)")
        
        # Scenario 2: Sell 50%
        sell_50_percent = int(balance * 0.5)
        print(f"   • %50 Satış: {sell_50_percent:,} shares")
        print(f"     Kalan: {balance - sell_50_percent:,} shares ({(balance - sell_50_percent)/holding['total']*100:.1f}%)")
        
        # Price suggestion (example)
        suggested_price_per_share = 0.01  # 0.01 MATIC per share
        total_price_10 = sell_10_percent * suggested_price_per_share
        total_price_50 = sell_50_percent * suggested_price_per_share
        
        print(f"\n   💰 Fiyat Önerileri (örnek):")
        print(f"      Share başı: {suggested_price_per_share} MATIC")
        print(f"      %10 satış toplam: {total_price_10:.2f} MATIC (~${total_price_10*0.90:.2f})")
        print(f"      %50 satış toplam: {total_price_50:.2f} MATIC (~${total_price_50*0.90:.2f})")
    
    print(f"\n{'='*60}")
    print("🎯 Satış İçin Sonraki Adımlar:")
    print("="*60)
    print("""
1️⃣  Marketplace'e Approval Verin:
    • Marketplace'in sizin adınıza transfer yapabilmesi için
    • Komut: building_contract.functions.setApprovalForAll(marketplace_address, True)
    
2️⃣  Backend API Kullanarak Liste:
    • POST /api/v1/marketplace/list
    • Fiyat ve share miktarı belirleyin
    
3️⃣  Flutter App'ten Liste:
    • "Sell Shares" butonu
    • Kullanıcı dostu arayüz
    
4️⃣  Direkt Contract Çağrısı:
    • marketplace.functions.listShares(token_id, amount, price_per_share)
""")
    
    print("\n📱 Şimdi ne yapmak istersiniz?")
    print("   a) Marketplace approval ver (gerekli ilk adım)")
    print("   b) Backend API oluştur")
    print("   c) Test alıcısı ile işlem simülasyonu")
    print("   d) Flutter app ile entegrasyon")


if __name__ == "__main__":
    list_shares_for_sale()
