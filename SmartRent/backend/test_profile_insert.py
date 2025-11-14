"""
Test profile insertion into Supabase
"""

import sys
import os
from uuid import uuid4

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from app.core.supabase_client import get_supabase_client
    from app.core.config import settings
    
    print("\n" + "=" * 60)
    print("🔍 Supabase Profile Insert Test")
    print("=" * 60)
    
    client = get_supabase_client(use_service_role=True)
    
    # Test user ID
    test_user_id = str(uuid4())
    print(f"\n📋 Test User ID: {test_user_id}")
    
    # Test payload
    test_payload = {
        "id": test_user_id,
        "email": "test@example.com",
        "full_name": "Test User",
        "auth_provider": "email",
        "is_onboarded": False,
    }
    
    print(f"\n📤 Inserting test profile...")
    print(f"Payload: {test_payload}")
    
    try:
        # Try to insert
        table = client.table("profiles")
        response = table.insert(test_payload).execute()
        
        print(f"\n✅ Insert başarılı!")
        print(f"Response: {response.data}")
        
        # Try to read it back
        print(f"\n📥 Reading back the profile...")
        read_response = table.select("*").eq("id", test_user_id).execute()
        
        if read_response.data:
            print(f"✅ Profile okundu!")
            print(f"Data: {read_response.data[0]}")
        else:
            print(f"❌ Profile okunamadı!")
            
        # Clean up - delete test record
        print(f"\n🧹 Cleaning up test record...")
        delete_response = table.delete().eq("id", test_user_id).execute()
        print(f"✅ Test record silindi")
        
    except Exception as e:
        print(f"\n❌ Hata oluştu!")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        import traceback
        traceback.print_exc()
        
        # Check if table exists
        print(f"\n🔍 Tablo varlığını kontrol ediyorum...")
        try:
            # Try to select from table (even if empty)
            test_select = table.select("id").limit(1).execute()
            print(f"✅ Profiles tablosu mevcut")
        except Exception as select_error:
            print(f"❌ Profiles tablosu bulunamadı veya erişim hatası!")
            print(f"Error: {str(select_error)}")
            print(f"\n💡 Supabase dashboard'da profiles tablosunun oluşturulduğundan emin olun:")
            print(f"   https://supabase.com/dashboard/project/oajhrwleyhpeelbrdqdd/editor")
    
    print("\n" + "=" * 60)
    
except Exception as e:
    print(f"❌ Script hatası: {str(e)}")
    import traceback
    traceback.print_exc()

