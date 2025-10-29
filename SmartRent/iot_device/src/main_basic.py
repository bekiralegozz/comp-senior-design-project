"""
ESP32 Smart Lock - Main Entry Point
SmartRent IoT Device

This script runs on ESP32 to control a smart lock remotely
via backend API and Supabase Realtime.
"""

import time
import network
import urequests
from machine import Pin

# ============= CONFIGURATION =============
WIFI_SSID = "YOUR_WIFI_SSID"
WIFI_PASSWORD = "YOUR_WIFI_PASSWORD"

BACKEND_API_URL = "http://YOUR_BACKEND_IP:8000/api/v1"
DEVICE_ID = "device_001"
DEVICE_AUTH_TOKEN = "YOUR_DEVICE_AUTH_TOKEN"

# Supabase Configuration
SUPABASE_URL = "https://your-project.supabase.co"
SUPABASE_KEY = "your-supabase-anon-key"

# Hardware Configuration
LOCK_PIN = 2  # GPIO pin for lock control (relay)
STATUS_LED_PIN = 4  # GPIO pin for status LED

# ============= HARDWARE SETUP =============
lock_relay = Pin(LOCK_PIN, Pin.OUT)
status_led = Pin(STATUS_LED_PIN, Pin.OUT)

# Initialize lock to locked state
lock_relay.value(0)
status_led.value(0)

# ============= WIFI CONNECTION =============
def connect_wifi():
    """Connect to WiFi network"""
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if not wlan.isconnected():
        print(f"Connecting to WiFi: {WIFI_SSID}")
        wlan.connect(WIFI_SSID, WIFI_PASSWORD)
        
        # Wait for connection
        timeout = 20
        while not wlan.isconnected() and timeout > 0:
            print(".", end="")
            time.sleep(1)
            timeout -= 1
        
        if wlan.isconnected():
            print(f"\nWiFi connected! IP: {wlan.ifconfig()[0]}")
            # Blink LED to indicate connection
            for _ in range(3):
                status_led.value(1)
                time.sleep(0.2)
                status_led.value(0)
                time.sleep(0.2)
            return True
        else:
            print("\nFailed to connect to WiFi")
            return False
    else:
        print("Already connected to WiFi")
        return True

# ============= LOCK CONTROL =============
def unlock_door():
    """Unlock the door"""
    print("🔓 Unlocking door...")
    lock_relay.value(1)
    status_led.value(1)
    print("Door unlocked!")

def lock_door():
    """Lock the door"""
    print("🔒 Locking door...")
    lock_relay.value(0)
    status_led.value(0)
    print("Door locked!")

# ============= API COMMUNICATION =============
def get_lock_status():
    """Get current lock status from backend"""
    try:
        headers = {
            "Authorization": f"Bearer {DEVICE_AUTH_TOKEN}",
            "Content-Type": "application/json"
        }
        url = f"{BACKEND_API_URL}/iot/lock-status/{DEVICE_ID}"
        
        response = urequests.get(url, headers=headers)
        
        if response.status_code == 200:
            data = response.json()
            return data.get("is_locked", True)
        else:
            print(f"Error getting lock status: {response.status_code}")
            return None
    except Exception as e:
        print(f"Exception getting lock status: {e}")
        return None

def update_lock_status(is_locked):
    """Update lock status on backend"""
    try:
        headers = {
            "Authorization": f"Bearer {DEVICE_AUTH_TOKEN}",
            "Content-Type": "application/json"
        }
        url = f"{BACKEND_API_URL}/iot/lock-status/{DEVICE_ID}"
        data = {"is_locked": is_locked}
        
        response = urequests.post(url, headers=headers, json=data)
        
        if response.status_code == 200:
            print("Lock status updated on backend")
            return True
        else:
            print(f"Error updating lock status: {response.status_code}")
            return False
    except Exception as e:
        print(f"Exception updating lock status: {e}")
        return False

# ============= MAIN LOOP =============
def main():
    """Main program loop"""
    print("=" * 50)
    print("SmartRent IoT Device Starting...")
    print(f"Device ID: {DEVICE_ID}")
    print("=" * 50)
    
    # Connect to WiFi
    if not connect_wifi():
        print("Cannot proceed without WiFi. Please check configuration.")
        return
    
    # Main loop
    print("\nStarting main loop...")
    print("Polling for lock status updates...")
    
    last_status = True  # Assume locked initially
    poll_interval = 2  # Poll every 2 seconds
    
    while True:
        try:
            # Get lock status from backend
            current_status = get_lock_status()
            
            if current_status is not None and current_status != last_status:
                # Status changed
                print(f"\n🔔 Lock status changed: {'Locked' if current_status else 'Unlocked'}")
                
                if current_status:
                    lock_door()
                else:
                    unlock_door()
                
                last_status = current_status
            
            # Wait before next poll
            time.sleep(poll_interval)
            
        except KeyboardInterrupt:
            print("\n\nShutting down...")
            lock_door()  # Ensure door is locked on exit
            break
        except Exception as e:
            print(f"Error in main loop: {e}")
            time.sleep(5)

# ============= ENTRY POINT =============
if __name__ == "__main__":
    main()
