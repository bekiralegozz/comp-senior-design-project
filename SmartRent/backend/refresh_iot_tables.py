#!/usr/bin/env python3
"""
Refresh IoT tables in Supabase - Drop and recreate
"""
import asyncio
import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

async def refresh_tables():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    print("🗑️  Dropping existing IoT tables...")
    
    # Drop tables in correct order (reverse of creation)
    drop_queries = [
        "DROP TABLE IF EXISTS device_logs CASCADE;",
        "DROP TABLE IF EXISTS device_commands CASCADE;",
        "DROP TABLE IF EXISTS iot_devices CASCADE;",
    ]
    
    for query in drop_queries:
        try:
            result = supabase.rpc('execute_sql', {'query': query}).execute()
            print(f"✅ Executed: {query[:50]}...")
        except Exception as e:
            print(f"⚠️  Error: {e}")
            # Try direct SQL execution
            try:
                result = supabase.postgrest.rpc('query', {'query': query}).execute()
            except:
                pass
    
    print("\n📝 Creating fresh IoT tables...")
    
    # Read SQL file
    sql_file_path = os.path.join(os.path.dirname(__file__), 'sql', 'create_iot_tables.sql')
    with open(sql_file_path, 'r') as f:
        sql_content = f.read()
    
    # Execute SQL
    try:
        # Method 1: Try using RPC if available
        result = supabase.rpc('execute_sql', {'query': sql_content}).execute()
        print("✅ IoT tables created successfully!")
    except Exception as e:
        print(f"\n⚠️  Could not execute via RPC: {e}")
        print("\n📋 Please execute this SQL manually in Supabase SQL Editor:")
        print("=" * 80)
        print(sql_content)
        print("=" * 80)

if __name__ == "__main__":
    asyncio.run(refresh_tables())


