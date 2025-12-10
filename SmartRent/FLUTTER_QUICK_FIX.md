# 🚀 Flutter Hızlı Kurulum - Alternatif Yöntemler

## Durum Kontrolü

Script hangi adımda takıldı?
- [ ] İndirme (zip dosyası)
- [ ] Çıkarma (unzip)
- [ ] PATH ekleme

---

## Yöntem 1: Git ile Clone (Önerilen - Daha Hızlı)

### Gereksinim: Git kurulu olmalı

```powershell
# Git kontrolü
git --version

# Eğer Git yoksa: https://git-scm.com/download/win
```

### Kurulum:

```powershell
# PowerShell'i Yönetici olarak açın
cd C:\Users\Lenovo\comp-senior-design-project\SmartRent
.\install_flutter_fast.ps1
```

**Avantajlar:**
- Daha hızlı (sadece gerekli dosyalar)
- Güncelleme kolay (`flutter upgrade`)
- Daha az disk alanı

---

## Yöntem 2: Manuel İndirme (En Güvenilir)

### Adımlar:

1. **Tarayıcıda açın:**
   ```
   https://docs.flutter.dev/get-started/install/windows
   ```

2. **"Get the Flutter SDK"** bölümünden:
   - **"flutter_windows_3.24.0-stable.zip"** dosyasını indirin
   - Veya direkt link: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.0-stable.zip

3. **İndirilen zip'i çıkarın:**
   - `C:\src\flutter` klasörüne çıkarın
   - ⚠️ **ÖNEMLİ:** `C:\src\flutter\flutter\` değil, direkt `C:\src\flutter\` olmalı!

4. **PATH'e ekleyin:**
   - Windows tuşu → "Environment Variables"
   - System variables → Path → Edit
   - New → `C:\src\flutter\bin` ekleyin

5. **Yeni terminal açın:**
   ```powershell
   flutter --version
   flutter doctor
   ```

---

## Yöntem 3: Chocolatey ile (En Kolay)

### Gereksinim: Chocolatey kurulu olmalı

```powershell
# Chocolatey kontrolü
choco --version

# Eğer yoksa: https://chocolatey.org/install
```

### Kurulum:

```powershell
# PowerShell'i Yönetici olarak açın
choco install flutter -y
```

**Avantajlar:**
- Tek komut
- Otomatik PATH ekleme
- Güncelleme kolay

---

## Hızlı Kontrol

Kurulum tamamlandıktan sonra:

```powershell
# YENİ bir PowerShell açın (PATH için)
flutter --version
flutter doctor
```

---

## Sorun Giderme

### Sorun: "flutter: command not found"

**Çözüm:**
1. PATH'e eklendiğinden emin olun: `C:\src\flutter\bin`
2. Terminal'i kapatıp yeniden açın
3. PowerShell'i yönetici olarak açmayı deneyin

### Sorun: İndirme çok yavaş

**Çözüm:**
- Git ile clone yöntemini kullanın (daha hızlı)
- Veya tarayıcıdan manuel indirin

### Sorun: "Git not found"

**Çözüm:**
- Git'i kurun: https://git-scm.com/download/win
- Veya manuel indirme yöntemini kullanın

---

## Hangi Yöntemi Seçmeliyim?

- **Git kuruluysa** → Yöntem 1 (Git ile clone) - En hızlı
- **Git yoksa ama internet hızlıysa** → Yöntem 2 (Manuel indirme) - En güvenilir
- **Chocolatey kullanıyorsanız** → Yöntem 3 - En kolay

---

**Hangi yöntemi denemek istersiniz?** 🎯

