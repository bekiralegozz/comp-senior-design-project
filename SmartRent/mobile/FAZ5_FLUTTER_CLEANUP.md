# 🔧 FAZ 5: Flutter Tam Temizlik + Blockchain Entegrasyonu

## ⚠️ KRİTİK NOT

Bu fazda **TÜM Flutter dosyaları** analiz edilecek ve gereksiz her şey kaldırılacak/güncellenecek.

---

## 📋 Görevler

### 1. TÜM FLUTTER DOSYALARINI ANALİZ ET

**Okunacak Dosyalar:**

```
SmartRent/mobile/lib/
├── main.dart
├── components/
│   ├── asset_card.dart          ❌ Eski Asset modeli kullanıyor
│   ├── lock_control_dialog.dart
│   ├── rental_card.dart         ❌ Eski Rental modeli kullanıyor
│   └── wallet_info_widget.dart
├── constants/
│   ├── blockchain_config.dart   ✅ Polygon'a güncellendi
│   └── config.dart
├── contracts/
│   ├── Building1122.json
│   ├── Marketplace.json
│   └── RentalManager.json
├── core/
│   ├── providers/
│   │   ├── asset_provider.dart  ❌ Eski API kullanıyor
│   │   ├── auth_provider.dart   ✅ SIWE için güncellendi
│   │   ├── rental_provider.dart ❌ Eski API kullanıyor
│   │   └── wallet_provider.dart
│   ├── router/
│   │   └── app_router.dart      ✅ Güncellendi (ama route'lar sorunlu)
│   └── theme/
│       └── app_theme.dart
├── providers/
│   └── wallet_provider.dart     ❓ Duplicate mi kontrol et
├── screens/
│   ├── asset_details.dart       ❌ Eski Asset + API kullanıyor
│   ├── assets/
│   │   ├── create_asset_blockchain_screen.dart ❓ Kontrol et
│   │   └── my_assets_screen.dart ❌ Eski API kullanıyor
│   ├── auth/
│   │   └── wallet_connect_screen.dart ✅ SIWE için yeniden yazıldı
│   ├── home_screen.dart         ❌ getAssets, getCategories kullanıyor
│   ├── lock_control_screen.dart ❓ IoT - sonraya
│   ├── nft/
│   │   ├── nft_detail_screen.dart    ❓ Kontrol et
│   │   ├── nft_gallery_screen.dart   ❓ Kontrol et
│   │   ├── nft_portfolio_screen.dart ❓ Kontrol et
│   │   └── share_purchase_screen.dart ❓ Kontrol et
│   ├── profile_screen.dart      ❌ User modeli kullanıyor
│   ├── rental_screen.dart       ❌ Eski Rental + API kullanıyor
│   ├── rentals/
│   │   ├── pay_rent_blockchain_screen.dart ❓ Kontrol et
│   │   └── rental_details_screen.dart ❌ Eski API kullanıyor
│   ├── settings/
│   │   └── settings_screen.dart ❌ profile getter kullanıyor
│   └── wallet/
│       ├── wallet_connection_screen.dart ❓ Kontrol et
│       └── wallet_screen.dart    ❓ Kontrol et
├── services/
│   ├── api_service.dart         ✅ SIWE'ye güncellendi (ama eksik)
│   ├── blockchain_service.dart  ❓ Kontrol et
│   ├── models.dart              ⚠️ Placeholder modeller eklendi
│   ├── models.g.dart
│   ├── nft_models.dart          ❓ Kontrol et
│   ├── nft_service.dart         ❓ Kontrol et
│   ├── wallet_service.dart      ✅ Polygon'a güncellendi
│   └── wallet_service_simple.dart ❓ Gerekli mi?
└── widgets/
    ├── confirmation_dialog.dart
    ├── error_dialog.dart
    ├── success_dialog.dart
    ├── transaction_dialog.dart
    └── wallet_connect_button.dart
```

---

### 2. HER DOSYA İÇİN YAPILACAKLAR

#### A. API Çağrıları
- [ ] `ApiService` metodlarını kontrol et
- [ ] Database-dependent endpoint'leri kaldır
- [ ] Blockchain endpoint'leri ekle (varsa)

#### B. Model Kullanımları
- [ ] `User` → `walletAddress` only
- [ ] `Asset` → Blockchain data structure
- [ ] `Rental` → On-chain rental data
- [ ] `AuthProfile` → Kaldır, sadece `walletAddress`

#### C. Provider'lar
- [ ] `authStateProvider` → ✅ Zaten SIWE
- [ ] `assetProvider` → Blockchain'den asset çek
- [ ] `rentalProvider` → Blockchain'den rental çek
- [ ] `walletProvider` → Kontrol et

#### D. Screen'ler
Her screen için:
1. Eski API çağrılarını kaldır
2. Blockchain service kullan (varsa)
3. Ya da "Coming Soon" placeholder koy

---

### 3. KALDIRILACAK ŞEYLER

#### Dosyalar (Silinecek):
- [ ] `wallet_service_simple.dart` - Duplicate ise sil
- [ ] Kullanılmayan widgetlar

#### Kodlar (Kaldırılacak):
- [ ] `getAssets()` - Database API
- [ ] `getAssetCategories()` - Database API
- [ ] `getMyRentals()` - Database API
- [ ] `getRental()` - Database API
- [ ] `getUser()` - Database API
- [ ] `createAsset()` - Database API (blockchain versiyonu kullanılacak)
- [ ] `createRental()` - Database API (blockchain versiyonu kullanılacak)
- [ ] `profile` getter - AuthState'den kaldırıldı
- [ ] Email/password auth kodları

---

### 4. EKLENECEK ŞEYLER

#### Blockchain Data Fetching:
- [ ] `getAssetsFromBlockchain()` - Smart contract'tan asset listesi
- [ ] `getRentalsFromBlockchain()` - Smart contract'tan rental listesi
- [ ] `getUserAssetsFromBlockchain()` - Wallet'a ait asset'ler

#### SIWE Auth:
- [x] Nonce request
- [x] Signature verification
- [x] JWT token management
- [ ] Protected route handling

---

### 5. FAZ 5 ADIM ADIM

```
Adım 1: TÜM dosyaları oku ve analiz et
        ↓
Adım 2: Gereksiz dosyaları sil
        ↓
Adım 3: models.dart'ı blockchain-ready yap
        ↓
Adım 4: Providers'ı güncelle (blockchain data)
        ↓
Adım 5: Screens'leri güncelle
        ↓
Adım 6: Components'ları güncelle
        ↓
Adım 7: Test et (compile + runtime)
```

---

## 📊 Dosya Sayısı

| Kategori | Dosya Sayısı | Durum |
|----------|-------------|-------|
| Screens | 16 | Çoğu güncellenmeli |
| Components | 4 | 2'si güncellenmeli |
| Services | 7 | 4'ü güncellenmeli |
| Providers | 5 | 3'ü güncellenmeli |
| Widgets | 5 | Kontrol edilmeli |
| **TOPLAM** | **37** | |

---

## 🎯 Başarı Kriterleri

1. ✅ `flutter run -d chrome` hatasız compile
2. ✅ Wallet connect ekranı çalışıyor
3. ✅ SIWE auth flow çalışıyor
4. ✅ Home screen boş placeholder gösteriyor (blockchain data olmadan)
5. ✅ Hiç database API çağrısı yok
6. ✅ Tüm modeller blockchain-ready

---

## 📝 Notlar

- IoT device management şimdilik ignore edilecek
- NFT screen'leri kontrol edilecek (blockchain kullanıyor olabilir)
- `wallet_connect_screen.dart` zaten tamamlandı
- `auth_provider.dart` zaten SIWE için güncellendi

---

**Oluşturulma Tarihi:** 2025-12-16
**Faz:** 5 (Hazırlık)

