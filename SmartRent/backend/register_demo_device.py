"""
Register a demo IoT device for testing
"""
import requests
import json

# Configuration
API_BASE_URL = "http://localhost:8000/api/v1/iot"

# Demo device data
demo_device = {
    "device_id": "ESP32_DEMO_001",
    "device_name": "Demo Smart Lock",
    "device_type": "smart_lock",
    "asset_id": None,  # Will be linked to an asset later
    "firmware_version": "1.0.0",
    "mac_address": "AA:BB:CC:DD:EE:01"
}

print("=" * 60)
print("📱 SmartRent IoT Device Registration")
print("=" * 60)
print(f"\n🔧 Registering device: {demo_device['device_name']}")
print(f"🆔 Device ID: {demo_device['device_id']}\n")

try:
    # Register device (no auth required for demo - will add auth later)
    response = requests.post(
        f"{API_BASE_URL}/devices",
        headers={"Content-Type": "application/json"},
        json=demo_device,
        timeout=10
    )
    
    if response.status_code == 201:
        device = response.json()
        print("✅ Device registered successfully!")
        print("\n" + "=" * 60)
        print("📋 Device Information:")
        print("=" * 60)
        print(f"ID: {device['id']}")
        print(f"Device ID: {device['device_id']}")
        print(f"Name: {device['device_name']}")
        print(f"Type: {device['device_type']}")
        print(f"Status: {'🟢 Online' if device['is_online'] else '🔴 Offline'}")
        print(f"Lock State: {device['lock_state']}")
        print(f"Battery: {device.get('battery_level', 'N/A')}%")
        
        # The API key is NOT returned for security - it's stored in DB only
        print("\n" + "=" * 60)
        print("🔑 IMPORTANT: API Key")
        print("=" * 60)
        print("⚠️  The API key is stored securely in the database.")
        print("⚠️  You'll need to retrieve it from the database to configure ESP32.")
        print("\nTo get the API key, run this SQL in Supabase:")
        print(f"SELECT api_key FROM iot_devices WHERE device_id = '{demo_device['device_id']}';")
        
        print("\n" + "=" * 60)
        print("🎯 Next Steps:")
        print("=" * 60)
        print("1. Get API key from database")
        print("2. Update ESP32 code with API key")
        print("3. Upload code to ESP32")
        print("4. Test device polling")
        print("\n" + "=" * 60)
        
    elif response.status_code == 400:
        error = response.json()
        print(f"❌ Registration failed: {error.get('detail', 'Unknown error')}")
        print("\n💡 Tip: Device might already exist. Try a different device_id.")
        
    elif response.status_code == 401 or response.status_code == 403:
        print("❌ Authentication required!")
        print("\n💡 You need to be logged in to register devices.")
        print("   For testing, you can temporarily disable auth in the backend.")
        
    else:
        print(f"❌ Unexpected error: {response.status_code}")
        print(f"Response: {response.text}")
        
except requests.exceptions.ConnectionError:
    print("❌ Cannot connect to backend!")
    print("\n💡 Make sure backend is running:")
    print("   cd SmartRent/backend")
    print("   source venv/bin/activate")
    print("   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
    
except Exception as e:
    print(f"❌ Error: {e}")

print("\n")


