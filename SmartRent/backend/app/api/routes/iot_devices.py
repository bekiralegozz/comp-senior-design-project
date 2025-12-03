"""
IoT Device Management API Routes - Supabase Version
Handles smart lock devices, commands, and monitoring using Supabase REST API
"""

from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel, Field
from supabase import Client
import secrets
import hashlib

from app.db.database import get_supabase

router = APIRouter()


# ============================================
# Pydantic Schemas
# ============================================

class DeviceCreate(BaseModel):
    """Schema for creating a new IoT device"""
    device_id: str = Field(..., description="Unique device identifier (e.g., MAC address)")
    device_name: str = Field(..., description="Human-readable device name")
    device_type: str = Field(default="smart_lock", pattern="^(smart_lock|sensor|tracker)$")
    asset_id: Optional[str] = None  # UUID as string
    firmware_version: Optional[str] = None
    mac_address: Optional[str] = None


class DeviceResponse(BaseModel):
    """Response schema for device information"""
    id: int
    device_id: str
    device_name: str
    device_type: str
    is_online: bool
    lock_state: str
    battery_level: Optional[int]
    created_at: str


class CommandCreate(BaseModel):
    """Schema for creating a device command"""
    command_type: str = Field(..., pattern="^(unlock|lock|status|reboot)$")
    priority: int = Field(default=1, ge=1, le=5)


class CommandResponse(BaseModel):
    """Schema for command response to device"""
    id: int
    command_type: str
    command_payload: Dict[str, Any]
    issued_at: str


# ============================================
# Helper Functions
# ============================================

def generate_api_key() -> str:
    """Generate a secure API key for device authentication"""
    random_bytes = secrets.token_bytes(32)
    api_key = hashlib.sha256(random_bytes).hexdigest()
    return f"sk_iot_{api_key[:48]}"


# ============================================
# Device Management Endpoints
# ============================================

@router.get("/devices", response_model=List[DeviceResponse])
async def list_devices(
    skip: int = 0,
    limit: int = 100,
    supabase: Client = Depends(get_supabase)
):
    """
    List all IoT devices
    """
    try:
        response = supabase.table('iot_devices')\
            .select("*")\
            .range(skip, skip + limit - 1)\
            .execute()
        
        return response.data
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch devices: {str(e)}"
        )


@router.post("/devices", response_model=Dict[str, Any], status_code=status.HTTP_201_CREATED)
async def register_device(
    device: DeviceCreate,
    supabase: Client = Depends(get_supabase)
):
    """
    Register a new IoT device
    Returns device info + API key (SAVE THIS - shown only once!)
    """
    try:
        # Generate API key
        api_key = generate_api_key()
        
        # Prepare device data
        device_data = {
            "device_id": device.device_id,
            "device_name": device.device_name,
            "device_type": device.device_type,
            "asset_id": device.asset_id,
            "firmware_version": device.firmware_version,
            "mac_address": device.mac_address,
            "api_key": api_key,
            "is_online": False,
            "lock_state": "locked",
            "battery_level": 100,
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        
        # Insert device
        response = supabase.table('iot_devices').insert(device_data).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create device"
            )
        
        device_record = response.data[0]
        
        # Log registration
        log_data = {
            "device_id": device_record['id'],
            "log_level": "info",
            "event_type": "device_registered",
            "message": f"Device '{device.device_name}' registered successfully",
            "metadata": {"api_key_generated": True},  # Changed from extra_metadata
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        supabase.table('device_logs').insert(log_data).execute()
        
        return {
            **device_record,
            "api_key": api_key,  # Return API key ONLY on registration
            "message": "Device registered successfully. Save the API key securely!"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register device: {str(e)}"
        )


@router.get("/devices/{device_id}")
async def get_device_status(
    device_id: int,
    supabase: Client = Depends(get_supabase)
):
    """
    Get detailed device status
    """
    try:
        # Get device
        device_response = supabase.table('iot_devices')\
            .select("*")\
            .eq('id', device_id)\
            .single()\
            .execute()
        
        if not device_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device not found"
            )
        
        device = device_response.data
        
        # Get pending commands count
        commands_response = supabase.table('device_commands')\
            .select("id", count='exact')\
            .eq('device_id', device_id)\
            .eq('status', 'pending')\
            .execute()
        
        pending_commands = commands_response.count or 0
        
        # Get recent logs
        logs_response = supabase.table('device_logs')\
            .select("*")\
            .eq('device_id', device_id)\
            .order('created_at', desc=True)\
            .limit(10)\
            .execute()
        
        return {
            **device,
            "pending_commands": pending_commands,
            "recent_activity": logs_response.data
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch device status: {str(e)}"
        )


@router.post("/devices/{device_id}/commands", response_model=Dict[str, Any])
async def send_command(
    device_id: int,
    command: CommandCreate,
    supabase: Client = Depends(get_supabase)
):
    """
    Send a command to a device
    """
    try:
        # Verify device exists
        device_response = supabase.table('iot_devices')\
            .select("id, device_name")\
            .eq('id', device_id)\
            .single()\
            .execute()
        
        if not device_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device not found"
            )
        
        # Create command
        command_data = {
            "device_id": device_id,
            "command_type": command.command_type,
            "command_payload": {},
            "status": "pending",
            "priority": command.priority,
            "issued_at": datetime.now(timezone.utc).isoformat(),
            "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()
        }
        
        response = supabase.table('device_commands').insert(command_data).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create command"
            )
        
        command_record = response.data[0]
        
        # Log command
        log_data = {
            "device_id": device_id,
            "log_level": "info",
            "event_type": "command_issued",
            "message": f"Command '{command.command_type}' issued",
            "triggered_by_command_id": command_record['id'],
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        supabase.table('device_logs').insert(log_data).execute()
        
        return {
            **command_record,
            "message": f"Command '{command.command_type}' sent successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send command: {str(e)}"
        )


# ============================================
# Device-Side Endpoints (for ESP32)
# ============================================

@router.get("/devices/poll/{api_key}", response_model=List[CommandResponse])
async def poll_commands(
    api_key: str,
    supabase: Client = Depends(get_supabase)
):
    """
    Poll for pending commands (called by ESP32)
    Returns commands and marks them as 'sent'
    """
    try:
        # Verify API key and get device
        device_response = supabase.table('iot_devices')\
            .select("id, device_name")\
            .eq('api_key', api_key)\
            .single()\
            .execute()
        
        if not device_response.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key"
            )
        
        device = device_response.data
        device_id = device['id']
        
        # Update last_seen
        supabase.table('iot_devices')\
            .update({
                "last_seen_at": datetime.now(timezone.utc).isoformat(),
                "is_online": True
            })\
            .eq('id', device_id)\
            .execute()
        
        # Get pending commands
        commands_response = supabase.table('device_commands')\
            .select("*")\
            .eq('device_id', device_id)\
            .eq('status', 'pending')\
            .order('priority', desc=True)\
            .order('issued_at')\
            .execute()
        
        commands = commands_response.data
        
        # Mark commands as 'sent'
        if commands:
            command_ids = [cmd['id'] for cmd in commands]
            supabase.table('device_commands')\
                .update({
                    "status": "sent",
                    "executed_at": datetime.now(timezone.utc).isoformat()
                })\
                .in_('id', command_ids)\
                .execute()
        
        return commands
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to poll commands: {str(e)}"
        )


@router.post("/devices/heartbeat/{api_key}")
async def device_heartbeat(
    api_key: str,
    status_data: Dict[str, Any],
    supabase: Client = Depends(get_supabase)
):
    """
    Device heartbeat - update status (called by ESP32)
    """
    try:
        # Verify API key and get device
        device_response = supabase.table('iot_devices')\
            .select("id")\
            .eq('api_key', api_key)\
            .single()\
            .execute()
        
        if not device_response.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key"
            )
        
        device_id = device_response.data['id']
        
        # Update device status
        update_data = {
            "is_online": True,
            "last_seen_at": datetime.now(timezone.utc).isoformat(),
        }
        
        if 'lock_state' in status_data:
            update_data['lock_state'] = status_data['lock_state']
        if 'battery_level' in status_data:
            update_data['battery_level'] = status_data['battery_level']
        if 'signal_strength' in status_data:
            update_data['signal_strength'] = status_data['signal_strength']
        
        supabase.table('iot_devices')\
            .update(update_data)\
            .eq('id', device_id)\
            .execute()
        
        return {"status": "ok", "message": "Heartbeat received"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process heartbeat: {str(e)}"
        )


@router.post("/devices/command_response/{api_key}")
async def command_response(
    api_key: str,
    command_id: int,
    response_data: Dict[str, Any],
    supabase: Client = Depends(get_supabase)
):
    """
    Device reports command execution result (called by ESP32)
    """
    try:
        # Verify API key
        device_response = supabase.table('iot_devices')\
            .select("id")\
            .eq('api_key', api_key)\
            .single()\
            .execute()
        
        if not device_response.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key"
            )
        
        # Update command status
        update_data = {
            "status": response_data.get('status', 'completed'),
            "completed_at": datetime.now(timezone.utc).isoformat(),
            "response_data": response_data
        }
        
        if 'error' in response_data:
            update_data['error_message'] = response_data['error']
        
        supabase.table('device_commands')\
            .update(update_data)\
            .eq('id', command_id)\
            .execute()
        
        return {"status": "ok", "message": "Command response recorded"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process command response: {str(e)}"
        )
