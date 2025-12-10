# SmartRent Decentralized Architecture Migration Plan

## 🎯 Hedef: Tam Decentralized Mimari

**Ana Prensip:** Blockchain ana veri kaynağı, Database sadece cache/index

---

## 📊 Yeni Mimari Diyagramı

```
┌─────────────┐
│ Mobile App  │
│  (Flutter)  │
└─────────────┘
       │
       │ Wallet (MetaMask/Trust Wallet/WalletConnect)
       │ Transaction Sign & Send (Kullanıcı kendi wallet'ı ile)
       ▼
┌──────────────┐
│   Sepolia    │ ← ANA VERİ KAYNAĞI (Blockchain)
│  Testnet     │
└──────────────┘
       │
       │ Event'ler (RentPaid, ShareTraded, AssetInitialized)
       ▼
┌──────────────┐         ┌─────────────┐
│ Blockchain   │ ──────> │  Supabase   │
│   Server     │  Sync   │  (Cache)    │ ← Sadece cache/index
│(Event Only)  │         └─────────────┘
└──────────────┘
       ▲
       │ Read-Only (Blockchain'den veri okur)
       │
┌──────────────┐
│   Backend    │
│  (FastAPI)   │ ← Sadece Read-Only API
│ Read-Only    │
└──────────────┘
```

---

## 🔄 Akış Karşılaştırması

### ❌ Eski (Centralized) Akış: Rent Ödeme

1. Mobile App → `POST /api/v1/rent/pay` → Backend
2. Backend → `chain_actions` tablosuna yazar (`PENDING`)
3. Backend → Response döner
4. Blockchain Server → `chain_actions`'ı poll eder
5. Blockchain Server → Transaction gönderir (hot wallet ile)
6. Blockchain → Transaction onaylanır
7. Blockchain Server → Event dinler, database'i günceller

**Sorunlar:**
- Merkezi kontrol noktası (`chain_actions`)
- Kullanıcı kendi wallet'ını kullanmıyor
- Backend transaction başlatıyor
- Blockchain Server hot wallet kullanıyor

### ✅ Yeni (Decentralized) Akış: Rent Ödeme

1. Mobile App → Kullanıcı rent ödemek ister
2. Mobile App → Wallet'ı açar (MetaMask/Trust Wallet)
3. Mobile App → `RentalManager.payRent()` transaction'ını hazırlar
4. Kullanıcı → Wallet'ta transaction'ı onaylar
5. Mobile App → Transaction'ı Sepolia'ya gönderir (kullanıcı wallet'ı ile)
6. Blockchain → Transaction onaylanır, `RentPaid` event emit edilir
7. Blockchain Server → Event'i dinler, database'i sync eder (cache)
8. Backend → Database'den güncel veriyi okur, API'ye sunar

**Avantajlar:**
- Kullanıcı kendi wallet'ını kullanıyor
- Blockchain ana veri kaynağı
- Merkezi kontrol noktası yok
- Tamamen decentralized

---

## 📋 Migration Adımları

### Faz 1: Setup ve Hazırlık

#### 1.1 Mobile App Dependencies
- [ ] `web3dart` paketini ekle (Flutter için Ethereum client)
- [ ] `walletconnect_flutter_v2` paketini ekle (WalletConnect desteği)
- [ ] `web3modal_flutter` paketini ekle (opsiyonel, UI için)

**pubspec.yaml:**
```yaml
dependencies:
  web3dart: ^3.1.5
  walletconnect_flutter_v2: ^2.1.12
  # web3modal_flutter: ^1.0.0  # Opsiyonel
```

#### 1.2 RPC Provider Setup
- [ ] Alchemy/Infura RPC URL'i mobile app'e ekle
- [ ] Sepolia network config oluştur
- [ ] Contract address'lerini mobile app'e ekle

**Gerekli:**
- Sepolia RPC URL (Alchemy'den alınmış)
- Contract addresses (zaten var)

#### 1.3 Contract ABI'lerini Mobile App'e Ekle
- [ ] `Building1122.json` → Mobile app'e kopyala
- [ ] `RentalManager.json` → Mobile app'e kopyala
- [ ] `Marketplace.json` → Mobile app'e kopyala

**Yapı:**
```
SmartRent/mobile/lib/contracts/
├── Building1122.json
├── RentalManager.json
└── Marketplace.json
```

---

### Faz 2: Mobile App - Wallet Entegrasyonu

#### 2.1 Wallet Service Oluştur
- [ ] `WalletService` class'ı oluştur
- [ ] MetaMask/Trust Wallet bağlantısı
- [ ] WalletConnect desteği
- [ ] Transaction sign etme
- [ ] Balance sorgulama

**Dosya:** `SmartRent/mobile/lib/services/wallet_service.dart`

**Fonksiyonlar:**
- `connectWallet()` - Wallet bağla
- `disconnectWallet()` - Wallet bağlantısını kes
- `getAddress()` - Bağlı wallet address'i
- `getBalance()` - Wallet balance (ETH)
- `signTransaction()` - Transaction sign et
- `sendTransaction()` - Transaction gönder

#### 2.2 Blockchain Service Oluştur
- [ ] `BlockchainService` class'ı oluştur
- [ ] Contract instance'ları oluştur
- [ ] Contract fonksiyonlarını çağırma

**Dosya:** `SmartRent/mobile/lib/services/blockchain_service.dart`

**Fonksiyonlar:**
- `mintAsset()` - Asset mint etme
- `payRent()` - Rent ödeme
- `buyShare()` - Pay satın alma
- `getBalance()` - Token balance sorgulama
- `getOwnershipPercentage()` - Ownership yüzdesi

#### 2.3 UI Güncellemeleri
- [ ] Wallet connect ekranı güncelle
- [ ] Transaction onaylama dialog'u ekle
- [ ] Transaction status gösterimi
- [ ] Error handling UI

---

### Faz 3: Backend - Read-Only Dönüşümü

#### 3.1 Transaction Endpoint'lerini Kaldır
- [ ] `POST /api/v1/assets/create` → Kaldır veya deprecated yap
- [ ] `POST /api/v1/rent/pay` → Kaldır veya deprecated yap
- [ ] `POST /api/v1/marketplace/buy-share` → Kaldır veya deprecated yap

#### 3.2 Read-Only Endpoint'leri Güncelle
- [ ] `GET /api/v1/assets/` → Blockchain'den veri okur (cache'den)
- [ ] `GET /api/v1/assets/{id}` → Blockchain'den asset detayları
- [ ] `GET /api/v1/rentals/` → Blockchain event'lerinden rental listesi
- [ ] `GET /api/v1/ownerships/{assetId}` → Blockchain'den ownership bilgileri

#### 3.3 Blockchain Reader Service
- [ ] `BlockchainReaderService` oluştur
- [ ] RPC üzerinden blockchain'den veri okuma
- [ ] Contract view fonksiyonlarını çağırma

**Dosya:** `SmartRent/backend/app/services/blockchain_reader.py`

**Fonksiyonlar:**
- `getAsset(tokenId)` - Asset bilgileri
- `getOwnership(assetId, owner)` - Ownership bilgileri
- `getRentPayments(assetId)` - Rent payment listesi
- `getTotalRentCollected(assetId)` - Toplam rent

---

### Faz 4: Blockchain Server - Event Only

#### 4.1 Action Worker'ı Kaldır
- [ ] `actionWorker.js` dosyasını kaldır veya devre dışı bırak
- [ ] `chain_actions` polling'i kaldır
- [ ] Transaction gönderme kodlarını kaldır

#### 4.2 Event Worker'ı Güncelle
- [ ] Sadece event listener olarak çalışsın
- [ ] Database sync mekanizması
- [ ] Blockchain'den veri okuma (initial sync için)

#### 4.3 Database Sync Mekanizması
- [ ] Blockchain'den initial data sync
- [ ] Event'lerden incremental sync
- [ ] Conflict resolution (blockchain öncelikli)

---

### Faz 5: Database - Cache/Index Yapısı

#### 5.1 Tabloları Güncelle
- [ ] `chain_actions` tablosunu kaldır (artık gerekli değil)
- [ ] `assets` tablosu → Blockchain'den sync edilir
- [ ] `ownerships` tablosu → Blockchain'den sync edilir
- [ ] `rentals` tablosu → Blockchain event'lerinden sync edilir

#### 5.2 Sync Mekanizması
- [ ] Initial sync script (blockchain'den tüm veriyi çek)
- [ ] Event-based sync (yeni event'ler geldikçe)
- [ ] Periodic sync (opsiyonel, güvenlik için)

---

## 🔧 Setup Gereksinimleri

### 1. Mobile App Dependencies

**pubspec.yaml'a eklenecek:**
```yaml
dependencies:
  web3dart: ^3.1.5                    # Ethereum client
  walletconnect_flutter_v2: ^2.1.12  # WalletConnect
  http: ^1.1.0                        # HTTP client (zaten var)
```

**Kurulum:**
```bash
cd SmartRent/mobile
flutter pub get
```

### 2. RPC Provider

**Gerekli:**
- Alchemy/Infura Sepolia RPC URL (zaten var)
- Contract addresses (zaten var)
- ABI dosyaları (zaten var, mobile app'e kopyalanacak)

**Config:**
```dart
// lib/constants/blockchain_config.dart
class BlockchainConfig {
  static const String sepoliaRpcUrl = 'https://eth-sepolia.g.alchemy.com/v2/...';
  static const String building1122Address = '0xeFbfFC198FfA373C26E64a426E8866B132d08ACB';
  static const String rentalManagerAddress = '0x57044386A0C5Fb623315Dd5b8eeEA6078Bb9193C';
  static const String marketplaceAddress = '0x2fFCd104D50c99D24d76Acfc3Ef1dfb550127A1f';
  static const int chainId = 11155111; // Sepolia
}
```

### 3. Backend - Blockchain Reader

**Gerekli:**
- `web3.py` veya `eth-account` paketleri
- RPC URL (zaten var)
- Contract addresses (zaten var)
- ABI dosyaları (backend'e kopyalanacak)

**Kurulum:**
```bash
cd SmartRent/backend
pip install web3 eth-account
```

### 4. Blockchain Server - Güncelleme

**Değişiklikler:**
- Action Worker kaldırılacak
- Sadece Event Worker kalacak
- Database sync mekanizması eklenecek

**Gerekli:**
- Zaten kurulu (ethers.js, Supabase client)

---

## 📝 Detaylı Implementation Plan

### Adım 1: Mobile App - Wallet Service

**Dosya:** `SmartRent/mobile/lib/services/wallet_service.dart`

**Özellikler:**
- MetaMask/Trust Wallet bağlantısı
- WalletConnect desteği
- Transaction sign & send
- Balance sorgulama
- Network kontrolü (Sepolia)

**Kullanım:**
```dart
final walletService = WalletService();
await walletService.connectWallet();
final address = walletService.getAddress();
final balance = await walletService.getBalance();
```

### Adım 2: Mobile App - Blockchain Service

**Dosya:** `SmartRent/mobile/lib/services/blockchain_service.dart`

**Özellikler:**
- Contract instance'ları
- Transaction hazırlama
- Gas estimation
- Transaction gönderme
- View fonksiyonları (read-only)

**Kullanım:**
```dart
final blockchainService = BlockchainService();
await blockchainService.payRent(
  assetId: 1,
  amount: '0.1',
  owners: ['0xABC...', '0xDEF...'],
);
```

### Adım 3: Backend - Blockchain Reader

**Dosya:** `SmartRent/backend/app/services/blockchain_reader.py`

**Özellikler:**
- RPC connection
- Contract instance'ları
- View fonksiyonları
- Event filtering
- Data parsing

**Kullanım:**
```python
from app.services.blockchain_reader import BlockchainReader

reader = BlockchainReader()
asset = await reader.get_asset(token_id=1)
ownership = await reader.get_ownership(asset_id=1, owner='0xABC...')
```

### Adım 4: Blockchain Server - Event Only

**Değişiklikler:**
- `src/index.js` → Action Worker'ı kaldır
- `src/workers/actionWorker.js` → Kaldır veya devre dışı bırak
- `src/workers/eventWorker.js` → Sadece event listener

**Yeni Dosya:** `src/services/syncService.js`
- Initial sync (blockchain'den tüm veriyi çek)
- Event-based sync
- Conflict resolution

---

## ⚠️ Önemli Notlar

### 1. Gas Fees
- Kullanıcılar kendi gas fee'lerini ödeyecek
- Mobile app'te gas estimation gösterilmeli
- Transaction onaylamadan önce gas fee bilgisi verilmeli

### 2. Transaction Status
- Mobile app transaction'ı gönderdikten sonra status'u takip etmeli
- Backend'den status sorgulanabilmeli (blockchain'den)
- UI'da transaction hash gösterilmeli

### 3. Error Handling
- Network hataları
- Transaction reject (kullanıcı onaylamadı)
- Transaction fail (revert)
- Insufficient balance

### 4. Security
- Private key asla backend'e gönderilmemeli
- Wallet bağlantısı güvenli olmalı
- Transaction'lar kullanıcı tarafından onaylanmalı

### 5. User Experience
- Wallet bağlantısı kolay olmalı
- Transaction onaylama açık olmalı
- Loading state'leri gösterilmeli
- Error mesajları anlaşılır olmalı

---

## 🚀 Migration Sırası

### Öncelik 1: Mobile App Wallet Entegrasyonu
1. Wallet Service oluştur
2. Blockchain Service oluştur
3. UI güncellemeleri
4. Test et

### Öncelik 2: Backend Read-Only Dönüşümü
1. Blockchain Reader Service oluştur
2. Transaction endpoint'lerini kaldır
3. Read-only endpoint'leri güncelle
4. Test et

### Öncelik 3: Blockchain Server Event Only
1. Action Worker'ı kaldır
2. Event Worker'ı güncelle
3. Sync Service ekle
4. Test et

### Öncelik 4: Database Sync
1. Initial sync script
2. Event-based sync
3. Conflict resolution
4. Test et

---

## ✅ Checklist

### Setup
- [ ] Mobile app dependencies ekle
- [ ] RPC provider config
- [ ] ABI dosyalarını mobile app'e kopyala
- [ ] Backend blockchain reader dependencies

### Mobile App
- [ ] Wallet Service oluştur
- [ ] Blockchain Service oluştur
- [ ] UI güncellemeleri
- [ ] Transaction flow test et

### Backend
- [ ] Blockchain Reader Service oluştur
- [ ] Transaction endpoint'lerini kaldır
- [ ] Read-only endpoint'leri güncelle
- [ ] Test et

### Blockchain Server
- [ ] Action Worker'ı kaldır
- [ ] Event Worker'ı güncelle
- [ ] Sync Service ekle
- [ ] Test et

### Database
- [ ] `chain_actions` tablosunu kaldır
- [ ] Sync mekanizması
- [ ] Initial sync script
- [ ] Test et

---

## 📚 Kaynaklar

- [web3dart Documentation](https://pub.dev/packages/web3dart)
- [WalletConnect Flutter](https://docs.walletconnect.com/2.0/flutter/installation)
- [Ethers.js Documentation](https://docs.ethers.org/)
- [Web3.py Documentation](https://web3py.readthedocs.io/)

---

**Sonuç:** Bu plan ile tam decentralized bir mimariye geçiş yapılacak. Blockchain ana veri kaynağı olacak, kullanıcılar kendi wallet'larını kullanacak, ve sistem tamamen merkezi olmayan bir yapıya kavuşacak.

