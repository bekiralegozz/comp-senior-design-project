# 🤖 ESP32 Smart Lock Kurulum Rehberi

## ✅ Hazır Olan Bilgiler

- **Device ID:** `ESP32-ROOM-101`
- **Device Name:** `Room 101 Smart Lock`
- **API Key:** `sk_iot_12371f4cdb748e2afca99b173db4a53097c1ae029b97249c`
- **Backend URL:** `http://172.21.133.50:8000/api/v1/iot`

---

## 📝 İHTİYAÇ: WiFi Bilgileriniz

WiFi'nizin adını ve şifresini yazın:

- WiFi Adı (SSID): `__________________`
- WiFi Şifre: `__________________`

---

## 🚀 ADIM 1: ESP32 Kodunu Hazırla

Dosya: `SmartRent/iot_device/src/smart_lock_servo_v2.py`

Şu satırları bulup değiştirin:

```python
CONFIG = {
    'WIFI_SSID': 'WiFiAdınız',           # ← Buraya WiFi adınızı yazın
    'WIFI_PASSWORD': 'WiFiŞifreniz',     # ← Buraya WiFi şifrenizi yazın
    'API_BASE_URL': 'http://172.21.133.50:8000/api/v1/iot',  # ✓ Doğru
    'API_KEY': 'sk_iot_12371f4cdb748e2afca99b173db4a53097c1ae029b97249c',  # ✓ Doğru
    'DEVICE_ID': 'ESP32-ROOM-101',       # ✓ Doğru
    'SERVO_PIN': 13,                     # GPIO 13 (Servo kontrol pini)
}
```

---

## 🔌 ADIM 2: ESP32'yi Bağla

1. ESP32'yi USB ile bilgisayara bağlayın
2. Port kontrolü:

```bash
ls /dev/tty.* | grep usb
```

Port örneği: `/dev/tty.usbserial-0001`

---

## 📤 ADIM 3: Kodu ESP32'ye Yükle

### A) ampy ile yükleme (Önerilen):

```bash
# Port'u ayarlayın
export AMPY_PORT=/dev/tty.usbserial-0001  # ← Kendi portunuzu yazın
export AMPY_BAUD=115200

# Ana dosyayı yükle
ampy put SmartRent/iot_device/src/smart_lock_servo_v2.py main.py

echo "✅ Kod yüklendi!"
```

### B) esptool ile (MicroPython yoksa):

```bash
# 1. MicroPython firmware indir
curl -o esp32-micropython.bin \
  https://micropython.org/resources/firmware/esp32-20231005-v1.21.0.bin

# 2. Flash yap
PORT=/dev/tty.usbserial-0001  # ← Kendi portunuzu yazın
esptool.py --port $PORT erase_flash
esptool.py --chip esp32 --port $PORT write_flash -z 0x1000 esp32-micropython.bin

# 3. Kodu yükle (ampy ile yukarıdaki gibi)
```

---

## 🧪 ADIM 4: Test

ESP32'yi USB'den çıkarıp tekrar takın. Otomatik başlayacak.

### Serial Monitor ile Log İzle:

```bash
screen /dev/tty.usbserial-0001 115200
```

**Görmemiz gerekenler:**
```
🚀 Smart Lock v2.0.0 starting...
📡 Connecting to WiFi: YourWiFiName
✅ WiFi connected! IP: 192.168.1.100
🔐 Device: ESP32-ROOM-101
🔑 Authenticating...
✅ Authenticated!
💓 Heartbeat sent
🔍 Polling commands...
```

Çıkmak için: `Ctrl+A` sonra `K`

---

## 🌐 ADIM 5: Backend Test

Backend'den cihazı kontrol edin:

```bash
curl http://172.21.133.50:8000/api/v1/iot/devices
```

**Bakmanız gerekenler:**
```json
{
  "device_id": "ESP32-ROOM-101",
  "is_online": true,           # ← TRUE olmalı!
  "lock_state": "locked",
  "last_seen_at": "2025-11-24T..."
}
```

---

## 🔓 ADIM 6: Unlock Komutu Gönder

```bash
curl -X POST http://172.21.133.50:8000/api/v1/iot/devices/3/commands \
  -H "Content-Type: application/json" \
  -d '{
    "command_type": "unlock",
    "priority": 5
  }'
```

**ESP32 serial monitor'de göreceksiniz:**
```
🔓 UNLOCK command received!
📤 Servo unlocking...
✅ Command completed: unlock
```

**Servo motor 90° dönecek! 🎉**

---

## 🔧 Donanım Bağlantıları

```
ESP32          Servo Motor
━━━━━          ━━━━━━━━━━
GPIO 13  ───>  Signal (Sarı/Turuncu)
GND      ───>  GND (Kahverengi/Siyah)
5V/3.3V  ───>  VCC (Kırmızı)
```

---

## ❓ Sorun Giderme

### 1. WiFi'ye bağlanamıyor:
- SSID ve şifre doğru mu?
- ESP32'yi router'a yaklaştırın

### 2. Backend'e bağlanamıyor:
- `ping 172.21.133.50` çalışıyor mu?
- macOS Firewall Python'a izin veriyor mu?

### 3. "Operation not permitted" hatası:
```bash
# macOS'ta port izni
sudo chmod 666 /dev/tty.usbserial-0001
```

### 4. Servo hareket etmiyor:
- Pin bağlantıları doğru mu?
- Servo'ya güç geliyor mu? (Harici güç kaynağı gerekebilir)

---

## 🎯 Sonraki Adım

ESP32 çalışınca Flutter uygulamasından test edin:
1. Flutter web açın: http://localhost:8080
2. Login ekranından geçin (bypass aktif)
3. Bir kiralama yapın
4. "Kilidi Aç" popup'ı çıkacak
5. Unlock'a basın → ESP32'de servo dönecek! 🎉


