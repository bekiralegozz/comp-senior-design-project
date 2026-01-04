"""
SmartRent ESP32 Configuration
=============================

Copy this file to config.py and edit the values for your setup.

IMPORTANT: Never commit config.py with real credentials to git!
"""

# WiFi Settings
WIFI_SSID = 'YOUR_WIFI_SSID'
WIFI_PASSWORD = 'YOUR_WIFI_PASSWORD'

# Backend Settings
# For local development (find your computer's IP with `ifconfig` or `ipconfig`)
BACKEND_URL = 'http://192.168.1.100:8000'

# For Railway production (update after deploy)
# BACKEND_URL = 'https://your-app-name.up.railway.app'

# Device Identity
# Each ESP32 should have a unique DEVICE_ID
DEVICE_ID = 'ESP32-ROOM-101'
DEVICE_TYPE = 'smart_lock'
FIRMWARE_VERSION = '1.0.0'

# Timing (seconds)
HEARTBEAT_INTERVAL = 30  # How often to send status
POLL_INTERVAL = 5        # How often to check for commands

# Hardware Pins
SERVO_PIN = 13           # GPIO pin for servo signal
LED_PIN = 2              # Built-in LED (GPIO 2 on most ESP32)

# Servo Calibration
# Adjust these values based on your servo and lock mechanism
SERVO_LOCKED = 0         # Angle for locked position (0-180)
SERVO_UNLOCKED = 90      # Angle for unlocked position (0-180)
