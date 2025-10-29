# 🚀 SmartRent - Hızlı Başlangıç Kılavuzu (Türkçe)

## 📋 Oluşturulan Dosyalar

### ✅ Tamamlanan İskelet Yapısı

#### 📱 **Mobile (Flutter)**
```
mobile/lib/
├── core/
│   ├── router/app_router.dart           ✅ GoRouter konfigürasyonu
│   ├── providers/
│   │   ├── auth_provider.dart           ✅ Kimlik doğrulama state management
│   │   ├── asset_provider.dart          ✅ Asset state management
│   │   ├── rental_provider.dart         ✅ Rental state management
│   │   └── wallet_provider.dart         ✅ Wallet state management
│   └── theme/app_theme.dart             ✅ Material 3 tema
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart            ✅ Login ekranı
│   │   ├── register_screen.dart         ✅ Kayıt ekranı
│   │   └── wallet_connect_screen.dart   ✅ Wallet bağlantı ekranı
│   ├── assets/
│   │   ├── create_asset_screen.dart     ✅ Placeholder
│   │   └── my_assets_screen.dart        ✅ Placeholder
│   ├── rentals/
│   │   ├── rental_details_screen.dart   ✅ Placeholder
│   │   └── create_rental_screen.dart    ✅ Placeholder
│   ├── wallet/wallet_screen.dart        ✅ Wallet ekranı
│   └── settings/settings_screen.dart    ✅ Ayarlar ekranı
│
├── services/
│   └── blockchain_service.dart          ✅ Blockchain servis
│
└── main.dart                            ✅ Güncellenmiş ana dosya
```

#### 🔧 **Backend (FastAPI)**
```
backend/
├── app/
│   └── api/routes/
│       ├── users.py                     ✅ User endpoints (placeholder)
│       ├── assets.py                    ✅ Asset endpoints (placeholder)
│       └── rentals.py                   ✅ Rental endpoints (placeholder)
│
├── requirements.txt                     ✅ Python bağımlılıkları
├── .env.example                         ✅ Environment şablonu
└── README_DETAILED.md                   ✅ Detaylı dokümantasyon
```

#### 🔌 **IoT (ESP32)**
```
iot_device/
├── src/
│   └── main_basic.py                    ✅ Temel ESP32 kodu
└── README_DETAILED.md                   ✅ Detaylı dokümantasyon
```

#### 📚 **Dokümantasyon**
```
root/
├── DEVELOPMENT_CHECKLIST.md             ✅ Kapsamlı geliştirme checklist
├── PROJECT_STRUCTURE.md                 ✅ Proje yapısı
└── SmartRent/README_MAIN.md             ✅ Ana README
```

---

## 🎯 Sıradaki Adımlar

### 1️⃣ **Blockchain Ekibi**
```bash
cd SmartRent/blockchain
npm install
cp .env.example .env
# .env dosyasını düzenle (Infura API key, private key)
npx hardhat compile
npx hardhat test
```

**Yapılacaklar:**
- [ ] AssetToken contract'ını deploy et
- [ ] RentalAgreement contract'ını deploy et
- [ ] Contract adreslerini kaydet
- [ ] Test network'e (Sepolia) deploy et

### 2️⃣ **Backend Ekibi**
```bash
cd SmartRent/backend
python -m venv venv
source venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
cp .env.example .env
# .env dosyasını düzenle (Supabase, Web3 provider)
```

**Yapılacaklar:**
- [ ] Supabase projesi oluştur
- [ ] Database schema'yı tasarla
- [ ] User endpoints'leri implement et
- [ ] Asset endpoints'leri implement et
- [ ] Rental endpoints'leri implement et

### 3️⃣ **Mobile Ekibi**
```bash
cd SmartRent/mobile
flutter pub get
# lib/constants/config.dart dosyasını düzenle
flutter run
```

**Yapılacaklar:**
- [ ] Backend API URL'sini config'e ekle
- [ ] WalletConnect project ID al ve ekle
- [ ] Home screen'i detaylandır
- [ ] Asset details screen'i detaylandır
- [ ] Rental flow'unu tamamla

### 4️⃣ **IoT Ekibi**
```bash
cd SmartRent/iot_device
# src/main_basic.py dosyasını düzenle
# Arduino IDE veya PlatformIO ile ESP32'ye yükle
```

**Yapılacaklar:**
- [ ] ESP32 geliştirme ortamını kur
- [ ] WiFi ayarlarını yapılandır
- [ ] Kilit donanımını bağla
- [ ] Temel lock/unlock test et

---

## 📋 Geliştirme Sırası (Öncelik)

### **PHASE 1 (İlk 2 Hafta)**
1. **Blockchain**: AssetToken ve RentalAgreement deploy
2. **Backend**: Temel API endpoints (users, assets, rentals)
3. **Mobile**: Login/Register/WalletConnect ekranları
4. **IoT**: Temel WiFi ve lock kontrolü

### **PHASE 2 (Sonraki 3 Hafta)**
1. **Blockchain**: Governance ve fractional ownership
2. **Backend**: Blockchain event listener
3. **Mobile**: Asset listeleme ve detay ekranları
4. **IoT**: Supabase Realtime entegrasyonu

### **PHASE 3 (Son 3 Hafta)**
1. **Blockchain**: Güvenlik testleri
2. **Backend**: Dynamic governance listener
3. **Mobile**: Rental oluşturma ve IoT unlock
4. **IoT**: Tam entegrasyon testi

---

## 🔑 Önemli Notlar

### **Environment Variables**
Her modül için `.env.example` dosyasını `.env` olarak kopyalayın ve düzenleyin:

**Blockchain:**
```env
INFURA_PROJECT_ID=your_infura_id
PRIVATE_KEY=your_private_key_without_0x
```

**Backend:**
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
WEB3_PROVIDER_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
```

**Mobile:**
```dart
// lib/constants/config.dart
apiBaseUrl = 'http://YOUR_IP:8000/api/v1'
walletConnectProjectId = 'YOUR_PROJECT_ID'
```

**IoT:**
```python
# src/main_basic.py
WIFI_SSID = "Your_WiFi"
WIFI_PASSWORD = "Your_Password"
BACKEND_API_URL = "http://YOUR_IP:8000/api/v1"
```

---

## 🧪 Test Komutları

```bash
# Blockchain testleri
cd blockchain && npx hardhat test

# Backend testleri
cd backend && pytest

# Mobile testleri
cd mobile && flutter test

# Backend'i çalıştır
cd backend && uvicorn app.main:app --reload

# Mobile'ı çalıştır
cd mobile && flutter run
```

---

## 📞 Kaynaklar

- **Sepolia Faucet**: https://sepoliafaucet.com/
- **Infura**: https://infura.io/
- **Supabase**: https://supabase.com/
- **WalletConnect**: https://cloud.walletconnect.com/

---

## ✅ Checklist Kullanımı

Ana geliştirme checklist'i için:
```bash
cat DEVELOPMENT_CHECKLIST.md
```

Bu dosya tüm ekipler için detaylı görevleri içerir. Her sprint'te:
1. Hangi görevlerin tamamlanacağına karar verin
2. Görevleri işaretleyin: `- [ ]` → `- [x]`
3. Daily standup'larda ilerlemeyi paylaşın
4. Blockerları belirleyin ve çözün

---

## 🎉 Başarılar Dileriz!

Her şey hazır! Artık ekip olarak paralel çalışabilir ve her hafta entegrasyon toplantılarında birleşebilirsiniz.

**İletişim**: Her ekip kendi modülünde çalışırken, API endpoints ve contract adreslerini güncel tutun.

**Git Workflow**:
```bash
git checkout -b feature/your-feature-name
# Değişiklikleri yap
git add .
git commit -m "feat: your feature description"
git push origin feature/your-feature-name
# Pull request oluştur
```

---

**Hazırlanan:** SmartRent Development Team  
**Tarih:** 29 Ekim 2025  
**Versiyon:** 1.0.0
