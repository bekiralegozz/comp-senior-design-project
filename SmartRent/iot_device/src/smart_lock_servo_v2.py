"""
SmartRent IoT Smart Lock - ESP32 MicroPython
Servo-based smart lock with network control
Version: 2.0 (Supabase Backend Compatible)
"""

import network
import urequests
import ujson
import time
from machine import Pin, PWM

# ============================================
# CONFIGURATION - BURAYA KENDİ BİLGİLERİNİZİ GİRİN!
# ============================================

CONFIG = {
    # WiFi Settings - BURAYA KENDİ WiFi BİLGİLERİNİZİ YAZIN!
    'WIFI_SSID': 'YOUR_WIFI_NAME',              # ← WiFi adınızı yazın
    'WIFI_PASSWORD': 'YOUR_WIFI_PASSWORD',      # ← WiFi şifrenizi yazın
    
    # Backend API (bilgisayarınızın IP adresi)
    'API_BASE_URL': 'http://172.21.133.50:8000/api/v1/iot',  # ✓ Hazır
    'API_KEY': 'sk_iot_12371f4cdb748e2afca99b173db4a53097c1ae029b97249c',  # ✓ API key
    
    # Device Info
    'DEVICE_ID': 'ESP32-ROOM-101',              # ✓ Device ID
    
    # Hardware
    'SERVO_PIN': 13,                            # Servo motor GPIO pin
    'LED_PIN': 2,                               # Built-in LED (status)
    
    # Timing
    'POLL_INTERVAL': 5,                         # Komut polling aralığı (saniye)
    'HEARTBEAT_INTERVAL': 30,                   # Heartbeat aralığı (saniye)
    'WIFI_TIMEOUT': 15,                         # WiFi bağlantı timeout (saniye)
}


# ============================================
# SERVO CONTROL CLASS
# ============================================

class ServoLock:
    """Servo motor based smart lock"""
    
    # Servo positions (duty cycle values for 50Hz PWM)
    LOCKED_POSITION = 26     # 0 degrees
    UNLOCKED_POSITION = 128  # 180 degrees
    
    def __init__(self, pin):
        self.servo = PWM(Pin(pin), freq=50)
        self.state = 'locked'
        self.lock()  # Initialize to locked position
        
    def lock(self):
        """Lock the door"""
        print("[SERVO] Locking...")
        self.servo.duty(self.LOCKED_POSITION)
        time.sleep(0.5)
        self.state = 'locked'
        print("[SERVO] Locked ✓")
        
    def unlock(self):
        """Unlock the door"""
        print("[SERVO] Unlocking...")
        self.servo.duty(self.UNLOCKED_POSITION)
        time.sleep(0.5)
        self.state = 'unlocked'
        print("[SERVO] Unlocked ✓")
        
    def get_state(self):
        """Get current lock state"""
        return self.state


# ============================================
# WIFI MANAGER
# ============================================

class WiFiManager:
    """Manages WiFi connection"""
    
    def __init__(self, ssid, password):
        self.ssid = ssid
        self.password = password
        self.wlan = network.WLAN(network.STA_IF)
        
    def connect(self, timeout=15):
        """Connect to WiFi"""
        self.wlan.active(True)
        
        if self.wlan.isconnected():
            print(f"[WIFI] Already connected: {self.wlan.ifconfig()[0]}")
            return True
            
        print(f"[WIFI] Connecting to: {self.ssid}")
        self.wlan.connect(self.ssid, self.password)
        
        # Wait for connection
        start_time = time.time()
        while not self.wlan.isconnected():
            if time.time() - start_time > timeout:
                print("[WIFI] Connection timeout!")
                return False
            time.sleep(0.5)
            
        ip = self.wlan.ifconfig()[0]
        print(f"[WIFI] Connected! IP: {ip}")
        return True
        
    def is_connected(self):
        """Check if WiFi is connected"""
        return self.wlan.isconnected()
        
    def reconnect(self):
        """Try to reconnect to WiFi"""
        print("[WIFI] Reconnecting...")
        return self.connect()


# ============================================
# BACKEND API CLIENT
# ============================================

class BackendClient:
    """Communicates with SmartRent backend"""
    
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.headers = {'Content-Type': 'application/json'}
        
    def poll_commands(self):
        """Poll for pending commands"""
        try:
            url = f"{self.base_url}/devices/poll/{self.api_key}"
            response = urequests.get(url, headers=self.headers)
            
            if response.status_code == 200:
                commands = response.json()
                response.close()
                return commands
            else:
                print(f"[API] Poll failed: {response.status_code}")
                response.close()
                return []
                
        except Exception as e:
            print(f"[API] Poll error: {e}")
            return []
            
    def send_heartbeat(self, status_data):
        """Send heartbeat with device status"""
        try:
            url = f"{self.base_url}/devices/heartbeat/{self.api_key}"
            response = urequests.post(
                url, 
                data=ujson.dumps(status_data),
                headers=self.headers
            )
            
            success = response.status_code == 200
            response.close()
            
            if success:
                print("[API] Heartbeat sent ✓")
            else:
                print(f"[API] Heartbeat failed: {response.status_code}")
                
            return success
            
        except Exception as e:
            print(f"[API] Heartbeat error: {e}")
            return False
            
    def send_command_response(self, command_id, response_data):
        """Send command execution result"""
        try:
            url = f"{self.base_url}/devices/command_response/{self.api_key}"
            data = {
                'command_id': command_id,
                **response_data
            }
            
            response = urequests.post(
                url,
                data=ujson.dumps(data),
                headers=self.headers
            )
            
            success = response.status_code == 200
            response.close()
            
            return success
            
        except Exception as e:
            print(f"[API] Command response error: {e}")
            return False


# ============================================
# SMART LOCK DEVICE
# ============================================

class SmartLockDevice:
    """Main smart lock device controller"""
    
    def __init__(self, config):
        self.config = config
        
        # Initialize components
        print("=== SmartRent IoT Smart Lock v2.0 ===")
        print(f"Device ID: {config['DEVICE_ID']}")
        
        self.servo = ServoLock(config['SERVO_PIN'])
        self.led = Pin(config['LED_PIN'], Pin.OUT)
        self.wifi = WiFiManager(config['WIFI_SSID'], config['WIFI_PASSWORD'])
        self.api = BackendClient(config['API_BASE_URL'], config['API_KEY'])
        
        self.last_heartbeat = 0
        self.battery_level = 100  # Simulated
        
    def blink_led(self, times=1):
        """Blink LED for visual feedback"""
        for _ in range(times):
            self.led.on()
            time.sleep(0.1)
            self.led.off()
            time.sleep(0.1)
            
    def execute_command(self, command):
        """Execute a command from backend"""
        command_id = command['id']
        command_type = command['command_type']
        
        print(f"[CMD] Executing: {command_type} (ID: {command_id})")
        self.blink_led(2)
        
        try:
            # Execute command
            if command_type == 'unlock':
                self.servo.unlock()
                status = 'completed'
                message = 'Door unlocked successfully'
                
            elif command_type == 'lock':
                self.servo.lock()
                status = 'completed'
                message = 'Door locked successfully'
                
            elif command_type == 'status':
                status = 'completed'
                message = f"Lock status: {self.servo.get_state()}"
                
            else:
                status = 'failed'
                message = f'Unknown command: {command_type}'
                
            # Send response to backend
            response_data = {
                'status': status,
                'message': message,
                'lock_state': self.servo.get_state()
            }
            
            self.api.send_command_response(command_id, response_data)
            print(f"[CMD] Completed: {message}")
            
        except Exception as e:
            print(f"[CMD] Error: {e}")
            self.api.send_command_response(command_id, {
                'status': 'failed',
                'error': str(e)
            })
            
    def send_heartbeat(self):
        """Send periodic heartbeat"""
        current_time = time.time()
        
        if current_time - self.last_heartbeat < self.config['HEARTBEAT_INTERVAL']:
            return
            
        status_data = {
            'lock_state': self.servo.get_state(),
            'battery_level': self.battery_level,
            'signal_strength': 80  # Simulated
        }
        
        if self.api.send_heartbeat(status_data):
            self.last_heartbeat = current_time
            self.blink_led(1)
            
    def run(self):
        """Main device loop"""
        # Connect to WiFi
        if not self.wifi.connect(self.config['WIFI_TIMEOUT']):
            print("[ERROR] WiFi connection failed!")
            return
            
        self.blink_led(3)  # WiFi connected indicator
        
        print("[INFO] Starting main loop...")
        print(f"[INFO] Polling every {self.config['POLL_INTERVAL']}s")
        print(f"[INFO] Heartbeat every {self.config['HEARTBEAT_INTERVAL']}s")
        
        # Main loop
        while True:
            try:
                # Check WiFi connection
                if not self.wifi.is_connected():
                    print("[WARN] WiFi disconnected, reconnecting...")
                    if not self.wifi.reconnect():
                        time.sleep(5)
                        continue
                        
                # Send heartbeat
                self.send_heartbeat()
                
                # Poll for commands
                commands = self.api.poll_commands()
                
                if commands:
                    print(f"[INFO] Received {len(commands)} command(s)")
                    for command in commands:
                        self.execute_command(command)
                        time.sleep(0.5)  # Small delay between commands
                        
                # Wait before next poll
                time.sleep(self.config['POLL_INTERVAL'])
                
            except KeyboardInterrupt:
                print("\n[INFO] Shutting down...")
                self.servo.lock()  # Lock on shutdown
                break
                
            except Exception as e:
                print(f"[ERROR] Main loop error: {e}")
                time.sleep(5)


# ============================================
# MAIN ENTRY POINT
# ============================================

def main():
    """Main entry point"""
    try:
        device = SmartLockDevice(CONFIG)
        device.run()
    except Exception as e:
        print(f"[FATAL] Startup error: {e}")


# Auto-run on boot
if __name__ == '__main__':
    main()

