"""
IoT Device Management API Router

Handles ESP32 device communication:
- Device registration and heartbeat
- Command polling and execution
- Unlock authorization via blockchain
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, Dict, List
from datetime import datetime, timedelta
import asyncio

router = APIRouter(prefix="/iot", tags=["IoT Devices"])

# ============================================
# IN-MEMORY STORAGE
# ============================================

# Online devices: {device_id: {status, last_seen, ...}}
devices: Dict[str, dict] = {}

# Command queue: {device_id: [commands]}
command_queue: Dict[str, List[dict]] = {}

# Device timeout (seconds) - device considered offline after this
DEVICE_TIMEOUT = 60

# ============================================
# MODELS
# ============================================

class DeviceRegisterRequest(BaseModel):
    device_id: str
    device_type: str = "smart_lock"
    firmware_version: Optional[str] = None

class DeviceHeartbeatRequest(BaseModel):
    device_id: str
    lock_state: Optional[str] = "locked"  # "locked" or "unlocked"
    battery_level: Optional[int] = None
    signal_strength: Optional[int] = None
    ip_address: Optional[str] = None

class UnlockRequest(BaseModel):
    device_id: str
    wallet_address: str
    # signature: Optional[str] = None  # For future wallet signature verification

class CommandResponse(BaseModel):
    device_id: str
    command_id: str
    status: str  # "success" or "failed"
    message: Optional[str] = None

class LinkDeviceRequest(BaseModel):
    device_id: str
    token_id: int
    wallet_address: str

# ============================================
# HELPER FUNCTIONS
# ============================================

def is_device_online(device_id: str) -> bool:
    """Check if device is online (heartbeat within timeout)"""
    if device_id not in devices:
        return False
    last_seen = devices[device_id].get("last_seen")
    if not last_seen:
        return False
    return (datetime.utcnow() - last_seen).total_seconds() < DEVICE_TIMEOUT

def get_online_devices() -> List[dict]:
    """Get list of online devices"""
    online = []
    for device_id, info in devices.items():
        if is_device_online(device_id):
            online.append({
                "device_id": device_id,
                **info,
                "online": True
            })
    return online

def add_command(device_id: str, command_type: str, data: dict = None) -> str:
    """Add command to device queue, return command_id"""
    import uuid
    command_id = str(uuid.uuid4())[:8]
    
    if device_id not in command_queue:
        command_queue[device_id] = []
    
    command_queue[device_id].append({
        "command_id": command_id,
        "type": command_type,
        "data": data or {},
        "created_at": datetime.utcnow().isoformat()
    })
    
    return command_id

# ============================================
# ESP32 ENDPOINTS
# ============================================

@router.post("/devices/register")
async def register_device(request: DeviceRegisterRequest):
    """
    Register a new device or update existing registration.
    Called by ESP32 on boot.
    """
    device_id = request.device_id
    
    devices[device_id] = {
        "device_type": request.device_type,
        "firmware_version": request.firmware_version,
        "last_seen": datetime.utcnow(),
        "lock_state": "locked",
        "registered_at": datetime.utcnow().isoformat() if device_id not in devices else devices.get(device_id, {}).get("registered_at", datetime.utcnow().isoformat())
    }
    
    # Initialize command queue
    if device_id not in command_queue:
        command_queue[device_id] = []
    
    return {
        "status": "registered",
        "device_id": device_id,
        "message": f"Device {device_id} registered successfully"
    }

@router.post("/devices/heartbeat")
async def device_heartbeat(request: DeviceHeartbeatRequest):
    """
    Receive heartbeat from device. Updates device status.
    Called by ESP32 every 30 seconds.
    """
    device_id = request.device_id
    
    if device_id not in devices:
        # Auto-register if not exists
        devices[device_id] = {
            "device_type": "smart_lock",
            "registered_at": datetime.utcnow().isoformat()
        }
    
    # Update device info
    devices[device_id].update({
        "last_seen": datetime.utcnow(),
        "lock_state": request.lock_state,
        "battery_level": request.battery_level,
        "signal_strength": request.signal_strength,
        "ip_address": request.ip_address
    })
    
    return {
        "status": "ok",
        "server_time": datetime.utcnow().isoformat()
    }

@router.get("/devices/poll/{device_id}")
async def poll_commands(device_id: str):
    """
    Poll for pending commands.
    Called by ESP32 every 3-5 seconds.
    Returns and clears pending commands.
    """
    # Update last seen
    if device_id in devices:
        devices[device_id]["last_seen"] = datetime.utcnow()
    
    # Get and clear commands
    commands = command_queue.get(device_id, [])
    command_queue[device_id] = []
    
    return {
        "commands": commands,
        "server_time": datetime.utcnow().isoformat()
    }

@router.post("/devices/command/complete")
async def command_complete(response: CommandResponse):
    """
    Report command completion status.
    Called by ESP32 after executing a command.
    """
    # Log command completion (could store in DB for audit)
    print(f"[IoT] Command {response.command_id} on {response.device_id}: {response.status}")
    
    # Update lock state if unlock/lock command
    if response.device_id in devices and response.status == "success":
        # The device will report actual state via heartbeat
        pass
    
    return {"status": "acknowledged"}

# ============================================
# MOBILE APP ENDPOINTS
# ============================================

@router.get("/devices/available")
async def get_available_devices():
    """
    Get list of online devices that are not yet assigned to an asset.
    Used by Flutter app when creating a new asset.
    
    Note: Assignment check requires blockchain query (TODO).
    For now, returns all online devices.
    """
    online_devices = get_online_devices()
    
    # Filter out devices already linked to an asset
    available = [d for d in online_devices if not d.get("linked_asset_id")]
    
    return {
        "devices": available,
        "count": len(available)
    }

@router.get("/devices/by-asset/{asset_id}")
async def get_device_by_asset(asset_id: int):
    """
    Get device linked to a specific asset (token_id).
    Used by Flutter SmartLockScreen to find the correct device.
    """
    for device_id, info in devices.items():
        if info.get("linked_asset_id") == asset_id:
            return {
                "device_id": device_id,
                "online": is_device_online(device_id),
                **info,
                "last_seen": info.get("last_seen").isoformat() if info.get("last_seen") else None
            }
    
    raise HTTPException(status_code=404, detail=f"No device linked to asset #{asset_id}")

@router.get("/devices/{device_id}/status")
async def get_device_status(device_id: str):
    """
    Get current status of a specific device.
    """
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not found")
    
    device_info = devices[device_id]
    online = is_device_online(device_id)
    
    return {
        "device_id": device_id,
        "online": online,
        **device_info,
        "last_seen": device_info.get("last_seen").isoformat() if device_info.get("last_seen") else None
    }

@router.post("/unlock")
async def request_unlock(request: UnlockRequest):
    """
    Request to unlock a device.
    
    Flow:
    1. Check device is online
    2. Verify wallet has authorization (linked asset or active rental)
    3. If authorized, add unlock command to queue
    4. ESP32 will pick up command on next poll
    """
    device_id = request.device_id
    wallet_address = request.wallet_address
    
    # Check device exists and is online
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not found")
    
    if not is_device_online(device_id):
        raise HTTPException(status_code=503, detail="Device is offline")
    
    # Authorization check:
    # 1. Check if device is linked to an asset
    # 2. For now, we allow unlock if:
    #    - Device owner (linked_by matches wallet)
    #    - OR anyone with a valid wallet (for demo/testing)
    # 
    # In production, this should call RentalHub.isAuthorizedToUnlock() on blockchain
    
    device_info = devices[device_id]
    linked_by = device_info.get("linked_by", "").lower()
    linked_asset_id = device_info.get("linked_asset_id")
    
    is_owner = linked_by == wallet_address.lower()
    
    # For MVP: Allow owner OR anyone during active rental period
    # TODO: Implement proper blockchain verification
    is_authorized = True  # Allow for testing - replace with blockchain call in production
    
    print(f"[IoT] Unlock request: device={device_id}, wallet={wallet_address[:10]}..., is_owner={is_owner}, authorized={is_authorized}")
    
    if not is_authorized:
        raise HTTPException(
            status_code=403, 
            detail="Not authorized. No active rental found for this device."
        )
    
    # Add unlock command to queue
    command_id = add_command(device_id, "unlock", {
        "wallet_address": wallet_address,
        "rental_id": rental_id,
        "duration": 5  # Auto-lock after 5 seconds
    })
    
    return {
        "status": "queued",
        "command_id": command_id,
        "message": "Unlock command sent to device",
        "device_id": device_id
    }

@router.post("/lock")
async def request_lock(request: UnlockRequest):
    """
    Request to lock a device.
    Similar to unlock but doesn't require rental verification.
    """
    device_id = request.device_id
    
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not found")
    
    if not is_device_online(device_id):
        raise HTTPException(status_code=503, detail="Device is offline")
    
    command_id = add_command(device_id, "lock", {
        "wallet_address": request.wallet_address
    })
    
    return {
        "status": "queued",
        "command_id": command_id,
        "message": "Lock command sent to device",
        "device_id": device_id
    }

# ============================================
# ADMIN ENDPOINTS
# ============================================

@router.get("/devices")
async def list_all_devices():
    """
    List all registered devices (admin).
    """
    all_devices = []
    for device_id, info in devices.items():
        all_devices.append({
            "device_id": device_id,
            "online": is_device_online(device_id),
            **info,
            "last_seen": info.get("last_seen").isoformat() if info.get("last_seen") else None
        })
    
    return {
        "devices": all_devices,
        "total": len(all_devices),
        "online": sum(1 for d in all_devices if d["online"])
    }

@router.delete("/devices/{device_id}")
async def remove_device(device_id: str):
    """
    Remove a device from registry (admin).
    """
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not found")
    
    del devices[device_id]
    if device_id in command_queue:
        del command_queue[device_id]
    
    return {"status": "removed", "device_id": device_id}

@router.post("/link")
async def link_device_to_asset(request: LinkDeviceRequest):
    """
    Link an IoT device to an NFT asset.
    
    This stores the device-asset mapping in our backend database.
    The on-chain registration (RentalHub.registerDevice) should be called
    separately by the asset owner through their wallet.
    
    For now, we'll store this mapping in memory and return success.
    In production, this should:
    1. Store mapping in database
    2. Optionally trigger on-chain registration if backend has signing capability
    """
    device_id = request.device_id
    token_id = request.token_id
    wallet_address = request.wallet_address
    
    # Check if device exists
    if device_id not in devices:
        # Auto-register device if it's being linked
        devices[device_id] = {
            "device_type": "smart_lock",
            "registered_at": datetime.utcnow().isoformat(),
            "last_seen": None,
            "lock_state": "unknown"
        }
    
    # Store the asset link
    devices[device_id]["linked_asset_id"] = token_id
    devices[device_id]["linked_by"] = wallet_address
    devices[device_id]["linked_at"] = datetime.utcnow().isoformat()
    
    print(f"[IoT] Device {device_id} linked to asset #{token_id} by {wallet_address}")
    
    return {
        "status": "linked",
        "device_id": device_id,
        "token_id": token_id,
        "message": f"Device {device_id} linked to asset #{token_id}",
        # Note: On-chain registration should be done via smart contract call
        "note": "For on-chain registration, call RentalHub.registerDevice() from owner wallet"
    }
