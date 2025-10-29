# SmartRent IoT Device

MicroPython-based IoT device controller for ESP32 smart locks and sensors in the SmartRent ecosystem.

## Overview

This module provides the firmware for IoT devices that integrate with the SmartRent platform:

- **Smart Locks**: Remote lock/unlock control via API
- **Asset Tracking**: Real-time location and status monitoring  
- **Secure Communication**: Encrypted communication with backend
- **Local Intelligence**: Fallback operations when offline
- **Battery Monitoring**: Power management and alerts

## Hardware Requirements

### Recommended Hardware
- **ESP32 Development Board** (ESP32-DevKit-V1 or similar)
- **Relay Module** (5V/3.3V compatible for lock control)
- **Magnetic Reed Switch** (for lock position sensing)  
- **LED Indicator** (status indication)
- **Battery Pack** (3.7V Li-ion with charging circuit)
- **Enclosure** (weatherproof for outdoor use)

### Pin Configuration (ESP32)
```
GPIO 2  - Lock Relay Control
GPIO 4  - Lock Position Sensor
GPIO 5  - Status LED
GPIO 36 - Battery Level (ADC)
```

## Features

### Core Functionality
- ✅ **Remote Control**: Lock/unlock via SmartRent backend
- ✅ **Status Monitoring**: Real-time device status reporting
- ✅ **Battery Management**: Level monitoring with low battery alerts
- ✅ **Connectivity**: WiFi with automatic reconnection
- ✅ **Security**: Secure API authentication
- ✅ **Local Fallback**: Continues operation when offline

### Smart Features
- 🔒 **Auto-lock**: Automatic locking after configurable timeout
- 🚨 **Tampering Detection**: Alerts when physical/digital states mismatch
- 📊 **Usage Analytics**: Track lock/unlock events and patterns
- 🔋 **Power Optimization**: Sleep modes and efficient operation
- 📡 **OTA Updates**: Over-the-air firmware updates (planned)

## Quick Start

### 1. Hardware Setup

1. **Connect the Relay Module**:
   ```
   ESP32 GPIO2 → Relay IN
   ESP32 5V    → Relay VCC
   ESP32 GND   → Relay GND
   ```

2. **Connect Lock Position Sensor**:
   ```
   ESP32 GPIO4 → Reed Switch Terminal 1
   ESP32 GND   → Reed Switch Terminal 2 (with pull-up)
   ```

3. **Connect Status LED**:
   ```
   ESP32 GPIO5 → LED Anode (through 330Ω resistor)
   ESP32 GND   → LED Cathode
   ```

4. **Connect Battery Monitor**:
   ```
   ESP32 GPIO36 → Battery + (through voltage divider if needed)
   ```

### 2. Software Setup

1. **Install MicroPython on ESP32**:
   ```bash
   # Erase flash
   esptool.py --chip esp32 erase_flash
   
   # Flash MicroPython firmware
   esptool.py --chip esp32 write_flash -z 0x1000 esp32-micropython.bin
   ```

2. **Upload the SmartRent IoT Code**:
   ```bash
   # Using ampy tool
   ampy --port /dev/ttyUSB0 put main.py
   
   # Or using your preferred MicroPython IDE (Thonny, etc.)
   ```

3. **Configure Device Settings**:
   
   Edit the configuration in `main.py`:
   ```python
   class Config:
       # WiFi Configuration
       WIFI_SSID = "your_wifi_network"
       WIFI_PASSWORD = "your_wifi_password"
       
       # SmartRent Backend API
       API_BASE_URL = "https://your-backend-url.com"
       
       # Device Configuration  
       DEVICE_NAME = "SmartRent Lock #001"
       DEVICE_SECRET = "your-device-secret-key"
   ```

### 3. Device Registration

1. **Power on the ESP32** - it will automatically:
   - Connect to WiFi
   - Register with the SmartRent backend
   - Start sending heartbeat messages

2. **Verify Registration** in the SmartRent backend logs:
   ```
   Device registered successfully: sr-smart_lock-abc123
   ```

3. **Test Remote Control** via the mobile app or API

## API Integration

The device communicates with the SmartRent backend through secure REST APIs:

### Device Registration
```http
POST /api/v1/iot/register
Content-Type: application/json
X-Device-Secret: your-device-secret

{
  "device_id": "sr-smart_lock-abc123",
  "device_type": "smart_lock", 
  "name": "SmartRent Lock #001",
  "firmware_version": "1.0.0"
}
```

### Heartbeat/Status Updates
```http
POST /api/v1/iot/heartbeat
Content-Type: application/json
X-Device-Secret: your-device-secret

{
  "device_id": "sr-smart_lock-abc123",
  "is_online": true,
  "battery_level": 85,
  "is_locked": true,
  "last_seen": 1640995200
}
```

### Remote Commands
The backend can send commands in heartbeat responses:
```json
{
  "commands": [
    {"type": "unlock", "data": {}},
    {"type": "lock", "data": {}},
    {"type": "status", "data": {}}
  ]
}
```

## Device States

### Lock States
- **Locked** (`is_locked = True`): Device is securely locked
- **Unlocked** (`is_locked = False`): Device is unlocked (temporary state)

### Connection States  
- **Online**: Connected to WiFi and communicating with backend
- **Offline**: WiFi connected but backend unreachable
- **Offline Mode**: No connectivity, operating with local intelligence

### Status Indicators (LED)
- **Solid Off**: Normal operation, connected
- **Slow Blink**: Connecting to WiFi
- **Fast Blink**: Error state or tampering detected
- **2 Blinks**: Lock activated
- **3 Blinks**: Unlock activated

## Security Features

### Communication Security
- **Device Authentication**: Unique device ID + secret key
- **HTTPS**: All API communication encrypted
- **Command Validation**: Commands verified before execution

### Physical Security
- **Tampering Detection**: Monitors physical vs digital lock states
- **Secure Boot**: (Planned) Verified boot process
- **Encrypted Storage**: (Planned) Sensitive data encryption

### Operational Security
- **Auto-lock**: Automatic locking after timeout
- **Battery Alerts**: Low power notifications
- **Offline Resilience**: Continues operation without connectivity

## Troubleshooting

### Common Issues

**Device Won't Connect to WiFi**
```
1. Check SSID and password in Config
2. Verify WiFi signal strength
3. Check for 2.4GHz network (ESP32 doesn't support 5GHz)
4. Reset device and try again
```

**Registration Failed**
```
1. Verify API_BASE_URL is correct
2. Check DEVICE_SECRET matches backend configuration  
3. Ensure backend is accessible from device network
4. Check backend logs for error details
```

**Lock Not Responding**
```
1. Check relay wiring and power supply
2. Verify GPIO pin configuration
3. Test relay manually with multimeter
4. Check for loose connections
```

**Battery Draining Quickly**
```
1. Check for excessive WiFi reconnections
2. Verify sleep modes are working
3. Check for hardware shorts
4. Consider power optimization settings
```

### Debug Mode

Enable debug output by modifying the main loop:
```python
# Add debug prints
def run(self):
    DEBUG = True  # Set to True for verbose output
    
    while True:
        if DEBUG:
            print(f"Battery: {self.get_battery_level()}%")
            print(f"Lock State: {'Locked' if self.is_locked else 'Unlocked'}")
            print(f"WiFi: {'Connected' if self.is_connected else 'Disconnected'}")
```

### Serial Monitor

Connect to the device serial port to see real-time logs:
```bash
# Linux/Mac
screen /dev/ttyUSB0 115200

# Windows  
putty -serial COM3 -sercfg 115200,8,n,1,N
```

## Development

### Adding New Features

1. **Create Feature Branch**:
   ```bash
   git checkout -b feature/new-sensor-support
   ```

2. **Add New Device Type**:
   ```python
   class Config:
       DEVICE_TYPE = "temperature_sensor"  # New type
   
   class TemperatureSensor(SmartLockDevice):
       def read_temperature(self):
           # Implementation
           pass
   ```

3. **Update API Integration**:
   ```python
   def send_sensor_data(self, temperature):
       payload = {
           "device_id": self.device_id,
           "sensor_type": "temperature", 
           "value": temperature,
           "timestamp": time.time()
       }
       # Send to backend
   ```

### Testing

**Unit Testing** (on development machine):
```python
# test_device.py
import unittest
from unittest.mock import Mock, patch

class TestSmartLockDevice(unittest.TestCase):
    def test_device_initialization(self):
        device = SmartLockDevice()
        self.assertIsNotNone(device.device_id)
        
    def test_lock_unlock_cycle(self):
        device = SmartLockDevice()
        device.unlock()
        self.assertFalse(device.is_locked)
        device.lock() 
        self.assertTrue(device.is_locked)
```

**Integration Testing** (on actual hardware):
```python
# Deploy test firmware with additional test endpoints
def test_mode(self):
    self.lock()
    time.sleep(1)
    self.unlock()
    time.sleep(1) 
    self.send_status_report()
```

## Production Deployment

### Security Checklist
- [ ] Change default DEVICE_SECRET
- [ ] Use production API endpoints
- [ ] Enable HTTPS certificate verification
- [ ] Implement secure boot (if available)
- [ ] Set up OTA update mechanism
- [ ] Configure proper logging levels

### Monitoring Setup
- [ ] Backend monitoring for device health
- [ ] Battery level alerts
- [ ] Connectivity monitoring  
- [ ] Usage analytics dashboard
- [ ] Automated alerting for issues

### Maintenance
- [ ] Regular firmware updates
- [ ] Battery replacement schedule
- [ ] Physical inspection routine
- [ ] Performance optimization reviews

## Contributing

1. Follow MicroPython coding standards
2. Add comprehensive error handling
3. Include docstrings for all functions
4. Test on actual ESP32 hardware
5. Update documentation for new features

## License

This IoT device firmware is part of the SmartRent project.

## Support

For technical support:
- Check the troubleshooting section above
- Review device logs via serial connection
- Contact SmartRent technical support
- Submit issues on the project repository








