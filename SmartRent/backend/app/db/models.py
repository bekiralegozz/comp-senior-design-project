"""
SQLAlchemy database models for SmartRent
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.database import Base


class User(Base):
    """User model for platform users"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(50), unique=True, index=True, nullable=False)
    full_name = Column(String(255), nullable=True)
    wallet_address = Column(String(42), unique=True, index=True, nullable=True)  # Ethereum address
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    owned_assets = relationship("Asset", foreign_keys="Asset.owner_id", back_populates="owner")
    rentals_as_renter = relationship("Rental", foreign_keys="Rental.renter_id", back_populates="renter")
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"


class Asset(Base):
    """Asset model for rentable items"""
    __tablename__ = "assets"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=False)  # e.g., "electronics", "vehicles", "tools"
    price_per_day = Column(Float, nullable=False)  # Price in ETH or USD
    currency = Column(String(10), default="ETH")  # ETH, USD, etc.
    
    # Blockchain integration
    token_id = Column(Integer, nullable=True, unique=True)  # NFT token ID
    contract_address = Column(String(42), nullable=True)  # Smart contract address
    
    # Availability
    is_available = Column(Boolean, default=True)
    location = Column(String(255), nullable=True)
    
    # Owner relationship
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    owner = relationship("User", foreign_keys=[owner_id], back_populates="owned_assets")
    
    # IoT integration
    iot_device_id = Column(String(100), nullable=True)  # Connected IoT device
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    rentals = relationship("Rental", back_populates="asset")
    
    def __repr__(self):
        return f"<Asset(id={self.id}, title='{self.title}', owner_id={self.owner_id})>"


class Rental(Base):
    """Rental agreement model"""
    __tablename__ = "rentals"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Asset and renter
    asset_id = Column(Integer, ForeignKey("assets.id"), nullable=False)
    asset = relationship("Asset", back_populates="rentals")
    
    renter_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    renter = relationship("User", foreign_keys=[renter_id], back_populates="rentals_as_renter")
    
    # Rental terms
    start_date = Column(DateTime(timezone=True), nullable=False)
    end_date = Column(DateTime(timezone=True), nullable=False)
    total_price = Column(Float, nullable=False)  # Total rental price
    currency = Column(String(10), default="ETH")
    
    # Status tracking
    status = Column(String(20), default="pending")  # pending, active, completed, cancelled
    
    # Blockchain integration
    smart_contract_address = Column(String(42), nullable=True)
    transaction_hash = Column(String(66), nullable=True)
    
    # Security deposit
    security_deposit = Column(Float, default=0.0)
    deposit_returned = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    def __repr__(self):
        return f"<Rental(id={self.id}, asset_id={self.asset_id}, renter_id={self.renter_id}, status='{self.status}')>"


class IoTDevice(Base):
    """IoT device model for connected hardware"""
    __tablename__ = "iot_devices"
    
    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(100), unique=True, nullable=False)  # Unique device identifier
    device_type = Column(String(50), nullable=False)  # e.g., "lock", "tracker", "sensor"
    name = Column(String(255), nullable=False)
    
    # Status
    is_online = Column(Boolean, default=False)
    battery_level = Column(Integer, nullable=True)  # 0-100%
    last_seen = Column(DateTime(timezone=True), nullable=True)
    
    # Configuration
    firmware_version = Column(String(20), nullable=True)
    hardware_version = Column(String(20), nullable=True)
    
    # Associated asset
    asset_id = Column(Integer, ForeignKey("assets.id"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    def __repr__(self):
        return f"<IoTDevice(id={self.id}, device_id='{self.device_id}', type='{self.device_type}')>"

