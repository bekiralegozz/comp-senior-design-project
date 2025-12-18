# Tüm NFT'leri Görüntüleme Akışı (Browse/Marketplace)

**Use Case:** Kullanıcı sistemdeki tüm NFT'leri görüntüler (marketplace, browse assets).

---

## 🔄 Mimari Akış Diyagramı

```
┌─────────────────────────────────────────────────────────────┐
│  1. Flutter UI - NFT Gallery/Browse Screen                 │
│  mobile/lib/screens/nft/nft_gallery_screen.dart            │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Kullanıcı "Browse Assets" veya "Marketplace" sekmesine  │
│    tıklar                                                   │
│  - _loadAssets() metodu çağrılır                            │
│  - Loading spinner gösterilir                               │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Sistemimdeki tüm NFT'leri keşfetme                       │
│  - Satın alınabilir assetleri görme                         │
│  - Loading state ve pagination yönetimi                     │
│                                                             │
│  INPUT: None (tüm NFT'leri iste)                            │
│  OUTPUT: HTTP request tetiklenir                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ getAllAssets()
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  2. Flutter Service - NFT Service                           │
│  mobile/lib/services/nft_service.dart                       │
│                                                             │
│  NE YAPIYOR?                                                │
│  - HTTP GET request oluşturur                               │
│  - Backend URL: /nft/assets                                 │
│  - Query params: limit, offset (pagination için)            │
│  - JSON response parse eder                                 │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Flutter ↔ Backend HTTP bridge                            │
│  - Pagination support (20 NFT per page)                     │
│  - Type-safe modeling (NftAsset)                            │
│                                                             │
│  REQUEST: GET http://localhost:8000/api/v1/nft/assets       │
│  QUERY: ?limit=20&offset=0                                  │
│  RESPONSE: {assets: [...], total: N}                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTP GET /nft/assets
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  3. Backend API - NFT Route                                 │
│  backend/app/api/routes/nft.py (@router.get)               │
│                                                             │
│  NE YAPIYOR?                                                │
│  - FastAPI endpoint - isteği alır                           │
│  - smartrenthub_service.get_all_assets() çağırır           │
│  - Pagination uygular (offset:offset+limit)                 │
│  - Her asset için IPFS'den metadata çeker                   │
│  - Owner count hesaplar                                     │
│  - OpenSea URL oluşturur                                    │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Blockchain + IPFS data aggregation                       │
│  - Pagination logic (performans için)                       │
│  - Data enrichment (metadata + extra fields)                │
│  - API gateway                                              │
│                                                             │
│  INPUT: limit=20, offset=0 (query params)                   │
│  OUTPUT: {assets: [...], total: N, limit, offset}          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ get_all_assets()
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  4. SmartRentHub Service - Web3 Layer                       │
│  backend/app/services/smartrenthub_service.py               │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Web3.py ile Infura'ya bağlanır                           │
│  - Contract instance hazırlar (ABI + address)               │
│  - contract.functions.getAllAssets().call()                 │
│  - Blockchain response'u Python list[dict]'e parse eder     │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Python ↔ Blockchain adapter                              │
│  - Smart contract abstraction layer                         │
│  - Type conversion (Solidity tuple → Python dict)           │
│  - Connection pooling (Web3 instance reuse)                 │
│                                                             │
│  WEB3 CALL: getAllAssets()                                  │
│  RETURN: List[Dict] (token_id, metadata_uri, total_shares, ...)│
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ JSON-RPC Request (eth_call)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  5. Infura RPC Node                                         │
│  polygon-mainnet.infura.io/v3/3eb14a5ade774b7985fc9cc2d9e9adb2│
│                                                             │
│  NE YAPIYOR?                                                │
│  - Backend'den JSON-RPC request alır                        │
│  - Request'i Polygon Mainnet node'una forward eder          │
│  - Blockchain response'u backend'e döndürür                 │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Managed blockchain access (self-hosted node gerekmez)    │
│  - Load balancing across multiple nodes                     │
│  - DDoS protection & rate limiting                          │
│  - Request/response logging & analytics                     │
│                                                             │
│  PROTOCOL: HTTPS POST (JSON-RPC 2.0)                        │
│  METHOD: eth_call (read-only, gas free)                     │
│  LIMIT: 100,000 requests/day (free tier)                    │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Blockchain Query Execute
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  6. Polygon Blockchain - SmartRentHub Contract              │
│  Address: 0x50B61c8F18EA52BC68565C5a11a848AE5aFdf785        │
│  Contract: SmartRentHub.sol                                 │
│                                                             │
│  NE YAPIYOR?                                                │
│  - getAllAssets() view function execute olur                │
│  - registeredTokenIds array'den tüm token ID'leri alır      │
│  - Her token için loop:                                     │
│    * assets[tokenId] mapping'den AssetInfo çeker            │
│    * exists == true olanları filtreler                      │
│  - AssetInfo[] array oluşturur ve döndürür                  │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Merkezi NFT registry (sistemdeki TÜM NFT'ler burada)     │
│  - Single call'da tüm asset listesi (gas efficient)         │
│  - Asset metadata storage (URI, total shares, created time) │
│  - Building1122'den bağımsız query (owner gerekmez)         │
│                                                             │
│  CODE:                                                      │
│  function getAllAssets() external view                      │
│      returns (AssetInfo[] memory)                           │
│  {                                                          │
│    uint256[] memory tokenIds = registeredTokenIds;          │
│    AssetInfo[] memory result = new AssetInfo[](tokenIds.length);│
│    for (uint256 i = 0; i < tokenIds.length; i++) {         │
│      result[i] = assets[tokenIds[i]];                       │
│    }                                                        │
│    return result;                                           │
│  }                                                          │
│                                                             │
│  VIEW FUNCTION: Gas ücreti YOK                              │
│  RETURN: AssetInfo[] (tokenId, metadataURI, totalShares,   │
│          createdAt, exists)                                 │
└─────────────────────────────────────────────────────────────┘
                      │
                      │ Data returns (blockchain → infura → backend)
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  7. IPFS Metadata Fetch (Paralel - Her Asset İçin)         │
│  Backend: smartrenthub_service.fetch_metadata()             │
│  Gateway: https://ipfs.io/ipfs/{hash}                       │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Blockchain'den gelen metadata_uri'leri alır              │
│  - ipfs:// → https://ipfs.io/ipfs/ dönüşümü yapar           │
│  - Her URI için async HTTP GET (paralel)                    │
│  - JSON metadata parse eder                                 │
│  - Timeout handling (10 saniye)                             │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - NFT görsel ve detay bilgilerini alma                     │
│  - Decentralized content delivery                           │
│  - Content-addressed immutable storage                      │
│  - Blockchain'de sadece hash tutarak gas tasarrufu          │
│                                                             │
│  IPFS METADATA FORMAT:                                      │
│  {                                                          │
│    "name": "Downtown Apartment #101",                       │
│    "description": "2BR luxury apartment...",                │
│    "image": "ipfs://QmImageHash...",                        │
│    "attributes": [                                          │
│      {"trait_type": "Bedrooms", "value": "2"},              │
│      {"trait_type": "Location", "value": "Downtown"}        │
│    ]                                                        │
│  }                                                          │
│                                                             │
│  PERFORMANCE: ~100-300ms per asset (paralel fetch)          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ Enriched data merge
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  8. Backend - Response Assembly & Pagination                │
│  backend/app/api/routes/nft.py                              │
│                                                             │
│  NE YAPIYOR?                                                │
│  - Blockchain data + IPFS metadata merge eder               │
│  - Pagination slice uygular: assets[offset:offset+limit]    │
│  - Her asset için:                                          │
│    * Image URL convert (ipfs:// → https://)                 │
│    * OpenSea URL generate                                   │
│    * Owners count ekle                                      │
│  - Final JSON response oluşturur                            │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - Data transformation & enrichment                         │
│  - Pagination (performans: 1000 NFT'den 20'sini döndür)     │
│  - API contract fulfillment (Flutter expectations)          │
│  - Error handling ve fallback values                        │
│                                                             │
│  RESPONSE FORMAT:                                           │
│  {                                                          │
│    "assets": [                                              │
│      {                                                      │
│        "token_id": 11757,                                   │
│        "name": "Downtown Apartment #101",                   │
│        "description": "2BR luxury...",                      │
│        "image_url": "https://ipfs.io/ipfs/Qm...",           │
│        "total_shares": 1000,                                │
│        "owners_count": 3,                                   │
│        "metadata_uri": "ipfs://Qm...",                      │
│        "opensea_url": "https://opensea.io/assets/matic/..." │
│      },                                                     │
│      ...                                                    │
│    ],                                                       │
│    "total": 247,  // Toplam NFT sayısı                      │
│    "limit": 20,                                             │
│    "offset": 0                                              │
│  }                                                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTP 200 OK + JSON
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  9. Flutter - UI Rendering (Grid/List)                     │
│  mobile/lib/screens/nft/nft_gallery_screen.dart            │
│                                                             │
│  NE YAPIYOR?                                                │
│  - JSON'u List<NftAsset> model'lerine parse eder            │
│  - setState() ile _assets listesini günceller               │
│  - GridView.builder veya ListView ile render eder           │
│  - Her NFT için Card widget:                                │
│    * Görsel (cached_network_image)                          │
│    * İsim                                                   │
│    * Total shares                                           │
│    * "View Details" butonu                                  │
│  - Pagination controls (Sayfa 1/13)                         │
│  - Pull-to-refresh functionality                            │
│                                                             │
│  NE İŞE YARIYOR?                                            │
│  - User'a browse experience                                 │
│  - Asset discovery (yeni NFT'leri keşfetme)                 │
│  - Marketplace görünümü (satın alınabilecek assetler)       │
│  - Smooth scrolling & lazy loading                          │
│                                                             │
│  UI EXAMPLE:                                                │
│  ┌────────┬────────┬────────┐                               │
│  │ [IMG]  │ [IMG]  │ [IMG]  │                               │
│  │ Apt#101│ Villa#5│ House#2│                               │
│  │ 1000sh │ 1000sh │ 1000sh │                               │
│  └────────┴────────┴────────┘                               │
│  ┌────────┬────────┬────────┐                               │
│  │ ...    │ ...    │ ...    │                               │
│  └────────┴────────┴────────┘                               │
│  ← Sayfa 1/13 →                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Portföy vs Tüm NFT'ler - Farklar

| Özellik | My NFTs (Portföy) | Browse/Marketplace (Tüm NFT'ler) |
|---------|-------------------|----------------------------------|
| **Endpoint** | `/nft/holdings/{address}` | `/nft/assets` |
| **Smart Contract Call** | `getAssetsWithBalances(address)` | `getAllAssets()` |
| **Filtering** | Wallet'a göre (sadece benim NFT'lerim) | Filtre yok (sistemdeki her NFT) |
| **Balance Info** | ✅ Var (kullanıcının share'leri) | ❌ Yok (genel listing) |
| **Cross-Contract Call** | ✅ Building1122.balanceOf() (her NFT için) | ❌ Yok (balance gerekmiyor) |
| **Pagination** | Genelde gereksiz (az NFT) | ✅ Kritik (binlerce NFT olabilir) |
| **Use Case** | "Benim ne kadar varlığım var?" | "Ne satın alabilirim?" |
| **Performance** | ~600ms - 1s | ~800ms - 2s (pagination sayesinde) |

---

## 📊 Veri Kaynakları

### Blockchain'den (SmartRentHub):
- **Token IDs:** `registeredTokenIds` array
- **Total Shares:** `assets[tokenId].totalShares`
- **Metadata URI:** `assets[tokenId].metadataURI`
- **Created Time:** `assets[tokenId].createdAt`
- **Exists Flag:** `assets[tokenId].exists`

### IPFS'den:
- **Name:** "Downtown Apartment #101"
- **Image:** QmHash... → `https://ipfs.io/ipfs/...`
- **Description:** Detaylı açıklama
- **Attributes:** Property özellikleri

### Backend'de Eklenen:
- **OpenSea URL:** `https://opensea.io/assets/matic/{contract}/{tokenId}`
- **Owners Count:** `len(asset.owners)` (SmartRentHub tracking'den)
- **Image URL Conversion:** `ipfs://` → `https://`

---

## ⚡ Performance Optimization

### Pagination Neden Kritik?

**Senaryo:** Sistemde 1000 NFT var

**Pagination OLMADAN:**
```
- Blockchain: 1000 NFT metadata (tek call, hızlı) ✅
- IPFS: 1000x metadata fetch (300ms x 1000) ❌
  = ~5 dakika bekleme!
- Memory: 1000 NFT'nin tüm datası RAM'de ❌
```

**Pagination İLE:**
```
- Blockchain: 1000 NFT metadata (tek call, hızlı) ✅
- IPFS: Sadece 20x metadata fetch (300ms x 20) ✅
  = ~6 saniye
- Memory: Sadece 20 NFT data
- User: Sayfa 2'ye tıklarsa, tekrar 20 çekilir
```

### Cache Stratejisi (Future İmprovement)
```python
# Backend'de cache eklenebilir:
@cache(ttl=300)  # 5 dakika cache
def get_all_assets():
    ...
```

---

## 💰 Maliyet & Limitler

| Kaynak | Maliyet | Limit | Not |
|--------|---------|-------|-----|
| **Infura RPC** | $0 | 100K req/day | Free tier |
| **Blockchain Read** | $0 (gas yok) | Unlimited | View function |
| **IPFS Gateway** | $0 | Soft limit (~100 req/min) | Public gateway |
| **Backend Compute** | $0 | - | Localhost |

**Scaling için:**
- Infura paid plan: $50/ay (1M req/month)
- Kendi IPFS pinning service (Pinata: $20/ay)
- Backend caching layer (Redis)

---

## 🔑 Kritik Nokta: Merkezi Registry

```
SmartRentHub = "Google for NFTs"
  ↓
Her mint edilen NFT buraya kaydedilir
  ↓
getAllAssets() ile tamamını listeleme

Building1122'de mint:
  mintInitialSupply()
    ↓ (automatic call)
  SmartRentHub.registerAsset()
    ↓
  registeredTokenIds.push(tokenId)
```

**Neden merkezi registry?**
- ERC-1155 standardında "tüm token'ları listele" fonksiyonu yok
- Her token'u bulmak için event log tarama gerekir (yavaş)
- SmartRentHub bu sorunu çözer (optimization)

---

## 🚀 Future Improvements

1. **Filtering:**
   - `/nft/assets?property_type=Apartment`
   - `/nft/assets?min_shares=500`

2. **Sorting:**
   - `/nft/assets?sort=created_at&order=desc`
   - `/nft/assets?sort=total_shares`

3. **Search:**
   - `/nft/assets?search=Downtown`
   - Full-text search (Elasticsearch)

4. **Caching:**
   - Redis layer
   - Blockchain data cache (5 dakika)
   - IPFS metadata cache (1 saat)

---

**Son Güncelleme:** 18 Aralık 2025

