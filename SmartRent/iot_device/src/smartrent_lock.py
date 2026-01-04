"""
SmartRent ESP32 Smart Lock Controller
=====================================

This firmware runs on ESP32 and controls a servo-based door lock.
It communicates with the SmartRent backend via HTTP polling.

Hardware Setup:
- ESP32 DevKit
- Servo motor on GPIO 13
- Optional: LED on GPIO 2 (built-in)

Communication Flow:
1. Boot -> Connect WiFi -> Register with backend
2. Loop: Send heartbeat (30s) + Poll commands (5s)
3. Execute lock/unlock commands via servo

Author: SmartRent Team
Version: 1.0.0
"""

import network
import urequests
import ujson
import time
import machine
from machine import Pin, PWM

# ============================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================

CONFIG = {
    # WiFi Settings
    'WIFI_SSID': 'Berk',
    'WIFI_PASSWORD': 'Berk1234',
    
    # Backend Settings
    # Local development:
    # 'BACKEND_URL': 'http://192.168.1.100:8000',
    # Railway production:
    'BACKEND_URL': 'https://lucky-beauty-production-e86e.up.railway.app',
    
    # Device Identity
    'DEVICE_ID': 'SmartLocak-001',
    'DEVICE_TYPE': 'smart_lock',
    'FIRMWARE_VERSION': '1.0.0',
    
    # Timing (seconds)
    'HEARTBEAT_INTERVAL': 30,
    'POLL_INTERVAL': 5,
    'WIFI_RETRY_DELAY': 5,
    
    # Hardware Pins
    'SERVO_PIN': 13,
    'LED_PIN': 2,
    
    # Servo Angles (adjust for your servo)
    'SERVO_LOCKED': 0,      # Locked position (degrees)
    'SERVO_UNLOCKED': 90,   # Unlocked position (degrees)
}

# ============================================
# HARDWARE SETUP
# ============================================

# Built-in LED for status indication
led = Pin(CONFIG['LED_PIN'], Pin.OUT)

# Servo PWM setup
servo = PWM(Pin(CONFIG['SERVO_PIN']))
servo.freq(50)  # 50Hz for servo

# Current lock state
lock_state = "locked"

# ============================================
# UTILITY FUNCTIONS
# ============================================

def blink_led(times=1, interval=0.2):
    """Blink LED for visual feedback"""
    for _ in range(times):
        led.value(1)
        time.sleep(interval)
        led.value(0)
        time.sleep(interval)

def set_servo_angle(angle):
    """
    Set servo angle (0-180 degrees)
    Converts angle to PWM duty cycle
    """
    # Map 0-180 degrees to duty cycle
    # Most servos: 0.5ms (0°) to 2.5ms (180°) pulse width
    # At 50Hz: period = 20ms
    # Duty: 0.5ms/20ms = 2.5% to 2.5ms/20ms = 12.5%
    # ESP32 duty range: 0-1023
    min_duty = 26   # ~2.5% of 1023
    max_duty = 128  # ~12.5% of 1023
    
    duty = int(min_duty + (angle / 180) * (max_duty - min_duty))
    servo.duty(duty)

def lock_door():
    """Lock the door"""
    global lock_state
    print("[LOCK] Locking door...")
    set_servo_angle(CONFIG['SERVO_LOCKED'])
    lock_state = "locked"
    blink_led(1)
    print("[LOCK] Door locked")

def unlock_door(duration=5):
    """
    Unlock the door temporarily
    Auto-locks after duration seconds
    """
    global lock_state
    print(f"[UNLOCK] Unlocking door for {duration} seconds...")
    set_servo_angle(CONFIG['SERVO_UNLOCKED'])
    lock_state = "unlocked"
    blink_led(3, 0.1)
    
    # Auto-lock after duration
    time.sleep(duration)
    lock_door()

# ============================================
# NETWORK FUNCTIONS
# ============================================

def connect_wifi():
    """Connect to WiFi network"""
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if wlan.isconnected():
        print(f"[WIFI] Already connected: {wlan.ifconfig()[0]}")
        return wlan
    
    print(f"[WIFI] Connecting to {CONFIG['WIFI_SSID']}...")
    wlan.connect(CONFIG['WIFI_SSID'], CONFIG['WIFI_PASSWORD'])
    
    # Wait for connection with timeout
    max_wait = 20
    while max_wait > 0:
        if wlan.isconnected():
            break
        max_wait -= 1
        print(f"[WIFI] Waiting... ({max_wait})")
        blink_led(1, 0.1)
        time.sleep(1)
    
    if wlan.isconnected():
        ip = wlan.ifconfig()[0]
        print(f"[WIFI] Connected! IP: {ip}")
        blink_led(3, 0.1)
        return wlan
    else:
        print("[WIFI] Connection failed!")
        return None

def get_signal_strength():
    """Get WiFi signal strength (RSSI)"""
    try:
        wlan = network.WLAN(network.STA_IF)
        return wlan.status('rssi')
    except:
        return None

def get_ip_address():
    """Get current IP address"""
    try:
        wlan = network.WLAN(network.STA_IF)
        return wlan.ifconfig()[0]
    except:
        return None

# ============================================
# BACKEND API FUNCTIONS
# ============================================

def api_request(method, endpoint, data=None):
    """Make HTTP request to backend"""
    url = f"{CONFIG['BACKEND_URL']}{endpoint}"
    headers = {'Content-Type': 'application/json'}
    
    try:
        if method == 'GET':
            response = urequests.get(url, headers=headers)
        elif method == 'POST':
            response = urequests.post(url, data=ujson.dumps(data), headers=headers)
        else:
            return None
        
        result = response.json()
        response.close()
        return result
    except Exception as e:
        print(f"[API] Error: {e}")
        return None

def register_device():
    """Register device with backend"""
    print("[API] Registering device...")
    
    data = {
        'device_id': CONFIG['DEVICE_ID'],
        'device_type': CONFIG['DEVICE_TYPE'],
        'firmware_version': CONFIG['FIRMWARE_VERSION']
    }
    
    result = api_request('POST', '/api/v1/iot/devices/register', data)
    
    if result and result.get('status') == 'registered':
        print(f"[API] Registered: {result.get('message')}")
        return True
    else:
        print(f"[API] Registration failed: {result}")
        return False

def send_heartbeat():
    """Send heartbeat to backend"""
    data = {
        'device_id': CONFIG['DEVICE_ID'],
        'lock_state': lock_state,
        'battery_level': 100,  # ESP32 doesn't have battery
        'signal_strength': get_signal_strength(),
        'ip_address': get_ip_address()
    }
    
    result = api_request('POST', '/api/v1/iot/devices/heartbeat', data)
    
    if result:
        print(f"[HEARTBEAT] OK - Server time: {result.get('server_time', 'N/A')}")
        return True
    else:
        print("[HEARTBEAT] Failed")
        return False

def poll_commands():
    """Poll for pending commands"""
    result = api_request('GET', f'/api/v1/iot/devices/poll/{CONFIG["DEVICE_ID"]}')
    
    if result:
        commands = result.get('commands', [])
        if commands:
            print(f"[POLL] Received {len(commands)} command(s)")
        return commands
    return []

def report_command_complete(command_id, status, message=None):
    """Report command completion to backend"""
    data = {
        'device_id': CONFIG['DEVICE_ID'],
        'command_id': command_id,
        'status': status,
        'message': message
    }
    
    api_request('POST', '/api/v1/iot/devices/command/complete', data)

# ============================================
# COMMAND HANDLERS
# ============================================

def handle_command(command):
    """Handle a single command from backend"""
    cmd_type = command.get('type')
    cmd_id = command.get('command_id')
    cmd_data = command.get('data', {})
    
    print(f"[CMD] Executing: {cmd_type} (ID: {cmd_id})")
    
    try:
        if cmd_type == 'unlock':
            duration = cmd_data.get('duration', 5)
            unlock_door(duration)
            report_command_complete(cmd_id, 'success', 'Door unlocked')
            
        elif cmd_type == 'lock':
            lock_door()
            report_command_complete(cmd_id, 'success', 'Door locked')
            
        elif cmd_type == 'status':
            # Just report current status
            report_command_complete(cmd_id, 'success', f'State: {lock_state}')
            
        else:
            print(f"[CMD] Unknown command type: {cmd_type}")
            report_command_complete(cmd_id, 'failed', f'Unknown command: {cmd_type}')
            
    except Exception as e:
        print(f"[CMD] Error: {e}")
        report_command_complete(cmd_id, 'failed', str(e))

# ============================================
# MAIN LOOP
# ============================================

def main():
    """Main entry point"""
    print("\n" + "=" * 50)
    print("  SmartRent ESP32 Smart Lock Controller")
    print("=" * 50)
    print(f"  Device ID: {CONFIG['DEVICE_ID']}")
    print(f"  Backend:   {CONFIG['BACKEND_URL']}")
    print(f"  Firmware:  {CONFIG['FIRMWARE_VERSION']}")
    print("=" * 50 + "\n")
    
    # Initialize lock in locked position
    lock_door()
    
    # Connect to WiFi
    wlan = None
    while not wlan:
        wlan = connect_wifi()
        if not wlan:
            print(f"[WIFI] Retrying in {CONFIG['WIFI_RETRY_DELAY']}s...")
            time.sleep(CONFIG['WIFI_RETRY_DELAY'])
    
    # Register with backend
    while not register_device():
        print(f"[API] Retrying registration in {CONFIG['WIFI_RETRY_DELAY']}s...")
        time.sleep(CONFIG['WIFI_RETRY_DELAY'])
    
    # Main loop
    last_heartbeat = 0
    last_poll = 0
    
    print("\n[MAIN] Entering main loop...")
    print(f"[MAIN] Heartbeat every {CONFIG['HEARTBEAT_INTERVAL']}s")
    print(f"[MAIN] Poll every {CONFIG['POLL_INTERVAL']}s\n")
    
    while True:
        try:
            current_time = time.time()
            
            # Check WiFi connection
            if not network.WLAN(network.STA_IF).isconnected():
                print("[WIFI] Connection lost, reconnecting...")
                connect_wifi()
                continue
            
            # Send heartbeat
            if current_time - last_heartbeat >= CONFIG['HEARTBEAT_INTERVAL']:
                send_heartbeat()
                last_heartbeat = current_time
            
            # Poll for commands
            if current_time - last_poll >= CONFIG['POLL_INTERVAL']:
                commands = poll_commands()
                for cmd in commands:
                    handle_command(cmd)
                last_poll = current_time
            
            # Small delay to prevent CPU hogging
            time.sleep(0.5)
            
        except KeyboardInterrupt:
            print("\n[MAIN] Shutting down...")
            break
        except Exception as e:
            print(f"[MAIN] Error: {e}")
            time.sleep(5)

# Run main
if __name__ == "__main__":
    main()
