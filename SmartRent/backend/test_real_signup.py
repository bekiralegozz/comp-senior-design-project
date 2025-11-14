"""
Test real signup flow to see if profile is created
"""

import sys
import os
import asyncio

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.supabase_client import get_supabase_client
from app.core.config import settings
from uuid import uuid4
from datetime import datetime

async def test_signup_flow():
    print("\n" + "=" * 60)
    print("🔍 Gerçek Signup Flow Testi")
    print("=" * 60)
    
    client = get_supabase_client(use_service_role=True)
    
    # Create a test user via auth
    test_email = f"test_{datetime.now().timestamp()}@example.com"
    test_password = "TestPassword123!"
    
    print(f"\n📋 Test Email: {test_email}")
    
    try:
        # Step 1: Sign up via auth
        print(f"\n1️⃣  Supabase Auth'a signup yapılıyor...")
        auth_result = client.auth.sign_up({
            "email": test_email,
            "password": test_password,
        })
        
        user = getattr(auth_result, "user", None)
        if not user:
            print("❌ Auth signup başarısız - user döndürülmedi")
            return
        
        user_id = str(getattr(user, "id", ""))
        print(f"✅ Auth signup başarılı!")
        print(f"   User ID: {user_id}")
        
        # Step 2: Check if user exists in auth.users
        print(f"\n2️⃣  Auth.users'da kullanıcı kontrol ediliyor...")
        admin_users = client.auth.admin.list_users()
        found_user = None
        for u in admin_users:
            if str(u.id) == user_id:
                found_user = u
                break
        
        if found_user:
            print(f"✅ Kullanıcı auth.users'da bulundu")
        else:
            print(f"⚠️  Kullanıcı auth.users'da bulunamadı (liste boş olabilir)")
        
        # Step 3: Try to insert profile
        print(f"\n3️⃣  Profiles tablosuna ekleme yapılıyor...")
        profile_payload = {
            "id": user_id,
            "email": test_email,
            "full_name": "Test User",
            "auth_provider": "email",
            "is_onboarded": False,
        }
        
        table = client.table("profiles")
        insert_result = table.insert(profile_payload).execute()
        
        print(f"✅ Profile başarıyla eklendi!")
        print(f"   Response: {insert_result.data}")
        
        # Step 4: Read back the profile
        print(f"\n4️⃣  Profile okunuyor...")
        read_result = table.select("*").eq("id", user_id).execute()
        
        if read_result.data:
            print(f"✅ Profile okundu!")
            print(f"   Data: {read_result.data[0]}")
        else:
            print(f"❌ Profile okunamadı!")
        
        # Cleanup - delete user
        print(f"\n🧹 Temizlik yapılıyor...")
        try:
            client.auth.admin.delete_user(user_id)
            print(f"✅ Test kullanıcısı silindi")
        except Exception as cleanup_error:
            print(f"⚠️  Kullanıcı silinemedi: {str(cleanup_error)}")
        
    except Exception as e:
        print(f"\n❌ Hata oluştu!")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    asyncio.run(test_signup_flow())

