"""
Database connection checker script
Tests both PostgreSQL and Supabase connections
"""

import sys
from sqlalchemy import text
from app.db.database import engine, SessionLocal
from app.core.config import settings
from app.core.supabase_client import get_supabase_client, SupabaseConfigurationError


def check_postgresql_connection():
    """Check PostgreSQL database connection"""
    print("=" * 60)
    print("🔍 PostgreSQL Database Connection Check")
    print("=" * 60)
    
    print(f"📋 DATABASE_URL: {settings.DATABASE_URL}")
    
    try:
        # Test connection
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.fetchone()[0]
            print(f"✅ PostgreSQL connection successful!")
            print(f"   Version: {version}")
            
            # Test if we can query
            result = conn.execute(text("SELECT current_database()"))
            db_name = result.fetchone()[0]
            print(f"   Database: {db_name}")
            
            # Check if tables exist
            result = conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name
            """))
            tables = [row[0] for row in result.fetchall()]
            
            if tables:
                print(f"   Tables found: {', '.join(tables)}")
            else:
                print(f"   ⚠️  No tables found. Run create_tables() to initialize.")
            
            return True
            
    except Exception as e:
        print(f"❌ PostgreSQL connection failed!")
        print(f"   Error: {str(e)}")
        print(f"\n💡 Troubleshooting:")
        print(f"   1. Check if PostgreSQL is running")
        print(f"   2. Verify DATABASE_URL in .env file")
        print(f"   3. Check database credentials")
        print(f"   4. If using Docker: docker-compose up db")
        return False


def check_supabase_connection():
    """Check Supabase connection"""
    print("\n" + "=" * 60)
    print("🔍 Supabase Connection Check")
    print("=" * 60)
    
    print(f"📋 SUPABASE_URL: {settings.SUPABASE_URL or 'Not configured'}")
    print(f"📋 SUPABASE_SERVICE_ROLE_KEY: {'Set' if settings.SUPABASE_SERVICE_ROLE_KEY else 'Not set'}")
    print(f"📋 SUPABASE_ANON_KEY: {'Set' if settings.SUPABASE_ANON_KEY else 'Not set'}")
    
    if not settings.SUPABASE_URL:
        print("⚠️  Supabase is not configured. Skipping connection test.")
        print("   This is OK if you're not using Supabase for authentication.")
        return None
    
    try:
        # Test service role client
        client = get_supabase_client(use_service_role=True)
        print("✅ Supabase service role client created successfully!")
        
        # Try a simple query to test connection
        try:
            # This will fail if tables don't exist, but that's OK
            # We just want to test the connection
            response = client.table("users").select("id").limit(1).execute()
            print("   Connection test query successful!")
        except Exception as query_error:
            # Connection works, but maybe tables don't exist
            print(f"   ⚠️  Connection works, but query failed: {str(query_error)[:100]}")
        
        return True
        
    except SupabaseConfigurationError as e:
        print(f"❌ Supabase configuration error!")
        print(f"   Error: {str(e)}")
        print(f"\n💡 Troubleshooting:")
        print(f"   1. Set SUPABASE_URL in .env file")
        print(f"   2. Set SUPABASE_SERVICE_ROLE_KEY in .env file")
        print(f"   3. Set SUPABASE_ANON_KEY in .env file")
        return False
    except Exception as e:
        print(f"❌ Supabase connection failed!")
        print(f"   Error: {str(e)}")
        return False


def main():
    """Main function to run all checks"""
    print("\n🚀 SmartRent Database Connection Checker\n")
    
    postgres_ok = check_postgresql_connection()
    supabase_ok = check_supabase_connection()
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    
    if postgres_ok:
        print("✅ PostgreSQL: Connected")
    else:
        print("❌ PostgreSQL: Failed")
    
    if supabase_ok is None:
        print("⚠️  Supabase: Not configured")
    elif supabase_ok:
        print("✅ Supabase: Connected")
    else:
        print("❌ Supabase: Failed")
    
    print("\n" + "=" * 60)
    
    # Exit with error code if PostgreSQL fails (it's required)
    if not postgres_ok:
        sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()

