# SmartRent IoT Device

ESP32-based smart lock controller for SmartRent platform.

## 🔌 Hardware Requirements

- ESP32 Development Board
- 5V Relay Module (for lock control)
- LED (for status indication)
- Electronic/Solenoid Lock
- Jumper Wires
- Power Supply (5V/12V depending on lock)

## 📋 Pin Configuration

```
ESP32 GPIO 2  → Relay IN (Lock Control)
ESP32 GPIO 4  → LED + (Status Indicator)
ESP32 GND     → Relay GND, LED -
ESP32 VIN/5V  → Relay VCC
```

## 🚀 Setup

### 1. Install Development Environment

**Option A: Arduino IDE**
1. Install Arduino IDE
2. Add ESP32 board support:
   - File → Preferences
   - Add to "Additional Board Manager URLs":
     ```
     https://dl.espressif.com/dl/package_esp32_index.json
     ```
   - Tools → Board → Boards Manager → Search "ESP32" → Install

**Option B: PlatformIO (Recommended)**
1. Install VS Code
2. Install PlatformIO extension
3. Create new project for ESP32

### 2. Configure WiFi and Backend

Edit `src/main.py`:

```python
WIFI_SSID = "Your_WiFi_SSID"
WIFI_PASSWORD = "Your_WiFi_Password"
BACKEND_API_URL = "http://YOUR_BACKEND_IP:8000/api/v1"
DEVICE_ID = "device_001"
DEVICE_AUTH_TOKEN = "your_device_token"
```

### 3. Upload Code

**Arduino IDE:**
- Tools → Board → ESP32 Dev Module
- Tools → Port → Select your port
- Upload

**PlatformIO:**
```bash
pio run --target upload
```

## 🔧 Development Phases

### Phase 1: Basic Lock Control
- ✅ WiFi connection
- ✅ Basic lock/unlock functions
- ✅ LED status indicator
- ✅ API polling for lock status

### Phase 2: Supabase Realtime
- [ ] Integrate Supabase client
- [ ] Subscribe to database changes
- [ ] Real-time lock control

### Phase 3: Advanced Features
- [ ] OTA updates
- [ ] Device authentication
- [ ] Local logging
- [ ] Failsafe mechanisms

## 🧪 Testing

### Test WiFi Connection
```python
# Should see "WiFi connected! IP: xxx.xxx.xxx.xxx"
```

### Test Lock Control
```python
unlock_door()  # Should hear relay click, LED turns on
lock_door()    # Should hear relay click, LED turns off
```

### Test API Communication
```python
# Check backend logs for device requests
```

## 🐛 Troubleshooting

### WiFi Won't Connect
- Check SSID and password
- Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)
- Check if network allows IoT devices

### Relay Not Clicking
- Check wiring
- Verify GPIO pin number
- Test with LED first

### API Errors
- Check backend URL
- Verify device token
- Check firewall settings

## 📝 TODO

See [DEVELOPMENT_CHECKLIST.md](../../DEVELOPMENT_CHECKLIST.md) for detailed IoT development tasks.

## 🔒 Security Notes

- Change default device token
- Use HTTPS in production
- Implement device authentication
- Keep firmware updated

## 📄 License

MIT
