"""
Pydantic schemas for request/response models
"""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field


# User schemas
class UserBase(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    full_name: Optional[str] = None
    wallet_address: Optional[str] = Field(None, regex="^0x[a-fA-F0-9]{40}$")


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    full_name: Optional[str] = None
    wallet_address: Optional[str] = Field(None, regex="^0x[a-fA-F0-9]{40}$")
    is_active: Optional[bool] = None
    is_verified: Optional[bool] = None


class UserResponse(UserBase):
    id: int
    is_active: bool
    is_verified: bool
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        orm_mode = True


# Asset schemas
class AssetBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    category: str = Field(..., min_length=1, max_length=100)
    price_per_day: float = Field(..., gt=0)
    currency: str = Field(default="ETH", regex="^(ETH|USD|EUR)$")
    location: Optional[str] = None


class AssetCreate(AssetBase):
    owner_id: int
    iot_device_id: Optional[str] = None


class AssetUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    category: Optional[str] = Field(None, min_length=1, max_length=100)
    price_per_day: Optional[float] = Field(None, gt=0)
    currency: Optional[str] = Field(None, regex="^(ETH|USD|EUR)$")
    is_available: Optional[bool] = None
    location: Optional[str] = None


class AssetResponse(AssetBase):
    id: int
    owner_id: int
    token_id: Optional[int]
    contract_address: Optional[str]
    is_available: bool
    iot_device_id: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        orm_mode = True


class AssetWithOwner(AssetResponse):
    owner: UserResponse


# Rental schemas
class RentalBase(BaseModel):
    asset_id: int
    start_date: datetime
    end_date: datetime
    total_price: float = Field(..., gt=0)
    currency: str = Field(default="ETH", regex="^(ETH|USD|EUR)$")
    security_deposit: float = Field(default=0.0, ge=0)


class RentalCreate(RentalBase):
    renter_id: int


class RentalUpdate(BaseModel):
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    total_price: Optional[float] = Field(None, gt=0)
    status: Optional[str] = Field(None, regex="^(pending|active|completed|cancelled)$")
    deposit_returned: Optional[bool] = None


class RentalResponse(RentalBase):
    id: int
    renter_id: int
    status: str
    smart_contract_address: Optional[str]
    transaction_hash: Optional[str]
    deposit_returned: bool
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        orm_mode = True


class RentalWithDetails(RentalResponse):
    asset: AssetResponse
    renter: UserResponse


# IoT Device schemas
class IoTDeviceBase(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=100)
    device_type: str = Field(..., min_length=1, max_length=50)
    name: str = Field(..., min_length=1, max_length=255)


class IoTDeviceCreate(IoTDeviceBase):
    asset_id: Optional[int] = None
    firmware_version: Optional[str] = None
    hardware_version: Optional[str] = None


class IoTDeviceUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    is_online: Optional[bool] = None
    battery_level: Optional[int] = Field(None, ge=0, le=100)
    firmware_version: Optional[str] = None
    hardware_version: Optional[str] = None
    asset_id: Optional[int] = None


class IoTDeviceResponse(IoTDeviceBase):
    id: int
    is_online: bool
    battery_level: Optional[int]
    last_seen: Optional[datetime]
    firmware_version: Optional[str]
    hardware_version: Optional[str]
    asset_id: Optional[int]
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        orm_mode = True


# Generic response schemas
class MessageResponse(BaseModel):
    message: str


class HealthResponse(BaseModel):
    status: str
    message: str
    version: str
    environment: str

