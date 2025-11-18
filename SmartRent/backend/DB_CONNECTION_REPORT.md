# Veritabanı Bağlantı Durumu Raporu

## 📊 Mevcut Durum

### ❌ PostgreSQL
- **Durum**: Çalışmıyor
- **Port**: 5432 erişilebilir değil
- **Konfigürasyon**: `postgresql://smartrent:password@localhost:5432/smartrent_db`

### ⚠️ Supabase
- **Durum**: Konfigüre edilmemiş
- **Not**: Opsiyonel (sadece authentication için kullanılıyor)

## 🔧 Yapılan Düzeltmeler

1. ✅ **config.py düzeltildi**: `BaseSettings` import'u `pydantic_settings` paketinden yapılacak şekilde güncellendi
2. ✅ **Bağlantı kontrol scriptleri oluşturuldu**:
   - `check_db_connection.py`: Tam bağlantı testi (tüm bağımlılıklar gerekli)
   - `check_db_simple.py`: Basit port kontrolü (bağımlılık gerektirmez)

## 🚀 PostgreSQL'i Başlatma Seçenekleri

### Seçenek 1: Docker ile (Önerilen)

```bash
cd /Users/ardayalniz/comp-senior-design-project/SmartRent
docker-compose up db -d
```

Docker yüklü değilse, Docker Desktop'ı yükleyin: https://www.docker.com/products/docker-desktop

### Seçenek 2: Homebrew ile Yerel Kurulum

```bash
# PostgreSQL'i yükle
brew install postgresql@15

# Servisi başlat
brew services start postgresql@15

# Veritabanını oluştur
createdb smartrent_db
createuser smartrent
psql -c "ALTER USER smartrent WITH PASSWORD 'password';"
psql -c "GRANT ALL PRIVILEGES ON DATABASE smartrent_db TO smartrent;"
```

### Seçenek 3: SQLite (Geliştirme için)

Eğer PostgreSQL kurmak istemiyorsanız, geçici olarak SQLite kullanabilirsiniz:

`.env` dosyası oluşturun:
```bash
DATABASE_URL=sqlite:///./smartrent.db
```

**Not**: SQLite production için önerilmez, sadece geliştirme için uygundur.

## 📝 .env Dosyası Oluşturma

Backend dizininde `.env` dosyası oluşturun:

```bash
cd /Users/ardayalniz/comp-senior-design-project/SmartRent/backend
cat > .env << EOF
# Database
DATABASE_URL=postgresql://smartrent:password@localhost:5432/smartrent_db

# Supabase (Opsiyonel)
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Security
SECRET_KEY=your-secret-key-change-this-in-production

# Environment
ENVIRONMENT=development
DEBUG=true
EOF
```

## ✅ Bağlantıyı Test Etme

### Basit Kontrol (Bağımlılık gerektirmez):
```bash
cd /Users/ardayalniz/comp-senior-design-project/SmartRent/backend
python3 check_db_simple.py
```

### Tam Kontrol (Virtual environment gerekli):
```bash
cd /Users/ardayalniz/comp-senior-design-project/SmartRent/backend
source venv/bin/activate
pip install -r requirements.txt
python check_db_connection.py
```

## 🔍 Sorun Giderme

### PostgreSQL bağlantı hatası alıyorsanız:

1. **PostgreSQL çalışıyor mu kontrol edin:**
   ```bash
   # macOS
   brew services list | grep postgresql
   
   # Docker
   docker ps | grep postgres
   ```

2. **Port 5432 kullanımda mı kontrol edin:**
   ```bash
   lsof -i :5432
   ```

3. **Veritabanı ve kullanıcı var mı kontrol edin:**
   ```bash
   psql -U postgres -l  # Veritabanı listesi
   psql -U postgres -c "\du"  # Kullanıcı listesi
   ```

4. **Firewall ayarlarını kontrol edin** (eğer uzak sunucu kullanıyorsanız)

## 📚 İlgili Dosyalar

- `app/db/database.py`: SQLAlchemy veritabanı bağlantısı
- `app/core/config.py`: Konfigürasyon ayarları
- `app/core/supabase_client.py`: Supabase client
- `docker-compose.yml`: Docker konfigürasyonu

## 🎯 Sonraki Adımlar

1. PostgreSQL'i başlatın (yukarıdaki seçeneklerden biriyle)
2. `.env` dosyasını oluşturun
3. Bağlantıyı test edin: `python3 check_db_simple.py`
4. Tabloları oluşturun (uygulama ilk çalıştığında otomatik oluşturulur veya manuel):
   ```python
   from app.db.database import create_tables
   create_tables()
   ```

