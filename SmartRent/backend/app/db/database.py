"""
Database connection and session management
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

from app.core.config import settings


# Create database engine
# Use NullPool to avoid DNS caching issues with Supabase
connect_args = {}
if "sqlite" in settings.DATABASE_URL:
    connect_args = {"check_same_thread": False}
elif "postgresql" in settings.DATABASE_URL or "postgres" in settings.DATABASE_URL:
    connect_args = {
        "connect_timeout": 10,
        "options": "-c timezone=utc"
    }

engine = create_engine(
    settings.DATABASE_URL,
    poolclass=NullPool,  # Changed from StaticPool to fix DNS issues
    connect_args=connect_args,
    echo=settings.DEBUG
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class for models
Base = declarative_base()


def get_db():
    """Dependency to get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_supabase():
    """Dependency to get Supabase client for IoT operations"""
    from app.core.supabase_client import get_supabase_client
    return get_supabase_client()


def create_tables():
    """Create all database tables"""
    Base.metadata.create_all(bind=engine)


def drop_tables():
    """Drop all database tables"""
    Base.metadata.drop_all(bind=engine)

