"""
Simple database connection checker (no dependencies required)
Checks if PostgreSQL is accessible
"""

import socket
import sys
import os
from urllib.parse import urlparse

def check_port(host, port, timeout=3):
    """Check if a port is open"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception as e:
        return False

def parse_database_url(url):
    """Parse DATABASE_URL"""
    try:
        parsed = urlparse(url)
        return {
            'host': parsed.hostname or 'localhost',
            'port': parsed.port or 5432,
            'database': parsed.path.lstrip('/') if parsed.path else None,
            'user': parsed.username,
            'password': '***' if parsed.password else None
        }
    except Exception as e:
        return None

def main():
    print("\n🚀 SmartRent Database Connection Checker (Simple)\n")
    print("=" * 60)
    
    # Check environment variables
    database_url = os.getenv('DATABASE_URL', 'postgresql://smartrent:password@localhost:5432/smartrent_db')
    
    print(f"📋 DATABASE_URL: {database_url}")
    
    # Parse URL
    db_info = parse_database_url(database_url)
    if not db_info:
        print("❌ Invalid DATABASE_URL format")
        sys.exit(1)
    
    print(f"\n📊 Database Configuration:")
    print(f"   Host: {db_info['host']}")
    print(f"   Port: {db_info['port']}")
    print(f"   Database: {db_info['database']}")
    print(f"   User: {db_info['user']}")
    
    # Check if port is open
    print(f"\n🔍 Checking PostgreSQL connection...")
    if check_port(db_info['host'], db_info['port']):
        print(f"✅ PostgreSQL port {db_info['port']} is open and accessible!")
    else:
        print(f"❌ Cannot connect to PostgreSQL on {db_info['host']}:{db_info['port']}")
        print(f"\n💡 Troubleshooting:")
        print(f"   1. Check if PostgreSQL is running:")
        print(f"      - macOS: brew services list | grep postgresql")
        print(f"      - Linux: sudo systemctl status postgresql")
        print(f"      - Docker: docker-compose up db")
        print(f"   2. Verify DATABASE_URL in .env file")
        print(f"   3. Check firewall settings")
        sys.exit(1)
    
    # Check Supabase
    print(f"\n" + "=" * 60)
    print(f"🔍 Supabase Configuration Check")
    print("=" * 60)
    
    supabase_url = os.getenv('SUPABASE_URL', '')
    supabase_service_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')
    supabase_anon_key = os.getenv('SUPABASE_ANON_KEY', '')
    
    if supabase_url:
        print(f"✅ SUPABASE_URL: {supabase_url[:50]}...")
    else:
        print(f"⚠️  SUPABASE_URL: Not configured")
    
    if supabase_service_key:
        print(f"✅ SUPABASE_SERVICE_ROLE_KEY: Set")
    else:
        print(f"⚠️  SUPABASE_SERVICE_ROLE_KEY: Not set")
    
    if supabase_anon_key:
        print(f"✅ SUPABASE_ANON_KEY: Set")
    else:
        print(f"⚠️  SUPABASE_ANON_KEY: Not set")
    
    if not supabase_url:
        print(f"\n💡 Supabase is optional. Configure it if you need authentication.")
    
    print(f"\n" + "=" * 60)
    print(f"📊 Summary")
    print("=" * 60)
    print(f"✅ PostgreSQL: Port accessible")
    if supabase_url:
        print(f"✅ Supabase: Configured")
    else:
        print(f"⚠️  Supabase: Not configured (optional)")
    print("=" * 60)
    print()

if __name__ == "__main__":
    main()

