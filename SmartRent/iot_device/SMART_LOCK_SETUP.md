# 🔐 SmartRent IoT Smart Lock - Complete Setup Guide

> **Professional IoT Smart Lock System for SmartRent Platform**  
> Network-controlled servo-based lock system with real-time monitoring

---

## 📋 Table of Contents

1. [Hardware Requirements](#hardware-requirements)
2. [Hardware Setup](#hardware-setup)
3. [Software Setup](#software-setup)
4. [Backend Configuration](#backend-configuration)
5. [Device Registration](#device-registration)
6. [Testing & Debugging](#testing--debugging)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

---

## 🛠️ Hardware Requirements

### Required Components

| Component | Specification | Quantity | Purpose |
|-----------|--------------|----------|---------|
| **ESP32 Development Board** | ESP32-WROOM-32 | 1 | Main microcontroller |
| **Servo Motor** | SG90 or MG90S (5V) | 1 | Lock mechanism |
| **Power Supply** | 5V 2A USB adapter | 1 | Power for ESP32 + Servo |
| **Jumper Wires** | Male-to-Female | 3 | Connections |
| **Breadboard** (Optional) | Standard size | 1 | Prototyping |
| **Micro USB Cable** | Data + Power | 1 | Programming & Power |

### Optional Components

- **External Power Supply**: 5V 3A for heavy-duty servos
- **Capacitor**: 100µF electrolytic for servo power stabilization
- **LED Indicator**: For visual status feedback
- **3D Printed Enclosure**: For professional mounting

---

## 🔌 Hardware Setup

### Step 1: Wiring Diagram

```
ESP32              SG90 Servo Motor
-----              ----------------
GPIO 15 --------> Signal (Orange/Yellow)
5V     ---------> VCC (Red)
GND    ---------> GND (Brown/Black)

Status LED (Optional):
GPIO 2  --------> LED Anode (+)
GND     --------> LED Cathode (-) with 220Ω resistor
```

### Step 2: Physical Connections

1. **Power Connections**
   ```
   ESP32 5V Pin  →  Servo VCC (Red Wire)
   ESP32 GND Pin →  Servo GND (Brown/Black Wire)
   ```

2. **Signal Connection**
   ```
   ESP32 GPIO 15 →  Servo Signal (Orange/Yellow Wire)
   ```

3. **Power Considerations**
   - ⚠️ **Important**: Servo motors can draw significant current (up to 1A)
   - Use a **quality USB power supply** (2A minimum)
   - If servo jitters or ESP32 resets: Use **external 5V power supply**
   - Add a **100µF capacitor** across servo VCC/GND for stability

### Step 3: Mechanical Installation

1. **Servo Horn Selection**
   - Use the longest servo horn for maximum leverage
   - Attach securely with provided screw

2. **Lock Mechanism**
   - Position servo so horn can rotate freely (0° to 90°)
   - 0° = **Locked** (bolt extended)
   - 90° = **Unlocked** (bolt retracted)
   - Test mechanical movement before final installation

3. **Mounting**
   - Secure ESP32 near the lock mechanism
   - Ensure servo is firmly mounted to prevent movement
   - Keep wires organized and strain-relieved

---

## 💻 Software Setup

### Step 1: Install MicroPython on ESP32

#### Option A: Using Thonny IDE (Recommended for Beginners)

1. **Download Thonny**: https://thonny.org/
2. **Install Thonny** and open it
3. **Connect ESP32** via USB
4. **Go to**: Tools → Options → Interpreter
5. **Select**: MicroPython (ESP32)
6. **Click**: Install or Update MicroPython
7. **Choose**: Latest ESP32 firmware
8. **Click**: Install

#### Option B: Using esptool (Advanced)

```bash
# Install esptool
pip install esptool

# Download MicroPython firmware
# Visit: https://micropython.org/download/esp32/
# Download: esp32-xxxxxxxx.bin

# Erase flash
esptool.py --chip esp32 --port /dev/ttyUSB0 erase_flash

# Flash MicroPython
esptool.py --chip esp32 --port /dev/ttyUSB0 \
  --baud 460800 write_flash -z 0x1000 esp32-xxxxxxxx.bin
```

### Step 2: Install Required Libraries

MicroPython on ESP32 includes most libraries by default. Verify:

```python
# Test in REPL
>>> import network
>>> import urequests
>>> import ujson
>>> import machine
>>> from machine import Pin, PWM
```

If `urequests` is missing:

```python
import upip
upip.install('micropython-urequests')
```

### Step 3: Upload Smart Lock Code

1. **Open** `smart_lock_servo.py` in Thonny
2. **Configure** settings (see [Configuration](#step-4-configuration))
3. **Save to ESP32**: File → Save as... → Select "MicroPython device"
4. **Save as**: `main.py` (runs automatically on boot)

### Step 4: Configuration

Edit the configuration section in `smart_lock_servo.py`:

```python
# WiFi Configuration
WIFI_SSID = "Your_WiFi_Name"          # Your WiFi network name
WIFI_PASSWORD = "Your_WiFi_Password"  # Your WiFi password

# API Configuration
API_BASE_URL = "http://192.168.1.100:8000/api/v1/iot"  # Your backend IP
API_KEY = "iot_abc123..."  # Device API key (from registration)

# Device Configuration
DEVICE_ID = "ESP32_LOCK_001"  # Unique device identifier

# Servo Configuration
SERVO_PIN = 15          # GPIO pin for servo control
LOCKED_ANGLE = 0        # Servo angle when locked (0-180)
UNLOCKED_ANGLE = 90     # Servo angle when unlocked (0-180)

# Polling Configuration
POLL_INTERVAL = 3       # Check for commands every 3 seconds
HEARTBEAT_INTERVAL = 30 # Send status update every 30 seconds
```

---

## 🖥️ Backend Configuration

### Step 1: Database Setup

Run the SQL script to create IoT tables:

```bash
cd SmartRent/backend

# Copy SQL to Supabase SQL Editor
cat sql/create_iot_tables.sql

# Or run the helper script
python create_iot_tables.py
```

Then execute in **Supabase SQL Editor**:
- Go to: https://app.supabase.com/project/YOUR_PROJECT/sql
- Paste the SQL content
- Click "Run"

### Step 2: Start Backend Server

```bash
cd SmartRent/backend

# Activate virtual environment
source venv/bin/activate

# Start server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verify backend is running:
```bash
curl http://localhost:8000/ping
# Should return: {"status":"ok","message":"SmartRent Backend is running"...}
```

### Step 3: Check API Documentation

Open in browser: http://localhost:8000/docs

You should see IoT endpoints:
- `POST /api/v1/iot/devices` - Register device
- `GET /api/v1/iot/devices/poll/{api_key}` - Poll commands
- `POST /api/v1/iot/devices/heartbeat/{api_key}` - Send heartbeat
- `POST /api/v1/iot/devices/{device_id}/lock` - Control lock

---

## 🔑 Device Registration

### Method 1: Using API Documentation (Swagger UI)

1. **Open**: http://localhost:8000/docs
2. **Find**: `POST /api/v1/iot/devices`
3. **Click**: "Try it out"
4. **Fill in**:
   ```json
   {
     "device_id": "ESP32_LOCK_001",
     "device_name": "Main Entrance Lock",
     "device_type": "smart_lock",
     "asset_id": 1,
     "firmware_version": "1.0.0",
     "mac_address": "AA:BB:CC:DD:EE:FF"
   }
   ```
5. **Execute** and copy the `api_key` from response

### Method 2: Using cURL

```bash
curl -X POST http://localhost:8000/api/v1/iot/devices \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_USER_TOKEN" \
  -d '{
    "device_id": "ESP32_LOCK_001",
    "device_name": "Main Entrance Lock",
    "device_type": "smart_lock",
    "asset_id": 1,
    "firmware_version": "1.0.0",
    "mac_address": "AA:BB:CC:DD:EE:FF"
  }'
```

### Method 3: Using Python Script

```python
import requests

API_URL = "http://localhost:8000/api/v1/iot"
USER_TOKEN = "your_auth_token_here"

response = requests.post(
    f"{API_URL}/devices",
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {USER_TOKEN}"
    },
    json={
        "device_id": "ESP32_LOCK_001",
        "device_name": "Main Entrance Lock",
        "device_type": "smart_lock",
        "asset_id": 1,
        "firmware_version": "1.0.0"
    }
)

device = response.json()
print(f"Device registered! API Key: {device['api_key']}")
```

**Important**: Save the returned `api_key` - you'll need it for ESP32 configuration!

---

## 🧪 Testing & Debugging

### Step 1: Test Servo Movement

Upload and run this test script:

```python
from machine import Pin, PWM
import time

servo = PWM(Pin(15), freq=50)

# Test lock
servo.duty(26)   # 0 degrees (locked)
time.sleep(2)

# Test unlock  
servo.duty(77)   # 90 degrees (unlocked)
time.sleep(2)

# Back to lock
servo.duty(26)
```

**Expected**: Servo should move smoothly between positions.

### Step 2: Test WiFi Connection

```python
import network

wlan = network.WLAN(network.STA_IF)
wlan.active(True)
wlan.connect('YOUR_SSID', 'YOUR_PASSWORD')

# Wait and check
import time
time.sleep(5)
print(wlan.isconnected())  # Should print: True
print(wlan.ifconfig())      # Should show IP address
```

### Step 3: Test API Communication

```python
import urequests

API_KEY = "your_device_api_key"
url = f"http://192.168.1.100:8000/api/v1/iot/devices/poll/{API_KEY}"

response = urequests.get(url)
print(response.json())  # Should return command list
response.close()
```

### Step 4: Full System Test

1. **Upload** `main.py` to ESP32
2. **Reset** ESP32 (press RST button)
3. **Monitor** serial output in Thonny
4. **Send unlock command** from Flutter app or API
5. **Verify** servo moves and command is completed

---

## 🐛 Troubleshooting

### Problem: ESP32 won't connect to WiFi

**Solutions**:
- ✅ Check SSID and password (case-sensitive!)
- ✅ Verify WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- ✅ Move ESP32 closer to router
- ✅ Check if router MAC filtering is enabled
- ✅ Restart router and ESP32

### Problem: Servo jitters or doesn't move

**Solutions**:
- ✅ Use external 5V power supply (2A+)
- ✅ Add 100µF capacitor across servo power pins
- ✅ Check all connections are secure
- ✅ Verify servo is functional (test with Arduino)
- ✅ Adjust `LOCKED_ANGLE` and `UNLOCKED_ANGLE` values

### Problem: Commands not being received

**Solutions**:
- ✅ Verify API_KEY is correct
- ✅ Check backend is running (`curl http://IP:8000/ping`)
- ✅ Verify API_BASE_URL uses correct IP address
- ✅ Check firewall settings on backend server
- ✅ Monitor backend logs for errors

### Problem: ESP32 resets/reboots randomly

**Solutions**:
- ✅ **Power issue**: Use higher amp power supply
- ✅ **Brown-out**: Add capacitor for servo
- ✅ **Code error**: Check serial monitor for exceptions
- ✅ **Overheating**: Ensure adequate ventilation

### Problem: "401 Unauthorized" error

**Solutions**:
- ✅ Verify API_KEY matches registered device
- ✅ Re-register device if API key was lost
- ✅ Check backend authentication middleware

---

## ⚙️ Advanced Configuration

### Custom Servo Angles

Adjust for your specific lock mechanism:

```python
# For different servo models or lock designs
LOCKED_ANGLE = 10    # Slightly off from 0°
UNLOCKED_ANGLE = 110  # Slightly more than 90°

# For reverse operation
LOCKED_ANGLE = 90
UNLOCKED_ANGLE = 0
```

### Adjust Polling Intervals

```python
# Faster response (higher network usage)
POLL_INTERVAL = 1      # Check every 1 second
HEARTBEAT_INTERVAL = 15 # Update every 15 seconds

# Slower, battery-friendly (if using battery)
POLL_INTERVAL = 10     # Check every 10 seconds
HEARTBEAT_INTERVAL = 60 # Update every 1 minute
```

### Enable Deep Sleep (Battery Mode)

```python
from machine import deepsleep

# Sleep for 10 seconds between polls
deepsleep(10000)  # milliseconds
```

### Add Button Control (Local Override)

```python
from machine import Pin

button = Pin(4, Pin.IN, Pin.PULL_UP)

def check_button():
    if button.value() == 0:  # Button pressed
        servo.unlock()
        time.sleep(5)
        servo.lock()

# Add to main loop
while True:
    check_button()
    # ... rest of loop
```

### Multiple Servos (Multi-Point Lock)

```python
servo1 = ServoMotor(15)  # Top lock
servo2 = ServoMotor(16)  # Bottom lock

def unlock_all():
    servo1.unlock()
    servo2.unlock()

def lock_all():
    servo1.lock()
    servo2.lock()
```

---

## 📊 System Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (User Phone)   │
└────────┬────────┘
         │ HTTP/REST
         │
    ┌────▼─────────┐
    │  Backend API │
    │  (FastAPI)   │
    └────┬─────────┘
         │ HTTP/REST
         │
    ┌────▼─────────┐
    │   Supabase   │
    │   Database   │
    └──────────────┘
         ▲
         │ Commands/Status
         │
    ┌────▼─────────┐
    │    ESP32     │
    │ MicroPython  │
    └────┬─────────┘
         │ PWM Signal
         │
    ┌────▼─────────┐
    │ Servo Motor  │
    │  (SG90/MG90S)│
    └──────────────┘
```

### Communication Flow

1. **User Action**: User presses "Unlock" in Flutter app
2. **API Call**: App sends POST to `/api/v1/iot/devices/{id}/lock`
3. **Command Queue**: Backend creates command in database
4. **Device Poll**: ESP32 polls `/devices/poll/{api_key}` every 3s
5. **Command Execution**: ESP32 receives command and moves servo
6. **Status Update**: ESP32 sends completion via `/command/{id}/complete`
7. **Heartbeat**: ESP32 sends status every 30s via `/devices/heartbeat`

---

## 🔒 Security Considerations

1. **API Key Protection**
   - Never commit API keys to version control
   - Store in separate config file
   - Rotate keys periodically

2. **Network Security**
   - Use HTTPS in production
   - Implement rate limiting
   - Add command expiration (already implemented)

3. **Physical Security**
   - Secure ESP32 in tamper-proof enclosure
   - Add tamper detection sensor
   - Implement emergency manual override

4. **Access Control**
   - Verify user permissions before command execution
   - Log all lock/unlock events
   - Implement geofencing for additional security

---

## 📝 Maintenance

### Regular Tasks

- **Weekly**: Check battery level (if battery-powered)
- **Monthly**: Verify WiFi signal strength
- **Quarterly**: Update firmware if available
- **Annually**: Replace servo if worn

### Monitoring

Check device status in Flutter app:
- Online/Offline status
- Battery level
- Signal strength
- Last seen timestamp
- Recent activity log

---

## 🎯 Next Steps

1. ✅ Complete hardware assembly
2. ✅ Flash MicroPython to ESP32
3. ✅ Configure WiFi and API settings
4. ✅ Register device in backend
5. ✅ Test servo movement
6. ✅ Test API communication
7. ✅ Deploy to production location
8. ✅ Monitor and maintain

---

## 📚 Additional Resources

- **MicroPython Docs**: https://docs.micropython.org/en/latest/esp32/
- **ESP32 Pinout**: https://randomnerdtutorials.com/esp32-pinout-reference-gpios/
- **Servo Control Guide**: https://learn.adafruit.com/using-servos-with-circuitpython/
- **FastAPI Docs**: https://fastapi.tiangolo.com/
- **Supabase Docs**: https://supabase.com/docs

---

## 💬 Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review backend logs
3. Monitor ESP32 serial output
4. Contact development team

---

**Built with ❤️ by SmartRent Team**  
*Professional IoT Solutions for Modern Rental Systems*


