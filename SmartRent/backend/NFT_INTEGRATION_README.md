# 🎨 NFT & Fractional Ownership Backend Integration

Backend'de Polygon Mainnet + OpenSea entegrasyonu tamamlandı!

## ✅ Tamamlanan İşlemler

### 1. Smart Contract Güncellemeleri
- ✅ `Building1122.sol` - OpenSea standardına uygun (ERC-2981 royalty)
- ✅ `Marketplace.sol` - Import güncellemesi
- ✅ `RentalManager.sol` - Import güncellemesi

### 2. Backend Services
- ✅ `web3_service.py` - Blockchain interaction
- ✅ `ipfs_service.py` - IPFS metadata ve image upload
- ✅ `nft.py` - NFT API endpoints

### 3. API Endpoints

#### NFT Management
```
GET  /api/v1/nft/status              - Blockchain status
POST /api/v1/nft/mint                - Mint new fractional NFT
GET  /api/v1/nft/asset/{token_id}    - Get asset info
GET  /api/v1/nft/ownership/{token_id}/{address} - Get ownership details
POST /api/v1/nft/buy-shares          - Purchase shares
POST /api/v1/nft/distribute-rent     - Distribute rent to owners
GET  /api/v1/nft/transaction/{tx_hash} - Get transaction details
GET  /api/v1/nft/ipfs/test           - Test IPFS connection
```

## 🚀 Hızlı Başlangıç

### 1. Environment Variables (.env)
```env
# Polygon Mainnet
WEB3_PROVIDER_URL=https://polygon-rpc.com
POLYGON_CHAIN_ID=137
WALLET_PRIVATE_KEY=your_64_char_hex_private_key
CONTRACT_OWNER_ADDRESS=0xYourAddress

# Contracts (after deployment)
BUILDING1122_CONTRACT_ADDRESS=0x...
MARKETPLACE_CONTRACT_ADDRESS=0x...
RENTAL_MANAGER_CONTRACT_ADDRESS=0x...

# Pinata IPFS
PINATA_API_KEY=your_key
PINATA_SECRET_KEY=your_secret
```

### 2. Test Sistemi
```bash
cd SmartRent/backend
python3 scripts/test_nft_system.py
```

### 3. Deploy Contracts
```bash
cd ../blockchain
npm install
npx hardhat run scripts/deploy.js --network polygon
```

### 4. Backend Başlat
```bash
cd SmartRent/backend
python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 📡 API Kullanım Örnekleri

### Mint NFT
```bash
curl -X POST http://localhost:8000/api/v1/nft/mint \
  -H "Content-Type: application/json" \
  -d '{
    "token_id": 1,
    "owner_address": "0xYourAddress",
    "total_shares": 1000,
    "asset_name": "Luxury Apartment #101",
    "description": "Beautiful 2-bedroom apartment",
    "image_url": "https://example.com/apartment.jpg",
    "property_type": "Apartment",
    "bedrooms": 2,
    "location": "Downtown",
    "square_feet": 1200
  }'
```

### Get Asset Info
```bash
curl http://localhost:8000/api/v1/nft/asset/1
```

### Get Ownership
```bash
curl http://localhost:8000/api/v1/nft/ownership/1/0xYourAddress
```

### Buy Shares
```bash
curl -X POST http://localhost:8000/api/v1/nft/buy-shares \
  -H "Content-Type: application/json" \
  -d '{
    "token_id": 1,
    "seller_address": "0xSellerAddress",
    "share_amount": 100,
    "price_in_matic": 10.5
  }'
```

## 🏗️ Mimari

```
┌─────────────────┐
│  Flutter App    │
└────────┬────────┘
         │ REST API
         ▼
┌─────────────────┐
│  FastAPI        │
│  Backend        │
├─────────────────┤
│ web3_service.py │──────► Polygon Mainnet
│ ipfs_service.py │──────► Pinata IPFS
└─────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Smart Contracts            │
├─────────────────────────────┤
│  Building1122 (ERC-1155)    │
│  Marketplace                │
│  RentalManager              │
└─────────────────────────────┘
         │
         ▼
    OpenSea Marketplace
```

## 📋 İş Akışı: NFT Mint

1. **Backend API'ye Request**
   ```
   POST /api/v1/nft/mint
   ```

2. **IPFS'e Image Upload**
   ```python
   ipfs_service.upload_image_from_url(image_url)
   # Returns: ipfs://QmImageHash
   ```

3. **IPFS'e Metadata Upload**
   ```python
   ipfs_service.upload_json_metadata(
       name, description, image_uri, attributes
   )
   # Returns: ipfs://QmMetadataHash
   ```

4. **Blockchain'de NFT Mint**
   ```python
   web3_service.mint_asset_nft(
       token_id, owner, shares, metadata_uri
   )
   # Returns: transaction_hash
   ```

5. **OpenSea'de Görünür**
   ```
   https://opensea.io/assets/matic/{contract}/{token_id}
   ```

## 🔧 Troubleshooting

### Web3 Bağlantı Hatası
```bash
# Test et
curl https://polygon-rpc.com \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}'
```

### IPFS Upload Hatası
```bash
# Pinata credentials test
curl -X GET https://api.pinata.cloud/data/testAuthentication \
  -H "pinata_api_key: YOUR_KEY" \
  -H "pinata_secret_api_key: YOUR_SECRET"
```

### Contract ABI Yok Hatası
```bash
# Contracts compile et
cd blockchain
npx hardhat compile
```

## 📚 Daha Fazla Bilgi

- **OpenSea Deployment Guide:** `../blockchain/OPENSEA_DEPLOYMENT_GUIDE.md`
- **API Docs:** http://localhost:8000/docs
- **Contract Source:** `../blockchain/contracts/`

## 🎯 Sonraki Adımlar

1. ✅ **Backend Entegrasyonu** - Tamamlandı
2. ⏭️ **Contract Deployment** - Hardhat ile deploy
3. ⏭️ **Flutter Integration** - Mobile app'e Web3 ekle
4. ⏭️ **OpenSea Configuration** - Collection customize
5. ⏭️ **Testing** - End-to-end test

## 💡 Notlar

- **Gas Fees:** Polygon mainnet'te ~$0.01-0.05 per transaction
- **IPFS Storage:** Pinata'da ilk 1GB ücretsiz
- **OpenSea:** Collection otomatik oluşur, 5-10 dakika bekle
- **Royalties:** %2.5 default olarak ayarlandı (değiştirilebilir)

---

**Son Güncelleme:** 15 Aralık 2025
**Version:** 1.0.0
