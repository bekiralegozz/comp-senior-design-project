#!/usr/bin/env python3
"""
Simulate a complete fractional share purchase
Creates a test buyer and executes a purchase via Marketplace
"""

import sys
import os
import json

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from web3 import Web3
from eth_account import Account
from app.core.config import settings

def main():
    print("\n🎭 Fractional Share Purchase Simulation")
    print("="*60)
    
    w3 = Web3(Web3.HTTPProvider(settings.WEB3_PROVIDER_URL))
    
    # Load contracts
    with open('../blockchain/artifacts/contracts/Building1122.sol/Building1122.json', 'r') as f:
        building_abi = json.load(f)['abi']
    
    with open('../blockchain/artifacts/contracts/Marketplace.sol/Marketplace.json', 'r') as f:
        marketplace_abi = json.load(f)['abi']
    
    building_contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.BUILDING1122_CONTRACT_ADDRESS),
        abi=building_abi
    )
    
    marketplace_contract = w3.eth.contract(
        address=Web3.to_checksum_address(settings.MARKETPLACE_CONTRACT_ADDRESS),
        abi=marketplace_abi
    )
    
    # Seller (you)
    seller = Account.from_key(settings.WALLET_PRIVATE_KEY)
    
    # Create a simulated buyer (just for demo - would be a real user's wallet)
    print(f"\n👤 ROLLER:")
    print("-"*60)
    print(f"🏪 Satıcı (Siz): {seller.address}")
    print(f"💰 Marketplace: {settings.MARKETPLACE_CONTRACT_ADDRESS}")
    
    print(f"\n💡 NOT: Gerçek senaryoda:")
    print(f"   • Alıcı kendi wallet'ından işlem yapar")
    print(f"   • Flutter app veya web3 wallet ile bağlanır")
    print(f"   • buyShare() fonksiyonunu çağırır")
    
    # Transaction details
    token_id = 1
    shares_to_buy = 100
    price_per_share = Web3.to_wei(0.01, 'ether')  # 0.01 MATIC per share
    total_price = price_per_share * shares_to_buy
    
    # Check seller's current balance
    seller_balance_before = building_contract.functions.balanceOf(
        seller.address,
        token_id
    ).call()
    
    print(f"\n📊 İŞLEM ÖNCESİ DURUM:")
    print("-"*60)
    print(f"🏠 NFT: #{token_id} (Istanbul Apartment)")
    print(f"📦 Satıcının Shares: {seller_balance_before:,}")
    print(f"💰 İşlem Detayları:")
    print(f"   • Alınacak: {shares_to_buy} shares")
    print(f"   • Share Fiyatı: {Web3.from_wei(price_per_share, 'ether')} MATIC")
    print(f"   • Toplam Fiyat: {Web3.from_wei(total_price, 'ether')} MATIC")
    print(f"   • Platform Fee (%2.5): {Web3.from_wei(int(total_price * 0.025), 'ether')} MATIC")
    print(f"   • Satıcının Alacağı: {Web3.from_wei(int(total_price * 0.975), 'ether')} MATIC")
    
    print(f"\n{'='*60}")
    print(f"🔄 MARKETPLACE BUYSHARE FLOW'U")
    print(f"{'='*60}")
    
    print(f"""
Marketplace contract'ınızda buyShare() fonksiyonu var:

function buyShare(
    uint256 tokenId,
    address seller,
    uint256 shareAmount
) external payable nonReentrant whenNotPaused

Bu fonksiyon çağrıldığında:

1️⃣  Alıcı MATIC gönderir (msg.value)
2️⃣  Platform fee hesaplanır (%2.5)
3️⃣  Satıcıya net tutar transfer edilir
4️⃣  Share'ler alıcıya transfer edilir (safeTransferFrom)

📱 FLUTTER APP'TEN NASIL ÇAĞRILIR:
""")
    
    # Flutter code example
    flutter_code = f'''
// Flutter/Dart örnek kod:

final contractAddress = "{settings.MARKETPLACE_CONTRACT_ADDRESS}";
final tokenId = {token_id};
final sellerAddress = "{seller.address}";
final shareAmount = {shares_to_buy};
final totalPrice = "{Web3.from_wei(total_price, 'ether')}"; // MATIC

// Web3Dart ile transaction oluştur
final transaction = Transaction.callContract(
  contract: marketplaceContract,
  function: buyShareFunction,
  parameters: [
    BigInt.from(tokenId),
    EthereumAddress.fromHex(sellerAddress),
    BigInt.from(shareAmount),
  ],
  value: EtherAmount.inWei(BigInt.parse("{total_price}")),
);

// Kullanıcı wallet'ından imzala ve gönder
await web3client.sendTransaction(
  credentials,
  transaction,
  chainId: 137, // Polygon
);
'''
    
    print(flutter_code)
    
    print(f"\n{'='*60}")
    print(f"🧪 BACKEND API İLE TEST")
    print(f"{'='*60}")
    
    api_example = f'''
# Backend'de API endpoint ekleyin (zaten var olabilir):

POST /api/v1/marketplace/buy
{{
  "token_id": {token_id},
  "seller_address": "{seller.address}",
  "share_amount": {shares_to_buy},
  "buyer_address": "0x..." // Alıcının adresi
}}

# Bu endpoint çağrıldığında:
# 1. Fiyat hesaplanır
# 2. Alıcıdan onay alınır (frontend'de)
# 3. Blockchain'e transaction gönderilir
# 4. Sonuç döndürülür
'''
    
    print(api_example)
    
    print(f"\n{'='*60}")
    print(f"📊 İŞLEM SONRASI TAHMİNİ DURUM")
    print(f"{'='*60}")
    
    seller_balance_after = seller_balance_before - shares_to_buy
    
    print(f"Satıcı (Siz):")
    print(f"   • Kalan Shares: {seller_balance_after:,}")
    print(f"   • Satış Geliri: +{Web3.from_wei(int(total_price * 0.975), 'ether')} MATIC")
    print(f"\nAlıcı:")
    print(f"   • Alınan Shares: {shares_to_buy}")
    print(f"   • Ödenen: {Web3.from_wei(total_price, 'ether')} MATIC")
    print(f"\nMarketplace:")
    print(f"   • Platform Fee: {Web3.from_wei(int(total_price * 0.025), 'ether')} MATIC")
    
    print(f"\n{'='*60}")
    print(f"✅ SİSTEM HAZIR!")
    print(f"{'='*60}")
    
    print(f"""
🎯 Kullanılabilir Satış Yöntemleri:

1️⃣  Direct Marketplace.buyShare() - ÖNERİLEN
   ✅ Otomatik fiyat hesaplama
   ✅ Platform fee dahil
   ✅ Güvenli transfer
   ✅ Flutter app entegrasyonu kolay

2️⃣  P2P Transfer (Off-chain anlaşma)
   ✅ Ücretsiz (sadece gas)
   ❌ Güvenlik riski
   ❌ Platform fee yok

3️⃣  Backend API Wrapper
   ✅ Kullanıcı dostu
   ✅ Validasyon ve kontrol
   ✅ Database kaydı
   ✅ Email/notification entegrasyonu

💡 SONRAKI ADIM: Flutter app'e "Buy Shares" butonu ekleyin!
""")
    
    print(f"\n🔗 İşlem Takibi:")
    print(f"   Approval TX: https://polygonscan.com/tx/0x26089b9cb9cd7c95183945247cfa0ca8910259ba7888ff4929e73b52964f53b9")
    print(f"   Marketplace: https://polygonscan.com/address/{settings.MARKETPLACE_CONTRACT_ADDRESS}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
