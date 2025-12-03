# 🔐 SmartRent IoT Smart Lock - Tam Kurulum Rehberi

## 📋 İçindekiler
1. [Gereksinimler](#1-gereksinimler)
2. [Backend Hazırlık](#2-backend-hazırlık)
3. [ESP32 Kurulumu](#3-esp32-kurulumu)
4. [Cihaz Kaydı](#4-cihaz-kaydı)
5. [Asset'e Bağlama](#5-assete-bağlama)
6. [Mobil Uygulama Kullanımı](#6-mobil-uygulama-kullanımı)
7. [Test ve Sorun Giderme](#7-test-ve-sorun-giderme)

---

## 1. Gereksinimler

### Donanım
- ✅ **ESP32 Development Board** (herhangi bir model)
- ✅ **Servo Motor** (SG90 veya benzeri, 5V)
- ✅ **Breadboard** ve jumper kablolar
- ✅ **USB Kablosu** (ESP32'yi bilgisayara bağlamak için)

### Yazılım
- ✅ **Python 3.9+** (MicroPython için)
- ✅ **esptool** (ESP32'ye firmware yüklemek için)
- ✅ **ampy** veya **mpremote** (dosya yüklemek için)
- ✅ **Backend çalışır durumda** (http://localhost:8000)

---

## 2. Backend Hazırlık

### 2.1. Backend'in Çalıştığını Doğrulayın

```bash
# Backend klasörüne gidin
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/backend

# Virtual environment'ı aktif edin
source venv/bin/activate

# Backend'i başlatın
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Test:**
- Tarayıcıda açın: http://localhost:8000/docs
- "IoT Devices" bölümünü görmelisiniz

### 2.2. Network Bilgilerini Not Alın

```bash
# Bilgisayarınızın local IP adresini bulun
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**Örnek çıktı:**
```
inet 192.168.1.100 netmask 0xffffff00 broadcast 192.168.1.255
```

📝 **Not alın:** `192.168.1.100` (sizinki farklı olabilir)

---

## 3. ESP32 Kurulumu

### 3.1. MicroPython Firmware Yükleme

```bash
# 1. esptool'u yükleyin
pip install esptool

# 2. MicroPython firmware'ini indirin
curl -o esp32-micropython.bin https://micropython.org/resources/firmware/esp32-20231005-v1.21.0.bin

# 3. ESP32'yi USB ile bağlayın ve port'u bulun
ls /dev/tty.* | grep usb
# Örnek: /dev/tty.usbserial-0001

# 4. Flash'i silin
esptool.py --port /dev/tty.usbserial-0001 erase_flash

# 5. Firmware'i yükleyin
esptool.py --chip esp32 --port /dev/tty.usbserial-0001 write_flash -z 0x1000 esp32-micropython.bin
```

### 3.2. Servo Motor Bağlantısı

**Bağlantı Şeması:**
```
Servo Motor       ESP32
-----------       -----
VCC (Kırmızı) -> 5V (VIN)
GND (Kahve)    -> GND
Signal (Turuncu) -> GPIO 13
```

### 3.3. ESP32 Kodunu Hazırlama

ESP32 için kodu güncelleyelim:

```bash
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/iot_device/src
```

Aşağıdaki değişiklikleri yapın:

---

## 4. Cihaz Kaydı

### 4.1. Backend'e Yeni Cihaz Kaydetme

**Terminal'de:**

```bash
# Backend'e POST request
curl -X POST http://localhost:8000/api/v1/iot/devices \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-LIVINGROOM-001",
    "device_name": "Living Room Smart Lock",
    "device_type": "smart_lock",
    "firmware_version": "v1.0.0",
    "mac_address": "AA:BB:CC:DD:EE:01"
  }'
```

**Yanıt:**
```json
{
  "id": 2,
  "device_id": "ESP32-LIVINGROOM-001",
  "device_name": "Living Room Smart Lock",
  "api_key": "sk_iot_abc123...",
  "message": "Device registered successfully. Save the API key securely!"
}
```

📝 **ÇOK ÖNEMLİ:** `api_key`'i kaydedin! Bir daha gösterilmeyecek!

### 4.2. API Key'i ESP32 Koduna Ekleme

`smart_lock_servo.py` dosyasını düzenleyin:

```python
# Configuration
CONFIG = {
    'WIFI_SSID': 'YourWiFiName',           # WiFi adınız
    'WIFI_PASSWORD': 'YourWiFiPassword',   # WiFi şifreniz
    'API_BASE_URL': 'http://192.168.1.100:8000/api/v1/iot',  # Backend IP
    'API_KEY': 'sk_iot_abc123...',         # Yukarıda aldığınız API key
    'DEVICE_ID': 'ESP32-LIVINGROOM-001',   # Device ID
    'SERVO_PIN': 13,
    'POLL_INTERVAL': 5,
}
```

### 4.3. Kodu ESP32'ye Yükleme

```bash
# ampy'yi yükleyin
pip install adafruit-ampy

# Dosyayı ESP32'ye yükleyin
ampy --port /dev/tty.usbserial-0001 put smart_lock_servo.py main.py

# ESP32'yi restart edin
ampy --port /dev/tty.usbserial-0001 reset
```

**Alternatif (mpremote):**
```bash
pip install mpremote
mpremote connect /dev/tty.usbserial-0001 cp smart_lock_servo.py :main.py
mpremote connect /dev/tty.usbserial-0001 reset
```

### 4.4. ESP32 Loglarını İzleme

```bash
# Serial monitor
screen /dev/tty.usbserial-0001 115200

# Çıkmak için: Ctrl+A, K, Y
```

**Göreceğiniz çıktı:**
```
=== SmartRent IoT Smart Lock v1.0.0 ===
[INFO] Connecting to WiFi: YourWiFiName
[INFO] WiFi connected! IP: 192.168.1.150
[INFO] Starting command polling loop...
[INFO] Polling for commands...
```

---

## 5. Asset'e Bağlama

### 5.1. Supabase'de Asset Oluşturma

1. **Supabase Dashboard** → https://supabase.com/dashboard/project/oajhrwleyhpeelbrdqdd
2. **Table Editor** → `assets` tablosu
3. **Insert Row** → Yeni asset ekleyin:

```
name: "Luxury Apartment A101"
description: "2+1 furnished apartment with smart lock"
price_per_day: 150.00
status: "available"
```

4. **Save** → Asset'in `id`'sini not alın (örn: `12345678-1234-5678-1234-567812345678`)

### 5.2. Device'ı Asset'e Bağlama

**SQL Editor'da çalıştırın:**

```sql
UPDATE iot_devices 
SET asset_id = '12345678-1234-5678-1234-567812345678'
WHERE device_id = 'ESP32-LIVINGROOM-001';
```

### 5.3. Doğrulama

```bash
# Device bilgisini kontrol edin
curl http://localhost:8000/api/v1/iot/devices/2
```

`asset_id` alanı dolu olmalı!

---

## 6. Mobil Uygulama Kullanımı

### 6.1. Flutter Uygulamasını Başlatma

```bash
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/mobile

# Web'de çalıştırın
flutter run -d chrome --web-port 8080
```

### 6.2. Kiralama Akışı

#### Adım 1: Login
1. Uygulamayı açın: http://localhost:8080
2. "Connect Wallet" butonu (şimdilik auth bypass)
3. Home ekranına yönlendirileceksiniz

#### Adım 2: Asset Bulma
1. **Home Screen** → Asset listesini görün
2. "Luxury Apartment A101" kartını bulun
3. Karta tıklayın → **Asset Details** sayfası

#### Adım 3: Kiralama
1. **"Rent Now"** butonuna basın
2. Tarih seçin (başlangıç ve bitiş)
3. **"Confirm Rental"**
4. ✅ Kiralama başarılı!

#### Adım 4: Kilidi Açma
1. Kiralama sonrası **"Kilidi Aç"** popup'ı çıkacak
2. **"Unlock"** butonuna basın
3. ⏳ Backend ESP32'ye komut gönderir
4. 🔓 ESP32 servo'yu çalıştırır, kilit açılır!

### 6.3. Lock Control Screen

Manuel kilit kontrolü için:

1. **Profile** → **My Rentals**
2. Aktif kiralama kartını seçin
3. **"Control Lock"** butonu
4. **Lock Control Screen** açılır:
   - 🔓 **Unlock** butonu
   - 🔒 **Lock** butonu
   - 📊 Battery, Signal, Status

---

## 7. Test ve Sorun Giderme

### 7.1. End-to-End Test

**Test Senaryosu:**

```bash
# 1. ESP32'nin online olduğunu kontrol edin
curl http://localhost:8000/api/v1/iot/devices/2

# Beklenen: "is_online": true

# 2. Manuel komut gönderin
curl -X POST http://localhost:8000/api/v1/iot/devices/2/commands \
  -H "Content-Type: application/json" \
  -d '{"command_type": "unlock", "priority": 5}'

# 3. ESP32 serial monitor'u izleyin
# Görmeli: [INFO] Executing command: unlock

# 4. Servo hareket etmeli!
```

### 7.2. Yaygın Sorunlar

#### ❌ ESP32 WiFi'ye bağlanamıyor
**Çözüm:**
- WiFi SSID ve şifresini kontrol edin
- ESP32'nin WiFi menzilinde olduğundan emin olun
- Serial monitor'da hata mesajlarını okuyun

#### ❌ ESP32 backend'e erişemiyor
**Çözüm:**
```bash
# Backend IP'sini kontrol edin
ifconfig | grep "inet "

# Firewall'u geçici olarak kapatın
# macOS: System Preferences → Security & Privacy → Firewall
```

#### ❌ Servo hareket etmiyor
**Çözüm:**
- Bağlantıları kontrol edin (özellikle GND)
- Servo'nun 5V gücü olduğundan emin olun
- GPIO 13 pin'ini test edin:
  ```python
  from machine import Pin, PWM
  servo = PWM(Pin(13), freq=50)
  servo.duty(77)  # 90 derece
  ```

#### ❌ Komut ESP32'ye ulaşmıyor
**Çözüm:**
```bash
# 1. API key'in doğru olduğundan emin olun
curl http://localhost:8000/api/v1/iot/devices/poll/sk_iot_abc123...

# 2. Device logs'u kontrol edin
curl http://localhost:8000/api/v1/iot/devices/2 | jq '.recent_activity'

# 3. ESP32 serial monitor'u kontrol edin
```

### 7.3. Backend Logs

```bash
# Backend loglarını izleyin
tail -f /tmp/backend_supabase.log

# Veya direkt terminalde çalıştırın (logları görürsünüz)
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/backend
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

## 🎯 Başarı Kriterleri

✅ **Tamamlandı:**
- [ ] ESP32 WiFi'ye bağlandı
- [ ] Backend'e heartbeat gönderiyor (is_online: true)
- [ ] Manuel komut servo'yu hareket ettiriyor
- [ ] Flutter app'den kiralama yapılıyor
- [ ] Kiralama sonrası popup çıkıyor
- [ ] Popup'tan kilit açılıyor
- [ ] Lock Control Screen çalışıyor

---

## 📱 Ekran Görüntüleri (Referans)

### Home Screen
```
┌─────────────────────────┐
│  SmartRent              │
├─────────────────────────┤
│  Available Assets       │
│                         │
│  ┌───────────────────┐  │
│  │ Apartment A101    │  │
│  │ $150/day          │  │
│  │ 🔐 Smart Lock     │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### Unlock Popup (Kiralama Sonrası)
```
┌─────────────────────────┐
│  🎉 Rental Confirmed!   │
├─────────────────────────┤
│  Would you like to      │
│  unlock the door now?   │
│                         │
│  ┌─────────┐ ┌────────┐│
│  │ Cancel  │ │ Unlock ││
│  └─────────┘ └────────┘│
└─────────────────────────┘
```

### Lock Control Screen
```
┌─────────────────────────┐
│  Lock Control           │
├─────────────────────────┤
│  Status: 🔒 Locked      │
│  Battery: 85%           │
│  Signal: ●●●○○          │
│                         │
│  ┌─────────────────┐    │
│  │   🔓 Unlock     │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │   🔒 Lock       │    │
│  └─────────────────┘    │
└─────────────────────────┘
```

---

## 🚀 İleri Seviye

### Çoklu Cihaz Yönetimi
- Her asset için ayrı ESP32
- Farklı GPIO pinleri
- Farklı API key'ler

### Güvenlik İyileştirmeleri
- HTTPS kullanımı
- API key rotation
- Command expiry
- Rate limiting

### Monitoring
- Device uptime tracking
- Battery low alerts
- Command success rate
- Response time metrics

---

## 📞 Destek

Sorun yaşarsanız:
1. Backend logs: `/tmp/backend_supabase.log`
2. ESP32 serial monitor: `screen /dev/tty.usbserial-0001 115200`
3. Supabase logs: Dashboard → Logs
4. Flutter logs: Terminal'de `flutter run` çıktısı

---

**🎉 Başarılar! Sisteminiz hazır!**


