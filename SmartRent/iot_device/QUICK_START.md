# 🚀 ESP32 Smart Lock - Hızlı Başlangıç

## 📦 1. Hazırlık (5 dakika)

### Gerekli Araçlar

```bash
# Python paketlerini yükleyin
pip install esptool adafruit-ampy
```

### Donanım Bağlantısı

```
Servo Motor       ESP32
───────────       ─────
VCC (Kırmızı) ──→ 5V
GND (Kahverengi)──→ GND
Signal (Turuncu)──→ GPIO 13
```

---

## 🔧 2. ESP32 Hazırlama (10 dakika)

### Adım 1: MicroPython Firmware

```bash
# Firmware indir
curl -o esp32-micropython.bin \
  https://micropython.org/resources/firmware/esp32-20231005-v1.21.0.bin

# Port bulma
ls /dev/tty.* | grep usb
# Örnek: /dev/tty.usbserial-0001

# Flash işlemi
PORT=/dev/tty.usbserial-0001  # Kendi portunu yaz

esptool.py --port $PORT erase_flash
esptool.py --chip esp32 --port $PORT write_flash -z 0x1000 esp32-micropython.bin
```

### Adım 2: Cihaz Kaydı

```bash
# Backend'e cihaz kaydet
curl -X POST http://localhost:8000/api/v1/iot/devices \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-TEST-001",
    "device_name": "Test Smart Lock",
    "device_type": "smart_lock",
    "firmware_version": "v2.0.0",
    "mac_address": "AA:BB:CC:DD:EE:02"
  }'
```

**📋 Çıktıdan `api_key`'i kopyala!**

### Adım 3: Kodu Düzenle

`smart_lock_servo_v2.py` dosyasını aç ve şunları düzenle:

```python
CONFIG = {
    'WIFI_SSID': 'EvWiFi',              # ← WiFi adın
    'WIFI_PASSWORD': '12345678',        # ← WiFi şifren
    'API_BASE_URL': 'http://192.168.1.100:8000/api/v1/iot',  # ← IP'n
    'API_KEY': 'sk_iot_abc123...',      # ← Backend'den aldığın key
    'DEVICE_ID': 'ESP32-TEST-001',      # ← Device ID
    # Diğer ayarlar varsayılan olabilir
}
```

**IP Adresi Nasıl Bulunur?**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
# Örnek: inet 192.168.1.100
```

### Adım 4: ESP32'ye Yükle

```bash
PORT=/dev/tty.usbserial-0001  # Kendi portunu yaz

# Kodu yükle
ampy --port $PORT put smart_lock_servo_v2.py main.py

# Reset
ampy --port $PORT reset
```

---

## 🧪 3. Test (5 dakika)

### Serial Monitor (Logları İzle)

```bash
screen /dev/tty.usbserial-0001 115200
```

**Görmeli:**
```
=== SmartRent IoT Smart Lock v2.0 ===
Device ID: ESP32-TEST-001
[SERVO] Locking...
[SERVO] Locked ✓
[WIFI] Connecting to: EvWiFi
[WIFI] Connected! IP: 192.168.1.150
[INFO] Starting main loop...
[INFO] Polling every 5s
[API] Heartbeat sent ✓
```

**Çıkmak için:** `Ctrl+A` sonra `K` sonra `Y`

### Manuel Komut Gönder

**Yeni terminal aç:**

```bash
# Device ID'yi backend'den bul
curl http://localhost:8000/api/v1/iot/devices

# Örnek çıktı:
# [{"id": 3, "device_id": "ESP32-TEST-001", ...}]
#   ^^ Bu ID'yi kullan

# Unlock komutu gönder
curl -X POST http://localhost:8000/api/v1/iot/devices/3/commands \
  -H "Content-Type: application/json" \
  -d '{"command_type": "unlock", "priority": 5}'
```

**ESP32 Serial Monitor'da:**
```
[INFO] Received 1 command(s)
[CMD] Executing: unlock (ID: 1)
[SERVO] Unlocking...
[SERVO] Unlocked ✓
[CMD] Completed: Door unlocked successfully
```

**🎉 Servo hareket etmeli!**

### Lock Komutu

```bash
curl -X POST http://localhost:8000/api/v1/iot/devices/3/commands \
  -H "Content-Type: application/json" \
  -d '{"command_type": "lock", "priority": 5}'
```

---

## 📱 4. Mobil App ile Test

### Flutter Uygulamasını Başlat

```bash
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/mobile
flutter run -d chrome --web-port 8080
```

### Asset'e Bağla

1. **Supabase Dashboard** → `assets` tablosunda bir asset ID'si bul
2. **SQL Editor:**

```sql
UPDATE iot_devices 
SET asset_id = 'ASSET_ID_BURAYA'
WHERE device_id = 'ESP32-TEST-001';
```

### Test Akışı

1. **Flutter App** → Home
2. Asset'i seç → **Rent Now**
3. Kiralama sonrası **"Kilidi Aç"** popup
4. **Unlock** butonuna bas
5. **ESP32 Serial Monitor'u izle** → Servo hareket etmeli!

---

## 🐛 Sorun Giderme

### ESP32 WiFi'ye bağlanamıyor

```python
# Serial monitor'da:
[WIFI] Connection timeout!

# Çözüm: CONFIG'de WiFi bilgilerini kontrol et
```

### Backend'e erişemiyor

```python
[API] Poll error: ...

# Çözüm 1: Backend IP'sini kontrol et
ifconfig | grep "inet "

# Çözüm 2: Backend çalışıyor mu?
curl http://localhost:8000/docs

# Çözüm 3: Firewall kapalı mı?
```

### Servo hareket etmiyor

```python
# Çözüm 1: Bağlantıları kontrol et
# Çözüm 2: GPIO pin numarasını kontrol et (CONFIG['SERVO_PIN'])
# Çözüm 3: Servo'nun gücü var mı? (5V)
```

### "Invalid API key" hatası

```bash
# Çözüm: Yeni API key al ve CONFIG'i güncelle
curl -X POST http://localhost:8000/api/v1/iot/devices \
  -H "Content-Type: application/json" \
  -d '{"device_id": "ESP32-NEW-001", ...}'
```

---

## 📊 Monitoring

### Device Status

```bash
# Device bilgisi
curl http://localhost:8000/api/v1/iot/devices/3

# Çıktı:
{
  "id": 3,
  "device_id": "ESP32-TEST-001",
  "is_online": true,        # ← Online mı?
  "lock_state": "locked",   # ← Kilit durumu
  "battery_level": 100,
  "last_seen_at": "2025-11-24T19:00:00",
  "pending_commands": 0,
  "recent_activity": [...]
}
```

### Logs

```bash
# Recent activity
curl http://localhost:8000/api/v1/iot/devices/3 | jq '.recent_activity'
```

---

## ✅ Başarı Kontrol Listesi

- [ ] ESP32 MicroPython firmware yüklendi
- [ ] Servo motor bağlandı ve test edildi
- [ ] WiFi'ye bağlanıyor
- [ ] Backend'e heartbeat gönderiyor (is_online: true)
- [ ] Manuel komut çalışıyor (servo hareket ediyor)
- [ ] Asset'e bağlandı
- [ ] Flutter app'den komut gönderilebiliyor

---

## 🎯 Sonraki Adımlar

1. **Gerçek Kilit:** Servo yerine elektrikli kilit kullanma
2. **Güvenlik:** HTTPS, API key rotation
3. **Monitoring:** Battery alerts, uptime tracking
4. **Multiple Devices:** Her asset için farklı ESP32

---

**⏱️ Toplam Süre:** ~20 dakika
**🎉 Başarılar!**


