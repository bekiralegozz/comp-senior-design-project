"""
Check Supabase profiles table structure
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from app.core.supabase_client import get_supabase_client
    from app.core.config import settings
    
    print("\n" + "=" * 60)
    print("🔍 Supabase Profiles Tablosu Kontrolü")
    print("=" * 60)
    
    client = get_supabase_client(use_service_role=True)
    
    # Try to get table structure
    try:
        # Get a sample row to see structure
        response = client.table("profiles").select("*").limit(1).execute()
        
        if response.data:
            print("\n✅ Profiles tablosu bulundu!")
            print("\n📋 Tablo Kolonları:")
            print("-" * 60)
            for key in response.data[0].keys():
                value = response.data[0][key]
                value_type = type(value).__name__
                print(f"  • {key}: {value_type}")
            print("-" * 60)
            
            # Show sample data
            print("\n📊 Örnek Veri:")
            import json
            print(json.dumps(response.data[0], indent=2, default=str))
        else:
            print("\n⚠️  Profiles tablosu boş, yapıyı kontrol ediyorum...")
            # Try to insert a test query to see what columns are expected
            print("   Tablo yapısını görmek için Supabase dashboard'unu kontrol edin.")
            
    except Exception as e:
        print(f"\n❌ Tablo sorgusu hatası: {str(e)}")
        print("\n💡 Alternatif: Supabase dashboard'dan tablo yapısını kontrol edin:")
        print("   https://supabase.com/dashboard/project/oajhrwleyhpeelbrdqdd/editor")
        
    # Try to get table info via RPC or direct query
    try:
        # Try to describe table structure
        print("\n🔍 Tablo yapısını analiz ediyorum...")
        # This might not work, but worth trying
        result = client.rpc('get_table_columns', {'table_name': 'profiles'}).execute()
        print("RPC sonucu:", result)
    except:
        pass
    
    print("\n" + "=" * 60)
    
except Exception as e:
    print(f"❌ Hata: {str(e)}")
    import traceback
    traceback.print_exc()

