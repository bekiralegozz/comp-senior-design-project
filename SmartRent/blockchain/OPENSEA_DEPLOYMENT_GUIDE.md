# 🎨 OpenSea NFT Marketplace - Tam Entegrasyon Rehberi

## 📦 ADIM 2: Hardhat Kurulumu ve Yapılandırma

### 2.1. Package.json Oluştur
```bash
cd SmartRent/blockchain
npm init -y
```

### 2.2. Gerekli Paketleri Yükle
```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npm install @openzeppelin/contracts dotenv
npm install --save-dev @nomiclabs/hardhat-ethers ethers
```

### 2.3. Hardhat'i Başlat
```bash
npx hardhat
# "Create a JavaScript project" seç
# Tüm sorulara "yes" de
```

### 2.4. hardhat.config.js Düzenle
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137,
      gasPrice: 35000000000 // 35 gwei
    },
    polygonMumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 80001
    }
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY
    }
  }
};
```

### 2.5. .env Dosyası Oluştur (blockchain klasöründe)
```env
PRIVATE_KEY=your_metamask_private_key_here
POLYGON_RPC_URL=https://polygon-rpc.com
POLYGONSCAN_API_KEY=your_polygonscan_api_key
PINATA_API_KEY=your_pinata_api_key
PINATA_SECRET_KEY=your_pinata_secret_key
```

**⚠️ ÖNEMLİ:** Private key'inizi ASLA git'e commit etmeyin!

---

## 🚀 ADIM 3: Smart Contract Deployment

### 3.1. Deployment Script Oluştur
```bash
# scripts/deploy.js dosyası oluştur
```

### 3.2. deploy.js İçeriği
```javascript
const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting deployment to Polygon Mainnet...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  
  const balance = await deployer.getBalance();
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "MATIC\n");

  // Check minimum balance (1 MATIC recommended)
  if (balance.lt(ethers.utils.parseEther("1"))) {
    console.warn("⚠️  Warning: Low balance. Recommended at least 1 MATIC for deployment");
  }

  // Deploy Building1122 (Main NFT Contract)
  console.log("📦 Deploying Building1122 contract...");
  const Building1122 = await hre.ethers.getContractFactory("Building1122");
  
  // Base URI will be updated later with IPFS
  const building1122 = await Building1122.deploy("https://ipfs.io/ipfs/");
  await building1122.deployed();
  
  console.log("✅ Building1122 deployed to:", building1122.address);
  console.log("   Transaction hash:", building1122.deployTransaction.hash);
  console.log("   Block number:", building1122.deployTransaction.blockNumber, "\n");

  // Wait for a few block confirmations
  console.log("⏳ Waiting for 5 block confirmations...");
  await building1122.deployTransaction.wait(5);
  console.log("✅ Confirmed!\n");

  // Deploy Marketplace
  console.log("📦 Deploying Marketplace contract...");
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    building1122.address,
    deployer.address // Fee recipient
  );
  await marketplace.deployed();
  
  console.log("✅ Marketplace deployed to:", marketplace.address);
  console.log("   Transaction hash:", marketplace.deployTransaction.hash, "\n");
  
  await marketplace.deployTransaction.wait(5);

  // Deploy RentalManager
  console.log("📦 Deploying RentalManager contract...");
  const RentalManager = await hre.ethers.getContractFactory("RentalManager");
  const rentalManager = await RentalManager.deploy(building1122.address);
  await rentalManager.deployed();
  
  console.log("✅ RentalManager deployed to:", rentalManager.address);
  console.log("   Transaction hash:", rentalManager.deployTransaction.hash, "\n");
  
  await rentalManager.deployTransaction.wait(5);

  // Summary
  console.log("🎉 Deployment Complete!\n");
  console.log("📋 Contract Addresses:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("Building1122:  ", building1122.address);
  console.log("Marketplace:   ", marketplace.address);
  console.log("RentalManager: ", rentalManager.address);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("📝 Next Steps:");
  console.log("1. Save these addresses to your .env file");
  console.log("2. Verify contracts on PolygonScan");
  console.log("3. Set up IPFS metadata");
  console.log("4. Configure OpenSea collection\n");

  // Verification commands
  console.log("🔍 Verify on PolygonScan:");
  console.log(`npx hardhat verify --network polygon ${building1122.address} "https://ipfs.io/ipfs/"`);
  console.log(`npx hardhat verify --network polygon ${marketplace.address} ${building1122.address} ${deployer.address}`);
  console.log(`npx hardhat verify --network polygon ${rentalManager.address} ${building1122.address}\n`);

  // OpenSea links
  console.log("🌐 OpenSea Collection URL (after metadata setup):");
  console.log(`https://opensea.io/assets/matic/${building1122.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
```

### 3.3. Deploy Komutu
```bash
# Önce balance kontrol et
npx hardhat run scripts/check-balance.js --network polygon

# Deploy et
npx hardhat run scripts/deploy.js --network polygon
```

---

## 🖼️ ADIM 4: IPFS Metadata Hazırlama (Pinata)

### 4.1. Pinata Hesabı
1. https://pinata.cloud/ → Sign Up (ücretsiz)
2. Dashboard → API Keys → New Key
3. API Key ve Secret Key'i kaydet

### 4.2. Metadata JSON Formatı (OpenSea Standardı)
```json
{
  "name": "Luxury Apartment #101",
  "description": "A beautiful 2-bedroom apartment in downtown with fractional ownership opportunities.",
  "image": "ipfs://QmYourImageHash",
  "external_url": "https://smartrent.com/assets/101",
  "attributes": [
    {
      "trait_type": "Property Type",
      "value": "Apartment"
    },
    {
      "trait_type": "Bedrooms",
      "value": "2"
    },
    {
      "trait_type": "Location",
      "value": "Downtown"
    },
    {
      "trait_type": "Total Shares",
      "value": 1000
    },
    {
      "trait_type": "Square Feet",
      "value": "1200"
    },
    {
      "display_type": "date",
      "trait_type": "Built Year",
      "value": 1672531200
    }
  ],
  "properties": {
    "address": "123 Main St, City, Country",
    "rental_yield": "5.5%",
    "estimated_value": "$250,000"
  }
}
```

### 4.3. Metadata Upload Script
```javascript
// scripts/upload-metadata.js
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
require('dotenv').config();

const PINATA_API_KEY = process.env.PINATA_API_KEY;
const PINATA_SECRET = process.env.PINATA_SECRET_KEY;

async function uploadImageToPinata(imagePath) {
  const url = 'https://api.pinata.cloud/pinning/pinFileToIPFS';
  
  let data = new FormData();
  data.append('file', fs.createReadStream(imagePath));

  const response = await axios.post(url, data, {
    headers: {
      'pinata_api_key': PINATA_API_KEY,
      'pinata_secret_api_key': PINATA_SECRET,
      ...data.getHeaders()
    }
  });

  return response.data.IpfsHash;
}

async function uploadMetadataToPinata(metadata) {
  const url = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
  
  const response = await axios.post(url, metadata, {
    headers: {
      'pinata_api_key': PINATA_API_KEY,
      'pinata_secret_api_key': PINATA_SECRET,
      'Content-Type': 'application/json'
    }
  });

  return response.data.IpfsHash;
}

async function main() {
  console.log("📤 Uploading to IPFS via Pinata...\n");

  // 1. Upload image
  console.log("🖼️  Uploading image...");
  const imageHash = await uploadImageToPinata('./assets/apartment-101.jpg');
  console.log("✅ Image uploaded:", `ipfs://${imageHash}\n`);

  // 2. Create metadata
  const metadata = {
    name: "Luxury Apartment #101",
    description: "A beautiful 2-bedroom apartment in downtown with fractional ownership opportunities.",
    image: `ipfs://${imageHash}`,
    external_url: "https://smartrent.com/assets/101",
    attributes: [
      { trait_type: "Property Type", value: "Apartment" },
      { trait_type: "Bedrooms", value: "2" },
      { trait_type: "Location", value: "Downtown" },
      { trait_type: "Total Shares", value: 1000 }
    ]
  };

  // 3. Upload metadata
  console.log("📝 Uploading metadata...");
  const metadataHash = await uploadMetadataToPinata(metadata);
  console.log("✅ Metadata uploaded:", `ipfs://${metadataHash}\n`);

  console.log("🎉 Upload Complete!");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("Metadata URI:", `ipfs://${metadataHash}`);
  console.log("OpenSea URL:  ", `https://gateway.pinata.cloud/ipfs/${metadataHash}`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  
  console.log("📋 Use this URI when minting NFT in your smart contract");
}

main().catch(console.error);
```

---

## 🌊 ADIM 5: OpenSea'de Collection Oluşturma

### 5.1. OpenSea'ya Bağlan
1. https://opensea.io/ → Connect Wallet
2. MetaMask ile bağlan (Polygon network'te ol)

### 5.2. Collection Oluştur (İlk NFT mint'ten sonra otomatik)
```
Contract deploy edildikten sonra:
1. OpenSea → Profile → More → Settings
2. "My Collections" → Yeni collection otomatik görünecek
3. Collection'ı düzenle:
   - Logo image (350x350 px)
   - Featured image (600x400 px)
   - Banner image (1400x350 px)
   - Description
   - Category: Art / Collectibles
   - Blockchain: Polygon
   - Royalty: 2.5% (contract'ta ayarladığımız)
```

### 5.3. Collection Metadata (İsteğe Bağlı)
OpenSea contract-level metadata için:

```json
{
  "name": "SmartRent Real Estate",
  "description": "Fractional ownership NFTs for real estate properties",
  "image": "ipfs://QmYourCollectionLogoHash",
  "external_link": "https://smartrent.com",
  "seller_fee_basis_points": 250,
  "fee_recipient": "0xYourWalletAddress"
}
```

Bu dosyayı IPFS'e yükle ve contract'ta `setURI()` ile ayarla.

---

## 🎯 ADIM 6: İlk NFT'yi Mint Et

### 6.1. Hardhat Console'dan Mint
```bash
npx hardhat console --network polygon
```

```javascript
const Building1122 = await ethers.getContractFactory("Building1122");
const contract = await Building1122.attach("YOUR_CONTRACT_ADDRESS");

// Metadata URI (Pinata'dan aldığın)
const metadataURI = "ipfs://QmYourMetadataHash";

// Mint initial supply
const tx = await contract.mintInitialSupply(
  1,                          // tokenId
  "0xYourWalletAddress",      // initial owner
  1000,                       // total shares
  metadataURI                 // metadata URI
);

await tx.wait();
console.log("✅ NFT Minted! Transaction:", tx.hash);
```

### 6.2. Backend'den Mint (Python)
```python
from web3 import Web3
import json

w3 = Web3(Web3.HTTPProvider('https://polygon-rpc.com'))

# Contract setup
contract_address = "YOUR_CONTRACT_ADDRESS"
with open('contracts/artifacts/Building1122.json') as f:
    abi = json.load(f)['abi']

contract = w3.eth.contract(address=contract_address, abi=abi)

# Mint NFT
tx = contract.functions.mintInitialSupply(
    1,                              # tokenId
    "0xOwnerAddress",               # owner
    1000,                           # total shares
    "ipfs://QmMetadataHash"         # metadata URI
).build_transaction({
    'from': deployer_address,
    'nonce': w3.eth.get_transaction_count(deployer_address),
    'gas': 500000,
    'gasPrice': w3.eth.gas_price
})

signed_tx = w3.eth.account.sign_transaction(tx, private_key)
tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

print(f"✅ NFT Minted! Token ID: 1")
```

---

## 🔍 ADIM 7: OpenSea'de Görüntüleme

### 7.1. NFT URL'i
```
https://opensea.io/assets/matic/{CONTRACT_ADDRESS}/{TOKEN_ID}

Örnek:
https://opensea.io/assets/matic/0x1234...5678/1
```

### 7.2. İlk Görünme Süresi
- **Mainnet:** 5-30 dakika
- **Testnet:** Hemen

### 7.3. Metadata Refresh (Gerekirse)
```
OpenSea → Your NFT → More (⋯) → Refresh metadata
```

---

## 📊 ADIM 8: Fractional Shares'i OpenSea'de Satma

### 8.1. Liste Oluştur
```javascript
// Frontend'den veya script ile
const tx = await marketplace.listShares(
  1,                    // tokenId
  100,                  // amount of shares to sell
  ethers.utils.parseEther("0.1")  // price per share in MATIC
);
```

### 8.2. OpenSea'de Görüntüleme
- Shares ERC-1155 olarak görünür
- Her share ayrı ayrı satılabilir
- "Quantity" field ile multiple shares

---

## 🔐 GÜVENLİK KONTROL LİSTESİ

```
✅ Private key'i asla commit etme
✅ .env dosyasını .gitignore'a ekle
✅ Contract'ı PolygonScan'de verify et
✅ Royalty receiver address'i kontrol et
✅ Ownership transferi test et
✅ Pause/Unpause fonksiyonlarını test et
✅ Metadata URI'ları HTTPS veya IPFS olmalı
✅ İlk mint'i testnet'te dene
```

---

## 🛠️ TROUBLESHOOTING

### Problem: OpenSea'de NFT görünmüyor
```
Çözüm:
1. 5-10 dakika bekle
2. Metadata refresh yap
3. Contract verify edilmiş mi kontrol et
4. Metadata URI çalışıyor mu test et (Pinata gateway)
```

### Problem: "Insufficient funds" hatası
```
Çözüm:
1. Wallet'ta yeterli MATIC var mı?
2. Gas price çok yüksek mi? (hardhat.config.js'te düşür)
3. Polygon network'te misin? (Mumbai değil!)
```

### Problem: Metadata yanlış görünüyor
```
Çözüm:
1. JSON formatını kontrol et (https://jsonlint.com)
2. Image URI'ı doğru mu? (ipfs:// veya https://)
3. OpenSea'de metadata refresh yap
```

---

## 📱 DIŞ SERVİSLER ÖZET

### 1. **MetaMask**
- Kurulum: https://metamask.io
- Polygon ekle
- MATIC al ve yükle

### 2. **Pinata (IPFS)**
- Ücretsiz hesap: https://pinata.cloud
- API key al
- Image + metadata upload

### 3. **PolygonScan**
- API key: https://polygonscan.com/apis
- Contract verification için gerekli

### 4. **OpenSea**
- Wallet bağla
- Collection otomatik oluşur
- Customize et

### 5. **Infura/Alchemy (Opsiyonel)**
- Daha güvenilir RPC endpoint
- Rate limit yüksek
- https://infura.io veya https://alchemy.com

---

## ✅ DEPLOYMENT CHECKLİST

```
□ MetaMask kuruldu ve Polygon eklendi
□ MATIC alındı (en az 5-10$)
□ Pinata hesabı oluşturuldu, API key alındı
□ Hardhat kuruldu ve yapılandırıldı
□ .env dosyası oluşturuldu (private key, API keys)
□ Contract'lar OpenSea standardına uygun
□ Deployment script hazır
□ Image ve metadata IPFS'e yüklendi
□ Contract deploy edildi (Polygon Mainnet)
□ Contract verify edildi (PolygonScan)
□ İlk NFT mint edildi
□ OpenSea'de collection görünüyor
□ Metadata doğru görünüyor
□ Fractional shares test edildi
```

---

## 🎉 BAŞARI!

Tebrikler! Artık Polygon Mainnet'te OpenSea entegreli NFT projeniz var!

**Sonraki Adımlar:**
- Backend API'yi Web3 ile entegre et
- Flutter app'e wallet connect ekle
- Marketplace fonksiyonlarını test et
- Marketing ve community building başlat

---

**Yardım için:**
- OpenSea Discord: https://discord.gg/opensea
- Polygon Discord: https://discord.gg/polygon
- Hardhat Docs: https://hardhat.org/docs
