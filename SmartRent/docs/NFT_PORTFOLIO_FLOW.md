# NFT Portföyü Görüntüleme Akışı (My NFTs)

**Use Case:** Kullanıcı kendi wallet'ındaki NFT'leri görüntüler.

---

## 🔄 Mimari Akış Diyagramı

```
┌─────────────────────────────────────────────────────────────┐
│  1. Flutter UI - NFT Portfolio Screen                      │
│  mobile/lib/screens/nft/nft_portfolio_screen.dart          │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Kullanıcı "My NFTs" sekmesine tıklar                     │
│  - _loadHoldings() metodu çağrılır                          │
│  - Loading spinner gösterilir                               │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - User experience: Loading state yönetimi                  │
│  - Wallet address validation                                │
│  - Error handling ve UI feedback                            │
│                                                             │
│  INPUT: widget.walletAddress (0x742d35...)                  │
│  OUTPUT: HTTP request tetiklenir                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ getUserHoldings(walletAddress)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  2. Flutter Service - NFT Service                           │
│  mobile/lib/services/nft_service.dart                       │
│                                                             │
│  NE YAPIYOR?                                                │
│  - HTTP GET request oluşturur                               │
│  - Backend URL: /nft/holdings/{address}                     │
│  - JSON response parse eder                                 │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Flutter ile Backend arasında HTTP iletişim              │
│  - Type-safe data modeling (UserNftHolding)                 │
│  - Network error handling                                   │
│                                                             │
│  REQUEST: GET http://localhost:8000/api/v1/nft/holdings/0x...│
│  RESPONSE: JSON array of holdings                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTP GET /nft/holdings/{wallet_address}
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  3. Backend API - NFT Route                                 │
│  backend/app/api/routes/nft.py (@router.get)               │
│                                                             │
│  NE YAPIYOR?                                                │
│  - FastAPI endpoint - isteği alır                           │
│  - smartrenthub_service.get_assets_by_owner() çağırır      │
│  - Her asset için IPFS'den metadata çeker                   │
│  - Response formatını Flutter için hazırlar                 │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Blockchain + IPFS verilerini birleştirir                 │
│  - Data enrichment (metadata ekleme)                        │
│  - API gateway olarak çalışır                               │
│                                                             │
│  INPUT: wallet_address (path parameter)                     │
│  OUTPUT: holdings[] (token_id, name, image, shares, %)     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ get_assets_by_owner(wallet_address)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  4. SmartRentHub Service - Web3 Layer                       │
│  backend/app/services/smartrenthub_service.py               │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Web3.py ile Infura'ya bağlanır                           │
│  - Contract instance oluşturur (ABI + address)              │
│  - contract.functions.getAssetsWithBalances().call()        │
│  - Raw blockchain data'yı Python dict'e parse eder          │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Python ↔ Blockchain köprüsü                              │
│  - Smart contract function call abstraction                 │
│  - Data type conversion (Solidity → Python)                 │
│                                                             │
│  WEB3 CALL: getAssetsWithBalances(address)                  │
│  RETURN: List[Dict] (token_id, balance, metadata_uri, ...)  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ JSON-RPC Request (eth_call)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  5. Infura RPC Node                                         │
│  polygon-mainnet.infura.io/v3/YOUR_API_KEY                  │
│                                                             │
│  NE YAPIYOR?                                                │
│  - JSON-RPC request'i alır                                  │
│  - Polygon Mainnet full node'una iletir                     │
│  - Response'u backend'e döndürür                            │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Managed blockchain gateway (kendi node çalıştırmaya gerek yok) │
│  - High availability & reliability                          │
│  - Rate limiting & monitoring                               │
│                                                             │
│  PROTOCOL: HTTPS POST (JSON-RPC 2.0)                        │
│  COST: Ücretsiz (100K request/day limit)                    │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Blockchain Query
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  6. Polygon Blockchain - SmartRentHub Contract              │
│  Address: 0x50B61c8F18EA52BC68565C5a11a848AE5aFdf785        │
│  Contract: SmartRentHub.sol                                 │
│                                                             │
│  NE YAPIYOR?                                                │
│  - getAssetsWithBalances(address owner) fonksiyonu çalışır  │
│  - _ownerToTokens[owner] mapping'den token ID'leri bulur    │
│  - Her token için loop:                                     │
│    * Asset metadata (totalShares, metadataURI, createdAt)   │
│    * Building1122.balanceOf() cross-contract call           │
│  - AssetWithBalance[] array oluşturur                       │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Merkezi NFT registry (tüm assetlerin listesi)            │
│  - Owner tracking (_ownerToTokens mapping)                  │
│  - Tek call'da tüm user NFT'lerini döndürme (gas efficient) │
│                                                             │
│  VIEW FUNCTION: Gas ücreti YOK                              │
│  RETURN: AssetWithBalance[] (ABI encoded)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Cross-Contract Call (her token için)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  6.1. Building1122 Contract (ERC-1155)                      │
│  Token contract                                             │
│                                                             │
│  NE YAPIYOR?                                                │
│  - balanceOf(address account, uint256 tokenId)              │
│  - _balances[tokenId][account] storage'dan okur             │
│  - Kullanıcının o token'dan kaç share'i olduğunu döndürür   │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Single source of truth: Token balances                   │
│  - ERC-1155 standard implementation                         │
│  - Transfer'lerde otomatik güncellenir                      │
│                                                             │
│  ÖRNEK: User 0x742... için token #11757 → 250 shares       │
└─────────────────────────────────────────────────────────────┘
                      │
                      │ Data returns (blockchain → backend)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  7. IPFS Metadata Fetch                                     │
│  Backend: smartrenthub_service.fetch_metadata()             │
│  Gateway: https://ipfs.io/ipfs/{hash}                       │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Her asset için metadata_uri'den JSON çeker               │
│  - ipfs:// protokolünü https:// gateway'e dönüştürür        │
│  - Async HTTP GET ile metadata alır                         │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - NFT görsel ve isim bilgisi (blockchain'de sadece URI var)│
│  - Decentralized storage access                             │
│  - Content-addressed immutable data                         │
│                                                             │
│  METADATA: {name, image, description, attributes}           │
│  FORMAT: JSON                                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Enriched data return
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  8. Backend - Response Assembly                             │
│  backend/app/api/routes/nft.py                              │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Blockchain data + IPFS metadata merge eder               │
│  - ownership_percentage hesaplar (balance/total*100)        │
│  - image_url convert (ipfs:// → https://)                   │
│  - Flutter'ın beklediği JSON formatına çevirir              │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Data aggregation & transformation                        │
│  - API contract (frontend beklentilerini karşıla)           │
│  - Error handling ve logging                                │
│                                                             │
│  JSON: [{token_id, name, image_url, shares, total, %}]     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTP 200 OK + JSON response
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  9. Flutter - UI Rendering                                  │
│  mobile/lib/screens/nft/nft_portfolio_screen.dart          │
│                                                             │
│  NE YAPIYOR?                                                │
│  - JSON'u UserNftHolding model'lerine parse eder            │
│  - setState() ile _holdings listesini günceller             │
│  - ListView.builder ile UI render eder                      │
│  - Her NFT için Card widget (image, name, shares, %)       │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - User'a görsel arayüz sunma                               │
│  - Reactive UI (data değişince otomatik güncelleme)         │
│  - Smooth UX (loading, error states)                        │
│                                                             │
│  UI: Grid/List of NFT cards with images and details        │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Veri Akışı Özeti

### Blockchain'den Gelen Veriler:
- **Token IDs:** SmartRentHub'dan (`_ownerToTokens` mapping)
- **Balance:** Building1122'den (ERC-1155 `balanceOf`)
- **Total Shares:** SmartRentHub'dan (asset registry)
- **Metadata URI:** SmartRentHub'dan
- **Created Time:** SmartRentHub'dan

### IPFS'den Gelen Veriler:
- **Name:** "Downtown Apartment #101"
- **Image:** QmHash... (görsel)
- **Description:** Asset açıklaması
- **Attributes:** Property type, bedrooms, location, vb.

### Backend'de Hesaplanan:
- **Ownership Percentage:** `(balance / total_shares) * 100`
- **URL Conversion:** `ipfs://` → `https://ipfs.io/ipfs/`

---

## ⚡ Performance & Maliyet

| Adım | Süre | Maliyet | Not |
|------|------|---------|-----|
| Flutter → Backend | ~50ms | Ücretsiz | HTTP request |
| Backend → Infura | ~200-500ms | Ücretsiz | RPC limit: 100K/day |
| Blockchain Read | ~50ms | **Gas YOK** | View function |
| IPFS Fetch | ~100-300ms/NFT | Ücretsiz | Public gateway |
| Total | ~600ms - 1.5s | **$0** | NFT sayısına göre değişir |

---

## 🔑 Kritik Nokta: Single Source of Truth

```
Token Ownership (Balance):
  Building1122 (ERC-1155) ✅ ASIL KAYNAK
       ↓ (cross-contract read)
  SmartRentHub ← Sadece "kim hangi tokenları tutuyor" listesi

Metadata:
  IPFS ✅ ASIL KAYNAK (immutable, content-addressed)
       ↓
  SmartRentHub ← Sadece URI referansı
```

**Neden bu önemli?**
- Transfer işlemleri Building1122'de yapılır
- SmartRentHub sadece tracking için (optimization)
- Veri tutarsızlığı olmaz (single source)

---

**Son Güncelleme:** 18 Aralık 2025

