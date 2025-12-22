"""
SmartRent IoT Smart Lock Controller
ESP32 + Servo Motor (SG90/MG90S)
MicroPython Implementation
"""

import network
import urequests as requests
import ujson as json
import machine
import time
from machine import Pin, PWM

# ============================================
# CONFIGURATION - CHANGE THESE VALUES
# ============================================

# WiFi Configuration
WIFI_SSID = "YOUR_WIFI_SSID"
WIFI_PASSWORD = "YOUR_WIFI_PASSWORD"

# API Configuration
API_BASE_URL = "http://192.168.1.100:8000/api/v1/iot"  # Change to your backend IP
API_KEY = "YOUR_DEVICE_API_KEY"  # Get this from device registration

# Device Configuration
DEVICE_ID = "ESP32_001"  # Unique device identifier

# Servo Configuration (SG90/MG90S)
SERVO_PIN = 15  # GPIO pin connected to servo signal wire
LOCKED_ANGLE = 0    # Angle when locked (0-180)
UNLOCKED_ANGLE = 90  # Angle when unlocked (0-180)

# Polling Configuration
POLL_INTERVAL = 3  # Seconds between command polls
HEARTBEAT_INTERVAL = 30  # Seconds between heartbeat updates

# ============================================
# Servo Control Class
# ============================================

class ServoMotor:
    """
    Controls SG90/MG90S servo motor
    - 0 degrees = 0.5ms pulse (duty ~26 for 50Hz)
    - 90 degrees = 1.5ms pulse (duty ~77 for 50Hz)  
    - 180 degrees = 2.5ms pulse (duty ~128 for 50Hz)
    """
    
    def __init__(self, pin_number):
        self.pin = Pin(pin_number, Pin.OUT)
        self.pwm = PWM(self.pin, freq=50)  # 50Hz for servo
        self.current_angle = LOCKED_ANGLE
        self.set_angle(LOCKED_ANGLE)
        
    def angle_to_duty(self, angle):
        """Convert angle (0-180) to PWM duty cycle (26-128)"""
        # Duty cycle calculation for 50Hz PWM:
        # 0° = 0.5ms = 0.5/20 = 2.5% duty = 26/1023
        # 180° = 2.5ms = 2.5/20 = 12.5% duty = 128/1023
        min_duty = 26
        max_duty = 128
        duty = int(min_duty + (angle / 180.0) * (max_duty - min_duty))
        return duty
    
    def set_angle(self, angle):
        """Set servo to specific angle (0-180)"""
        if angle < 0:
            angle = 0
        elif angle > 180:
            angle = 180
            
        duty = self.angle_to_duty(angle)
        self.pwm.duty(duty)
        self.current_angle = angle
        time.sleep(0.5)  # Give servo time to move
        
    def lock(self):
        """Move servo to locked position"""
        print(f"[SERVO] Locking... (Moving to {LOCKED_ANGLE}°)")
        self.set_angle(LOCKED_ANGLE)
        print("[SERVO] Locked!")
        
    def unlock(self):
        """Move servo to unlocked position"""
        print(f"[SERVO] Unlocking... (Moving to {UNLOCKED_ANGLE}°)")
        self.set_angle(UNLOCKED_ANGLE)
        print("[SERVO] Unlocked!")
        
    def get_state(self):
        """Get current lock state"""
        return "locked" if self.current_angle == LOCKED_ANGLE else "unlocked"
    
    def deinit(self):
        """Clean up PWM"""
        self.pwm.deinit()


# ============================================
# WiFi Connection Manager
# ============================================

class WiFiManager:
    """Manages WiFi connection"""
    
    def __init__(self, ssid, password):
        self.ssid = ssid
        self.password = password
        self.wlan = network.WLAN(network.STA_IF)
        
    def connect(self, timeout=30):
        """Connect to WiFi network"""
        print(f"[WIFI] Connecting to {self.ssid}...")
        
        self.wlan.active(True)
        self.wlan.connect(self.ssid, self.password)
        
        start_time = time.time()
        while not self.wlan.isconnected():
            if time.time() - start_time > timeout:
                print("[WIFI] Connection timeout!")
                return False
            time.sleep(1)
            print(".", end="")
        
        print(f"\n[WIFI] Connected! IP: {self.wlan.ifconfig()[0]}")
        print(f"[WIFI] Signal Strength: {self.wlan.status('rssi')} dBm")
        return True
    
    def is_connected(self):
        """Check if connected to WiFi"""
        return self.wlan.isconnected()
    
    def get_ip(self):
        """Get device IP address"""
        if self.wlan.isconnected():
            return self.wlan.ifconfig()[0]
        return None
    
    def get_signal_strength(self):
        """Get WiFi signal strength in dBm"""
        if self.wlan.isconnected():
            return self.wlan.status('rssi')
        return -100


# ============================================
# API Communication Manager
# ============================================

class APIManager:
    """Handles communication with backend API"""
    
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        
    def poll_commands(self):
        """Poll for pending commands from server"""
        try:
            url = f"{self.base_url}/devices/poll/{self.api_key}"
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                response.close()
                return data.get("commands", [])
            else:
                print(f"[API] Poll failed: {response.status_code}")
                response.close()
                return []
                
        except Exception as e:
            print(f"[API] Poll error: {e}")
            return []
    
    def send_heartbeat(self, lock_state, battery_level, signal_strength, ip_address):
        """Send heartbeat with device status"""
        try:
            url = f"{self.base_url}/devices/heartbeat/{self.api_key}"
            payload = {
                "lock_state": lock_state,
                "battery_level": battery_level,
                "signal_strength": signal_strength,
                "ip_address": ip_address
            }
            
            response = requests.post(
                url,
                headers={"Content-Type": "application/json"},
                data=json.dumps(payload),
                timeout=10
            )
            
            if response.status_code == 200:
                print("[API] Heartbeat sent successfully")
                response.close()
                return True
            else:
                print(f"[API] Heartbeat failed: {response.status_code}")
                response.close()
                return False
                
        except Exception as e:
            print(f"[API] Heartbeat error: {e}")
            return False
    
    def complete_command(self, command_id, status, error=None):
        """Mark a command as completed"""
        try:
            url = f"{self.base_url}/devices/command/{command_id}/complete"
            payload = {
                "api_key": self.api_key,
                "status": status,
                "data": {"timestamp": time.time()},
                "error": error
            }
            
            response = requests.post(
                url,
                headers={"Content-Type": "application/json"},
                data=json.dumps(payload),
                timeout=10
            )
            
            if response.status_code == 200:
                print(f"[API] Command {command_id} marked as {status}")
                response.close()
                return True
            else:
                print(f"[API] Command completion failed: {response.status_code}")
                response.close()
                return False
                
        except Exception as e:
            print(f"[API] Command completion error: {e}")
            return False


# ============================================
# Smart Lock Controller (Main Class)
# ============================================

class SmartLockController:
    """Main controller for smart lock system"""
    
    def __init__(self):
        print("=" * 50)
        print("SmartRent IoT Smart Lock Controller")
        print(f"Device ID: {DEVICE_ID}")
        print("=" * 50)
        
        # Initialize components
        self.servo = ServoMotor(SERVO_PIN)
        self.wifi = WiFiManager(WIFI_SSID, WIFI_PASSWORD)
        self.api = APIManager(API_BASE_URL, API_KEY)
        
        # State tracking
        self.last_poll_time = 0
        self.last_heartbeat_time = 0
        self.battery_level = 100  # Mock battery level (if using battery)
        
        # Built-in LED for status indication
        self.status_led = Pin(2, Pin.OUT)  # GPIO 2 is built-in LED on most ESP32
        
    def blink_led(self, times=1, delay=0.1):
        """Blink status LED"""
        for _ in range(times):
            self.status_led.on()
            time.sleep(delay)
            self.status_led.off()
            time.sleep(delay)
    
    def connect_wifi(self):
        """Connect to WiFi with retry logic"""
        max_retries = 3
        for attempt in range(max_retries):
            if self.wifi.connect():
                self.blink_led(3, 0.2)  # 3 quick blinks = success
                return True
            print(f"[WIFI] Retry {attempt + 1}/{max_retries}")
            time.sleep(5)
        
        print("[WIFI] Failed to connect after retries")
        return False
    
    def execute_command(self, command):
        """Execute a received command"""
        command_id = command.get("id")
        command_type = command.get("command_type")
        
        print(f"[COMMAND] Executing: {command_type} (ID: {command_id})")
        
        try:
            if command_type == "unlock":
                self.servo.unlock()
                self.api.complete_command(command_id, "completed")
                self.blink_led(2, 0.3)  # 2 blinks = unlocked
                
            elif command_type == "lock":
                self.servo.lock()
                self.api.complete_command(command_id, "completed")
                self.blink_led(1, 0.5)  # 1 long blink = locked
                
            elif command_type == "status":
                # Just acknowledge status request
                self.api.complete_command(command_id, "completed")
                
            else:
                print(f"[COMMAND] Unknown command type: {command_type}")
                self.api.complete_command(command_id, "failed", error="Unknown command")
                
        except Exception as e:
            print(f"[COMMAND] Execution error: {e}")
            self.api.complete_command(command_id, "failed", error=str(e))
    
    def poll_for_commands(self):
        """Poll API for pending commands"""
        current_time = time.time()
        
        if current_time - self.last_poll_time >= POLL_INTERVAL:
            self.last_poll_time = current_time
            
            commands = self.api.poll_commands()
            
            if commands:
                print(f"[POLL] Received {len(commands)} command(s)")
                for command in commands:
                    self.execute_command(command)
            else:
                print("[POLL] No pending commands")
    
    def send_heartbeat(self):
        """Send periodic heartbeat to API"""
        current_time = time.time()
        
        if current_time - self.last_heartbeat_time >= HEARTBEAT_INTERVAL:
            self.last_heartbeat_time = current_time
            
            lock_state = self.servo.get_state()
            signal_strength = self.wifi.get_signal_strength()
            ip_address = self.wifi.get_ip()
            
            print(f"[HEARTBEAT] Lock: {lock_state}, Signal: {signal_strength} dBm")
            
            self.api.send_heartbeat(
                lock_state=lock_state,
                battery_level=self.battery_level,
                signal_strength=signal_strength,
                ip_address=ip_address
            )
    
    def run(self):
        """Main control loop"""
        print("\n[SYSTEM] Initializing...")
        
        # Connect to WiFi
        if not self.connect_wifi():
            print("[SYSTEM] Cannot run without WiFi!")
            return
        
        print("[SYSTEM] Starting main loop...")
        print(f"[SYSTEM] Poll interval: {POLL_INTERVAL}s, Heartbeat interval: {HEARTBEAT_INTERVAL}s")
        
        # Initial heartbeat
        self.send_heartbeat()
        
        # Main loop
        try:
            while True:
                # Check WiFi connection
                if not self.wifi.is_connected():
                    print("[SYSTEM] WiFi disconnected! Reconnecting...")
                    self.connect_wifi()
                
                # Poll for commands
                self.poll_for_commands()
                
                # Send heartbeat
                self.send_heartbeat()
                
                # Small delay to prevent tight loop
                time.sleep(0.5)
                
        except KeyboardInterrupt:
            print("\n[SYSTEM] Shutting down...")
            self.servo.deinit()
            self.status_led.off()
            print("[SYSTEM] Goodbye!")


# ============================================
# MAIN ENTRY POINT
# ============================================

def main():
    """Main entry point"""
    try:
        controller = SmartLockController()
        controller.run()
    except Exception as e:
        print(f"[ERROR] Fatal error: {e}")
        import sys
        sys.print_exception(e)


if __name__ == "__main__":
    main()


