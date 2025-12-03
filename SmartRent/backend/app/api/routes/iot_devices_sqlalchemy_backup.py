"""
IoT Device Management API Routes
Handles smart lock devices, commands, and monitoring
"""

from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
import secrets
import hashlib

from app.db.database import get_db
from app.db.models import IoTDevice, DeviceCommand, DeviceLog, User
# from app.api.routes.auth import get_current_user, get_current_active_user  # TODO: Add authentication later

router = APIRouter()  # Prefix handled in main.py


# ============================================
# Pydantic Schemas
# ============================================

class DeviceCreate(BaseModel):
    """Schema for creating a new IoT device"""
    device_id: str = Field(..., description="Unique device identifier (e.g., MAC address)")
    device_name: str = Field(..., description="Human-readable device name")
    device_type: str = Field(default="smart_lock", pattern="^(smart_lock|sensor|tracker)$")
    asset_id: Optional[int] = None
    firmware_version: Optional[str] = None
    mac_address: Optional[str] = Field(None, pattern="^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$")


class DeviceUpdate(BaseModel):
    """Schema for updating device information"""
    is_online: Optional[bool] = None
    lock_state: Optional[str] = Field(None, pattern="^(locked|unlocked|jammed|unknown)$")
    battery_level: Optional[int] = Field(None, ge=0, le=100)
    signal_strength: Optional[int] = Field(None, ge=-100, le=0)
    firmware_version: Optional[str] = None
    ip_address: Optional[str] = None


class DeviceResponse(BaseModel):
    """Response schema for device information"""
    id: int
    device_id: str
    device_name: str
    device_type: str
    is_online: bool
    lock_state: str
    battery_level: Optional[int]
    signal_strength: Optional[int]
    firmware_version: Optional[str]
    asset_id: Optional[int]
    last_seen_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class DeviceControlRequest(BaseModel):
    """Request to control a device (unlock/lock)"""
    command_type: str = Field(..., pattern="^(unlock|lock|status)$")
    priority: int = Field(default=3, ge=1, le=5)


class LockControlRequest(BaseModel):
    """Simplified request to unlock/lock a device"""
    action: str = Field(..., pattern="^(unlock|lock)$", description="Action to perform")


class DeviceCommandResponse(BaseModel):
    """Response for device command"""
    id: int
    device_id: int
    command_type: str
    status: str
    issued_at: datetime
    completed_at: Optional[datetime]
    error_message: Optional[str]

    class Config:
        from_attributes = True


class DeviceLogResponse(BaseModel):
    """Response for device log"""
    id: int
    device_id: int
    log_level: str
    event_type: str
    message: str
    created_at: datetime

    class Config:
        from_attributes = True


class DeviceStatusResponse(BaseModel):
    """Detailed device status"""
    id: int
    device_id: str
    device_name: str
    is_online: bool
    lock_state: str
    battery_level: Optional[int]
    signal_strength: Optional[int]
    last_seen_at: Optional[datetime]
    pending_commands: int
    recent_activity: List[DeviceLogResponse]

    class Config:
        from_attributes = True


# ============================================
# Helper Functions
# ============================================

def generate_device_api_key(device_id: str) -> str:
    """Generate a unique API key for device authentication"""
    random_part = secrets.token_urlsafe(32)
    combined = f"{device_id}:{random_part}:{datetime.utcnow().isoformat()}"
    hashed = hashlib.sha256(combined.encode()).hexdigest()
    return f"iot_{hashed[:48]}"


def log_device_event(
    db: Session,
    device_id: int,
    event_type: str,
    message: str,
    log_level: str = "info",
    user_id: Optional[int] = None,
    command_id: Optional[int] = None,
    metadata: dict = None
):
    """Helper function to log device events"""
    log = DeviceLog(
        device_id=device_id,
        log_level=log_level,
        event_type=event_type,
        message=message,
        metadata=metadata or {},
        triggered_by_user_id=user_id,
        triggered_by_command_id=command_id
    )
    db.add(log)
    db.commit()


# ============================================
# Device Management Endpoints
# ============================================

@router.post("/devices", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
def register_device(
    device: DeviceCreate,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """
    Register a new IoT device
    Owner/Admin only
    """
    # Check if device already exists
    existing_device = db.query(IoTDevice).filter(IoTDevice.device_id == device.device_id).first()
    if existing_device:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Device with ID '{device.device_id}' already exists"
        )
    
    # Generate API key for device authentication
    api_key = generate_device_api_key(device.device_id)
    
    # Create new device
    new_device = IoTDevice(
        device_id=device.device_id,
        device_name=device.device_name,
        device_type=device.device_type,
        asset_id=device.asset_id,
        firmware_version=device.firmware_version,
        mac_address=device.mac_address,
        api_key=api_key,
        is_online=False,
        lock_state="locked"
    )
    
    db.add(new_device)
    db.commit()
    db.refresh(new_device)
    
    # Log device registration
    log_device_event(
        db=db,
        device_id=new_device.id,
        event_type="device_registered",
        message=f"Device '{device.device_name}' registered successfully",
        log_level="info",
        user_id=None,  # current_user.id - TODO: Add auth
    )
    
    return new_device


@router.get("/devices", response_model=List[DeviceResponse])
def list_devices(
    skip: int = 0,
    limit: int = 100,
    device_type: Optional[str] = None,
    is_online: Optional[bool] = None,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """List all IoT devices (with optional filters)"""
    query = db.query(IoTDevice)
    
    if device_type:
        query = query.filter(IoTDevice.device_type == device_type)
    if is_online is not None:
        query = query.filter(IoTDevice.is_online == is_online)
    
    devices = query.offset(skip).limit(limit).all()
    return devices


@router.get("/devices/{device_id}", response_model=DeviceResponse)
def get_device(
    device_id: int,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """Get device details by ID"""
    device = db.query(IoTDevice).filter(IoTDevice.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    return device


@router.patch("/devices/{device_id}", response_model=DeviceResponse)
def update_device(
    device_id: int,
    update: DeviceUpdate,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """Update device information"""
    device = db.query(IoTDevice).filter(IoTDevice.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    # Update fields if provided
    update_data = update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(device, field, value)
    
    device.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(device)
    
    return device


# ============================================
# Device Control Endpoints
# ============================================

@router.post("/devices/{device_id}/lock", response_model=DeviceCommandResponse)
async def control_lock(
    device_id: int,
    control: LockControlRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """
    Control smart lock (unlock/lock)
    Requires active rental or ownership
    """
    # Get device
    device = db.query(IoTDevice).filter(IoTDevice.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    if device.device_type != "smart_lock":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Device is not a smart lock"
        )
    
    # TODO: Check if user has permission (active rental or is owner)
    # For now, allowing all authenticated users
    
    # Create command
    command = DeviceCommand(
        device_id=device_id,
        command_type=control.action,
        command_payload={},  # TODO: Add user_id when auth is enabled
        status="pending",
        priority=5,  # High priority for lock control
        issued_by_user_id=None,  # current_user.id - TODO: Add auth
        expires_at=datetime.utcnow() + timedelta(minutes=5)
    )
    
    db.add(command)
    db.commit()
    db.refresh(command)
    
    # Log the control request
    log_device_event(
        db=db,
        device_id=device_id,
        event_type=f"lock_{control.action}_requested",
        message=f"User requested to {control.action} the lock",  # TODO: Add username when auth is enabled
        log_level="info",
        user_id=None,  # current_user.id - TODO: Add auth
        command_id=command.id
    )
    
    return command


@router.get("/devices/{device_id}/status", response_model=DeviceStatusResponse)
def get_device_status(
    device_id: int,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """Get real-time device status"""
    device = db.query(IoTDevice).filter(IoTDevice.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    # Get pending commands count
    pending_commands = db.query(DeviceCommand).filter(
        DeviceCommand.device_id == device_id,
        DeviceCommand.status.in_(["pending", "sent"])
    ).count()
    
    # Get recent activity (last 10 logs)
    recent_logs = db.query(DeviceLog).filter(
        DeviceLog.device_id == device_id
    ).order_by(DeviceLog.created_at.desc()).limit(10).all()
    
    return DeviceStatusResponse(
        id=device.id,
        device_id=device.device_id,
        device_name=device.device_name,
        is_online=device.is_online,
        lock_state=device.lock_state,
        battery_level=device.battery_level,
        signal_strength=device.signal_strength,
        last_seen_at=device.last_seen_at,
        pending_commands=pending_commands,
        recent_activity=recent_logs
    )


# ============================================
# Device-Side Endpoints (for ESP32)
# ============================================

@router.get("/devices/poll/{api_key}")
def poll_commands(
    api_key: str,
    db: Session = Depends(get_db)
):
    """
    Poll for pending commands (called by IoT device)
    No authentication required - uses API key
    """
    # Find device by API key
    device = db.query(IoTDevice).filter(IoTDevice.api_key == api_key).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    # Update device last seen
    device.last_seen_at = datetime.utcnow()
    device.is_online = True
    
    # Get pending commands (ordered by priority)
    commands = db.query(DeviceCommand).filter(
        DeviceCommand.device_id == device.id,
        DeviceCommand.status == "pending",
        DeviceCommand.expires_at > datetime.utcnow()
    ).order_by(
        DeviceCommand.priority.desc(),
        DeviceCommand.issued_at.asc()
    ).limit(5).all()
    
    # Mark commands as sent
    for cmd in commands:
        cmd.status = "sent"
        cmd.executed_at = datetime.utcnow()
    
    db.commit()
    
    return {
        "device_id": device.device_id,
        "timestamp": datetime.utcnow().isoformat(),
        "commands": [
            {
                "id": cmd.id,
                "command_type": cmd.command_type,
                "payload": cmd.command_payload,
                "priority": cmd.priority
            }
            for cmd in commands
        ]
    }


@router.post("/devices/heartbeat/{api_key}")
def device_heartbeat(
    api_key: str,
    status_update: dict,
    db: Session = Depends(get_db)
):
    """
    Device heartbeat with status update
    Updates device status (battery, lock state, etc.)
    """
    # Find device by API key
    device = db.query(IoTDevice).filter(IoTDevice.api_key == api_key).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    # Update device status
    device.last_seen_at = datetime.utcnow()
    device.is_online = True
    
    if "battery_level" in status_update:
        device.battery_level = status_update["battery_level"]
    if "lock_state" in status_update:
        old_state = device.lock_state
        new_state = status_update["lock_state"]
        device.lock_state = new_state
        
        # Log state change
        if old_state != new_state:
            log_device_event(
                db=db,
                device_id=device.id,
                event_type=f"lock_{new_state}",
                message=f"Lock state changed from '{old_state}' to '{new_state}'",
                log_level="info"
            )
    
    if "signal_strength" in status_update:
        device.signal_strength = status_update["signal_strength"]
    if "ip_address" in status_update:
        device.ip_address = status_update["ip_address"]
    
    db.commit()
    
    return {
        "status": "ok",
        "message": "Heartbeat received",
        "timestamp": datetime.utcnow().isoformat()
    }


@router.post("/devices/command/{command_id}/complete")
def complete_command(
    command_id: int,
    api_key: str,
    result: dict,
    db: Session = Depends(get_db)
):
    """
    Mark a command as completed (called by IoT device)
    """
    # Verify API key
    device = db.query(IoTDevice).filter(IoTDevice.api_key == api_key).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key"
        )
    
    # Get command
    command = db.query(DeviceCommand).filter(
        DeviceCommand.id == command_id,
        DeviceCommand.device_id == device.id
    ).first()
    
    if not command:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Command not found"
        )
    
    # Update command status
    command.status = result.get("status", "completed")
    command.completed_at = datetime.utcnow()
    command.response_data = result.get("data", {})
    
    if result.get("error"):
        command.error_message = result["error"]
        command.status = "failed"
    
    db.commit()
    
    # Log command completion
    log_device_event(
        db=db,
        device_id=device.id,
        event_type=f"command_{command.status}",
        message=f"Command '{command.command_type}' {command.status}",
        log_level="info" if command.status == "completed" else "error",
        command_id=command_id
    )
    
    return {
        "status": "ok",
        "message": "Command status updated"
    }


# ============================================
# Device Logs Endpoints
# ============================================

@router.get("/devices/{device_id}/logs", response_model=List[DeviceLogResponse])
def get_device_logs(
    device_id: int,
    skip: int = 0,
    limit: int = 50,
    event_type: Optional[str] = None,
    db: Session = Depends(get_db),
    # current_user: User = Depends(get_current_user)  # TODO: Add auth
):
    """Get device activity logs"""
    device = db.query(IoTDevice).filter(IoTDevice.id == device_id).first()
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found"
        )
    
    query = db.query(DeviceLog).filter(DeviceLog.device_id == device_id)
    
    if event_type:
        query = query.filter(DeviceLog.event_type == event_type)
    
    logs = query.order_by(DeviceLog.created_at.desc()).offset(skip).limit(limit).all()
    return logs
