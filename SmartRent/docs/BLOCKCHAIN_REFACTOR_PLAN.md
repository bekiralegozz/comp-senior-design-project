# SmartRent Blockchain Refactor Plan

## Mimari Diyagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        SMARTRENT ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐                      │
│  │   Flutter    │◄───────►│   Backend    │                      │
│  │   Mobile     │   REST  │   FastAPI    │                      │
│  └──────┬───────┘   API   └──────┬───────┘                      │
│         │                        │                               │
│         │ WalletConnect          │ Infura RPC                    │
│         ▼                        ▼                               │
│  ┌──────────────┐         ┌──────────────┐                      │
│  │   MetaMask   │         │   Polygon    │                      │
│  │   Wallet     │         │   Mainnet    │                      │
│  └──────────────┘         └──────┬───────┘                      │
│                                  │                               │
│                    ┌─────────────┴─────────────┐                │
│                    ▼                           ▼                │
│            ┌──────────────┐           ┌──────────────┐          │
│            │ SmartRentHub │◄─────────►│ Building1122 │          │
│            │  (Registry   │  Cross    │  (ERC-1155)  │          │
│            │  Marketplace)│  Calls    │              │          │
│            └──────────────┘           └──────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Contract Adresleri (Polygon Mainnet - 18 Aralık 2024)

| Contract | Adres | Açıklama |
|----------|-------|----------|
| SmartRentHub | `0xE579A3e8D770A5C52CCa1C2c08Ab1547757Be6D9` | Registry + Marketplace |
| Building1122 | `0xC37a4625641A8481127A3F129c8985857ee92CaB` | ERC-1155 Token |
| RentalManager | `0x7732B578B9CF47D4B725B54F6db43cBf51945E46` | Kira Dağıtımı (Gelecek) |

---

## FAZ 1: SmartRentHub.sol Smart Contract ✅

- [x] 1.1 Registry state ve struct'lar (AssetInfo, owners mapping)
- [x] 1.2 Listings state ve struct'lar (Listing, activeListingIds)
- [x] 1.3 registerAsset() ve updateOwnership() fonksiyonları
- [x] 1.4 createListing(), cancelListing(), buyFromListing()
- [x] 1.5 Helper view fonksiyonları (getAssetsByOwner, getActiveListings)

---

## FAZ 2: Building1122.sol Modifikasyonu ✅

- [x] 2.1 smartRentHub address state variable ekleme
- [x] 2.2 mintInitialSupply() → SmartRentHub.registerAsset() çağrısı
- [x] 2.3 _update() override → SmartRentHub.updateOwnership() çağrısı

---

## FAZ 3: Contract Deployment ✅

- [x] 3.1 Hardhat deployment script güncelleme
- [x] 3.2 Polygon Mainnet'e deploy
- [ ] 3.3 Contract verification (Polygonscan) - Opsiyonel

---

## FAZ 4: Backend Entegrasyonu 🔄

- [x] 4.1 Backend .env güncelleme (yeni contract adresleri)
- [ ] 4.2 SmartRentHub ABI ve service oluşturma
- [ ] 4.3 /nft/assets endpoint → SmartRentHub.getAllAssets()
- [ ] 4.4 /nft/my-nfts endpoint → SmartRentHub.getAssetsByOwner()
- [ ] 4.5 /nft/listings endpoint → SmartRentHub.getActiveListings()
- [ ] 4.6 Listing ve Buy transaction prepare endpoints

---

## FAZ 5: Flutter UI Güncellemeleri

- [ ] 5.1 My NFTs tab → Backend'den veri çek + Sell butonu
- [ ] 5.2 Sell flow UI (share miktarı, fiyat girişi)
- [ ] 5.3 Marketplace tab → Aktif listingleri göster
- [ ] 5.4 Buy flow UI (listing detay, satın alma onayı)

---

## FAZ 6: Test ve Cleanup

- [ ] 6.1 End-to-end test: Mint → List → Buy
- [ ] 6.2 Eski Alchemy kodlarını kaldır

---

## Notlar

- Alchemy dependency kaldırıldı, artık direkt RPC ile contract'lardan okuyoruz
- SmartRentHub hem registry hem marketplace görevi görüyor
- Building1122 her mint/transfer'da SmartRentHub'ı bilgilendiriyor
