"""
Supabase configuration checker
Shows current Supabase settings
"""

import os
from app.core.config import settings

print("\n" + "=" * 60)
print("🔍 Mevcut Supabase Konfigürasyonu")
print("=" * 60)

print(f"\n📋 SUPABASE_URL:")
print(f"   {settings.SUPABASE_URL if settings.SUPABASE_URL else '❌ Ayarlanmamış (boş)'}")

print(f"\n📋 SUPABASE_ANON_KEY:")
anon_key = settings.SUPABASE_ANON_KEY
if anon_key:
    print(f"   ✅ Ayarlanmış ({len(anon_key)} karakter)")
    print(f"   İlk 20 karakter: {anon_key[:20]}...")
else:
    print(f"   ❌ Ayarlanmamış (boş)")

print(f"\n📋 SUPABASE_SERVICE_ROLE_KEY:")
service_key = settings.SUPABASE_SERVICE_ROLE_KEY
if service_key:
    print(f"   ✅ Ayarlanmış ({len(service_key)} karakter)")
    print(f"   İlk 20 karakter: {service_key[:20]}...")
else:
    print(f"   ❌ Ayarlanmamış (boş)")

print(f"\n📋 SUPABASE_EMAIL_REDIRECT_TO:")
print(f"   {settings.SUPABASE_EMAIL_REDIRECT_TO if settings.SUPABASE_EMAIL_REDIRECT_TO else 'Ayarlanmamış'}")

print(f"\n📋 SUPABASE_JWT_AUDIENCE:")
print(f"   {settings.SUPABASE_JWT_AUDIENCE}")

print("\n" + "=" * 60)
print("📝 Not: Bu değerler .env dosyasından veya environment")
print("   değişkenlerinden okunuyor. .env dosyası yoksa")
print("   default değerler (boş) kullanılıyor.")
print("=" * 60 + "\n")

