# 🔧 Cihaz Konfigürasyonu - Sizin Sistem İçin

## 📡 Network Bilgileri

**Bilgisayar IP:** `172.21.133.50`
**Backend URL:** `http://172.21.133.50:8000`

---

## 🚀 Hızlı Başlangıç Komutları

### 1️⃣ Backend'i Başlat

```bash
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/backend
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Test:** http://localhost:8000/docs (tarayıcıda açın)

---

### 2️⃣ Yeni Cihaz Kaydet

**WiFi bilgilerinizi not edin:**
- WiFi Adı: `_________________`
- WiFi Şifre: `_________________`

**Cihaz kaydedin:**

```bash
curl -X POST http://172.21.133.50:8000/api/v1/iot/devices \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-MYDEVICE-001",
    "device_name": "My First Smart Lock",
    "device_type": "smart_lock",
    "firmware_version": "v2.0.0",
    "mac_address": "AA:BB:CC:DD:EE:03"
  }'
```

**📋 Çıktıdan `api_key`'i kopyalayın!**

Örnek:
```json
{
  "id": 4,
  "api_key": "sk_iot_5683aac..."  ← BUNU KAYDET!
}
```

---

### 3️⃣ ESP32 Kodunu Düzenle

**`smart_lock_servo_v2.py` dosyasını açın ve şunları değiştirin:**

```python
CONFIG = {
    'WIFI_SSID': 'WiFiAdınız',           # ← Buraya WiFi adınızı yazın
    'WIFI_PASSWORD': 'WiFiŞifreniz',     # ← Buraya WiFi şifrenizi yazın
    'API_BASE_URL': 'http://172.21.133.50:8000/api/v1/iot',  # ✓ Zaten doğru
    'API_KEY': 'sk_iot_5683aac...',      # ← Buraya aldığınız API key'i yazın
    'DEVICE_ID': 'ESP32-MYDEVICE-001',   # ← Device ID
    'SERVO_PIN': 13,                     # ✓ GPIO 13
    # ... geri kalanı varsayılan
}
```

---

### 4️⃣ ESP32'ye MicroPython Yükle (İlk Kez)

```bash
# Firmware indir (sadece bir kez)
curl -o esp32-micropython.bin \
  https://micropython.org/resources/firmware/esp32-20231005-v1.21.0.bin

# Port bulma
PORT=$(ls /dev/tty.* | grep usb | head -1)
echo "Port: $PORT"

# Flash
esptool.py --port $PORT erase_flash
esptool.py --chip esp32 --port $PORT write_flash -z 0x1000 esp32-micropython.bin

echo "✅ MicroPython yüklendi!"
```

---

### 5️⃣ Kodunu ESP32'ye Yükle

```bash
# Port bulma
PORT=$(ls /dev/tty.* | grep usb | head -1)
echo "Port: $PORT"

# Dosyayı yükle
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/iot_device/src
ampy --port $PORT put smart_lock_servo_v2.py main.py

echo "✅ Kod yüklendi!"
```

---

### 6️⃣ Logları İzle

```bash
PORT=$(ls /dev/tty.* | grep usb | head -1)
screen $PORT 115200
```

**Görmeli:**
```
=== SmartRent IoT Smart Lock v2.0 ===
[WIFI] Connecting to: YourWiFi
[WIFI] Connected! IP: 172.21.xxx.xxx
[INFO] Starting main loop...
[API] Heartbeat sent ✓
```

**Çıkmak için:** `Ctrl+A` → `K` → `Y`

---

### 7️⃣ Test - Manuel Komut

**Yeni terminal aç:**

```bash
# Device ID bul (yukarıda kaydettiğin device için)
curl http://172.21.133.50:8000/api/v1/iot/devices

# Unlock komutu gönder (ID değiştir!)
curl -X POST http://172.21.133.50:8000/api/v1/iot/devices/4/commands \
  -H "Content-Type: application/json" \
  -d '{"command_type": "unlock", "priority": 5}'
```

**Servo hareket etmeli!** 🎉

---

### 8️⃣ Asset'e Bağla

1. **Supabase Dashboard** → https://supabase.com/dashboard/project/oajhrwleyhpeelbrdqdd
2. **Table Editor** → `assets`
3. Bir asset seç, `id`'sini kopyala
4. **SQL Editor:**

```sql
UPDATE iot_devices 
SET asset_id = 'ASSET_UUID_BURAYA'
WHERE device_id = 'ESP32-MYDEVICE-001';
```

---

### 9️⃣ Flutter'dan Test

```bash
# Flutter başlat
cd /Users/bekiralagoz/CursorProjects/comp-senior-design-project/SmartRent/mobile
flutter run -d chrome --web-port 8080
```

**Test:**
1. Asset listesinde cihazlı asset'i bul
2. **Rent Now** → Kiralama yap
3. **"Kilidi Aç"** popup → **Unlock**
4. 🔓 Servo hareket eder!

---

## 🐛 Sorun Giderme

### "WiFi connection failed"

```bash
# ESP32 serial monitor'da görürseniz:
[WIFI] Connection timeout!

# Çözüm: WiFi SSID ve Password'ü kontrol edin
```

### "Poll error" veya "Heartbeat failed"

```bash
# Çözüm 1: Backend çalışıyor mu?
curl http://172.21.133.50:8000/docs

# Çözüm 2: Firewall kapalı mı?
# macOS: System Preferences → Security & Privacy → Firewall

# Çözüm 3: ESP32 aynı WiFi'de mi?
# ESP32 ve bilgisayar aynı WiFi network'te olmalı!
```

### "Invalid API key"

```bash
# Yeni cihaz kaydedin ve yeni API key alın
curl -X POST http://172.21.133.50:8000/api/v1/iot/devices \
  -H "Content-Type: application/json" \
  -d '{"device_id": "ESP32-NEW-002", "device_name": "New Lock", "device_type": "smart_lock"}'
```

---

## ✅ Kontrol Listesi

- [ ] Backend çalışıyor (http://172.21.133.50:8000/docs)
- [ ] ESP32'ye MicroPython firmware yüklendi
- [ ] Servo motor bağlandı (GPIO 13)
- [ ] WiFi bilgileri CONFIG'de
- [ ] Device kayıtlı, API key alındı
- [ ] API key CONFIG'de güncellendi
- [ ] Kod ESP32'ye yüklendi
- [ ] Serial monitor'da "Connected" görünüyor
- [ ] Manuel komut servo'yu hareket ettiriyor
- [ ] Asset'e bağlandı
- [ ] Flutter'dan test başarılı

---

## 📞 Destek

**Backend Logs:**
```bash
# Terminal'de backend çalışıyorsa logları görürsünüz
# Veya:
tail -f /tmp/backend_supabase.log
```

**ESP32 Serial Monitor:**
```bash
screen $(ls /dev/tty.* | grep usb | head -1) 115200
```

**Device Status:**
```bash
# Device online mı?
curl http://172.21.133.50:8000/api/v1/iot/devices/4 | jq '{is_online, lock_state, last_seen_at}'
```

---

**🎯 Başarılar! Herhangi bir sorun olursa yukarıdaki komutları kullanın.**


