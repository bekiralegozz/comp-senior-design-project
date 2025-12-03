"""
SmartRent IoT Device Controller
MicroPython implementation for ESP32-based smart locks and sensors

This module provides the core functionality for IoT devices in the SmartRent ecosystem:
- Smart lock control (lock/unlock via API commands)
- Asset tracking and monitoring
- Secure communication with backend
- Battery and connectivity monitoring
- Local fallback operations
"""

import gc
import json
import time
import machine
import network
import urequests
from machine import Pin, Timer, unique_id, reset
from ubinascii import hexlify
import uhashlib
import ussl

# Configuration
class Config:
    # WiFi Configuration
    WIFI_SSID = "YOUR_WIFI_SSID"
    WIFI_PASSWORD = "YOUR_WIFI_PASSWORD"
    
    # SmartRent Backend API
    API_BASE_URL = "https://api.smartrent.com"  # Update with your backend URL
    API_VERSION = "v1"
    
    # Device Configuration
    DEVICE_TYPE = "smart_lock"  # Options: smart_lock, tracker, sensor
    DEVICE_NAME = "SmartRent Lock #001"
    UPDATE_INTERVAL = 30  # seconds
    
    # Hardware Pins (ESP32)
    LOCK_RELAY_PIN = 2
    LOCK_SENSOR_PIN = 4
    LED_PIN = 5
    BATTERY_ADC_PIN = 36
    
    # Security
    DEVICE_SECRET = "your-device-secret-key"
    
    # Fallback mode settings
    OFFLINE_MODE_TIMEOUT = 300  # 5 minutes


class SmartLockDevice:
    """Main IoT device controller for SmartRent smart locks"""
    
    def __init__(self):
        self.device_id = self._generate_device_id()
        self.is_connected = False
        self.is_locked = True
        self.last_heartbeat = 0
        self.offline_mode = False
        
        # Initialize hardware
        self.lock_relay = Pin(Config.LOCK_RELAY_PIN, Pin.OUT)
        self.lock_sensor = Pin(Config.LOCK_SENSOR_PIN, Pin.IN, Pin.PULL_UP)
        self.status_led = Pin(Config.LED_PIN, Pin.OUT)
        self.battery_adc = machine.ADC(Pin(Config.BATTERY_ADC_PIN))
        
        # Set initial state
        self.lock_relay.value(1)  # Locked by default
        self.status_led.value(0)  # LED off
        
        print(f"SmartRent Device initialized: {self.device_id}")
        
    def _generate_device_id(self):
        """Generate unique device ID based on hardware"""
        unique = hexlify(unique_id()).decode('utf-8')
        return f"sr-{Config.DEVICE_TYPE}-{unique}"
    
    def connect_wifi(self):
        """Connect to WiFi network"""
        print("Connecting to WiFi...")
        self.status_led.value(1)  # LED on during connection
        
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)
        
        if not wlan.isconnected():
            wlan.connect(Config.WIFI_SSID, Config.WIFI_PASSWORD)
            
            # Wait for connection (max 30 seconds)
            timeout = 30
            while not wlan.isconnected() and timeout > 0:
                time.sleep(1)
                timeout -= 1
                print(f"Connecting... {timeout}s remaining")
        
        if wlan.isconnected():
            self.is_connected = True
            ip_info = wlan.ifconfig()
            print(f"Connected to WiFi: {ip_info[0]}")
            self.status_led.value(0)  # LED off when connected
            return True
        else:
            print("Failed to connect to WiFi")
            self.offline_mode = True
            self._blink_error()
            return False
    
    def register_device(self):
        """Register device with SmartRent backend"""
        if not self.is_connected:
            return False
            
        try:
            url = f"{Config.API_BASE_URL}/api/{Config.API_VERSION}/iot/register"
            
            payload = {
                "device_id": self.device_id,
                "device_type": Config.DEVICE_TYPE,
                "name": Config.DEVICE_NAME,
                "firmware_version": "1.0.0",
                "hardware_version": "ESP32-v1",
            }
            
            headers = {
                "Content-Type": "application/json",
                "X-Device-Secret": Config.DEVICE_SECRET
            }
            
            response = urequests.post(url, json=payload, headers=headers)
            
            if response.status_code == 201:
                print("Device registered successfully")
                return True
            else:
                print(f"Registration failed: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"Registration error: {e}")
            return False
    
    def send_heartbeat(self):
        """Send status update to backend"""
        if not self.is_connected or self.offline_mode:
            return
            
        try:
            url = f"{Config.API_BASE_URL}/api/{Config.API_VERSION}/iot/heartbeat"
            
            payload = {
                "device_id": self.device_id,
                "is_online": True,
                "battery_level": self.get_battery_level(),
                "is_locked": self.is_locked,
                "last_seen": time.time(),
                "status": "active"
            }
            
            headers = {
                "Content-Type": "application/json",
                "X-Device-Secret": Config.DEVICE_SECRET
            }
            
            response = urequests.post(url, json=payload, headers=headers)
            
            if response.status_code == 200:
                self.last_heartbeat = time.time()
                print(f"Heartbeat sent: Battery {self.get_battery_level()}%")
                
                # Check for commands in response
                try:
                    data = response.json()
                    if 'commands' in data:
                        self._process_commands(data['commands'])
                except:
                    pass  # No JSON response or no commands
            else:
                print(f"Heartbeat failed: {response.status_code}")
                
        except Exception as e:
            print(f"Heartbeat error: {e}")
            self._check_offline_mode()
    
    def _process_commands(self, commands):
        """Process commands received from backend"""
        for command in commands:
            cmd_type = command.get('type')
            cmd_data = command.get('data', {})
            
            print(f"Processing command: {cmd_type}")
            
            if cmd_type == 'unlock':
                self.unlock()
            elif cmd_type == 'lock':
                self.lock()
            elif cmd_type == 'status':
                self.send_status_report()
            elif cmd_type == 'update_config':
                self._update_config(cmd_data)
            elif cmd_type == 'reboot':
                print("Rebooting device...")
                time.sleep(2)
                reset()
    
    def lock(self):
        """Lock the device"""
        print("Locking device...")
        self.lock_relay.value(1)
        self.is_locked = True
        self._blink_status(2)  # 2 blinks for lock
        self._log_event("locked")
    
    def unlock(self):
        """Unlock the device"""
        print("Unlocking device...")
        self.lock_relay.value(0)
        self.is_locked = False
        self._blink_status(3)  # 3 blinks for unlock
        self._log_event("unlocked")
        
        # Auto-lock after 30 seconds
        Timer(-1).init(period=30000, mode=Timer.ONE_SHOT, 
                      callback=lambda t: self.lock())
    
    def get_battery_level(self):
        """Get battery level percentage"""
        # Read ADC value and convert to percentage
        # This is a simplified calculation - adjust based on your battery setup
        adc_value = self.battery_adc.read()
        max_adc = 4095  # 12-bit ADC
        voltage = (adc_value / max_adc) * 3.3  # Convert to voltage
        
        # Convert voltage to percentage (adjust based on battery characteristics)
        if voltage >= 3.0:
            battery_percent = 100
        elif voltage >= 2.8:
            battery_percent = int((voltage - 2.8) / 0.2 * 80 + 20)
        elif voltage >= 2.5:
            battery_percent = int((voltage - 2.5) / 0.3 * 20)
        else:
            battery_percent = 0
            
        return min(100, max(0, battery_percent))
    
    def _blink_status(self, count):
        """Blink status LED"""
        for _ in range(count):
            self.status_led.value(1)
            time.sleep(0.2)
            self.status_led.value(0)
            time.sleep(0.2)
    
    def _blink_error(self):
        """Blink error pattern"""
        for _ in range(5):
            self.status_led.value(1)
            time.sleep(0.1)
            self.status_led.value(0)
            time.sleep(0.1)
    
    def _log_event(self, event):
        """Log event locally and send to backend"""
        timestamp = time.time()
        log_entry = {
            "timestamp": timestamp,
            "device_id": self.device_id,
            "event": event,
            "battery_level": self.get_battery_level()
        }
        
        print(f"Event logged: {event} at {timestamp}")
        
        # Send to backend if connected
        if self.is_connected and not self.offline_mode:
            try:
                url = f"{Config.API_BASE_URL}/api/{Config.API_VERSION}/iot/events"
                headers = {
                    "Content-Type": "application/json",
                    "X-Device-Secret": Config.DEVICE_SECRET
                }
                urequests.post(url, json=log_entry, headers=headers)
            except Exception as e:
                print(f"Failed to send event log: {e}")
    
    def _check_offline_mode(self):
        """Check if device should enter offline mode"""
        if time.time() - self.last_heartbeat > Config.OFFLINE_MODE_TIMEOUT:
            print("Entering offline mode")
            self.offline_mode = True
            self._blink_error()
    
    def send_status_report(self):
        """Send comprehensive status report"""
        status = {
            "device_id": self.device_id,
            "timestamp": time.time(),
            "is_locked": self.is_locked,
            "battery_level": self.get_battery_level(),
            "is_connected": self.is_connected,
            "offline_mode": self.offline_mode,
            "last_heartbeat": self.last_heartbeat,
            "memory_free": gc.mem_free(),
            "uptime": time.ticks_ms(),
            "lock_sensor_state": self.lock_sensor.value()
        }
        
        print("Status Report:")
        for key, value in status.items():
            print(f"  {key}: {value}")
            
        return status
    
    def run(self):
        """Main device loop"""
        print(f"Starting SmartRent Device: {self.device_id}")
        
        # Connect to WiFi
        if self.connect_wifi():
            # Register with backend
            self.register_device()
        
        # Main loop
        while True:
            try:
                # Send heartbeat every UPDATE_INTERVAL seconds
                if time.time() - self.last_heartbeat >= Config.UPDATE_INTERVAL:
                    self.send_heartbeat()
                
                # Check lock sensor (physical state vs relay state)
                sensor_state = self.lock_sensor.value()
                if (sensor_state == 0 and not self.is_locked) or \
                   (sensor_state == 1 and self.is_locked):
                    # States match, all good
                    pass
                else:
                    # States don't match, possible tampering
                    print("WARNING: Lock state mismatch detected!")
                    self._log_event("tampering_detected")
                    self._blink_error()
                
                # Check battery level
                battery = self.get_battery_level()
                if battery < 20:
                    print(f"LOW BATTERY WARNING: {battery}%")
                    self._log_event("low_battery")
                
                # Garbage collection
                gc.collect()
                
                # Sleep for a short period
                time.sleep(1)
                
            except KeyboardInterrupt:
                print("Device stopped by user")
                break
            except Exception as e:
                print(f"Error in main loop: {e}")
                time.sleep(5)  # Wait before retrying


def main():
    """Main entry point"""
    print("="*50)
    print("SmartRent IoT Device Starting...")
    print("="*50)
    
    # Create and run device
    device = SmartLockDevice()
    
    try:
        device.run()
    except Exception as e:
        print(f"Fatal error: {e}")
        device._blink_error()
        time.sleep(10)
        reset()


if __name__ == "__main__":
    main()









