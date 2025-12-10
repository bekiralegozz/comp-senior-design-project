# 🚀 Hızlı Flutter Kurulum Rehberi

## Yöntem 1: Otomatik Script (Önerilen)

### Adımlar:

1. **PowerShell'i Yönetici Olarak Açın:**
   - Windows tuşu → "PowerShell" yazın
   - Sağ tık → **"Run as Administrator"**

2. **Script'i Çalıştırın:**
   ```powershell
   cd C:\Users\Lenovo\comp-senior-design-project\SmartRent
   .\install_flutter.ps1
   ```

3. **Yeni Terminal Açın:**
   - Script tamamlandıktan sonra terminali kapatın
   - **YENİ bir PowerShell açın** (normal, yönetici değil)

4. **Kontrol Edin:**
   ```powershell
   flutter --version
   flutter doctor
   ```

---

## Yöntem 2: Manuel Kurulum

### Adım 1: Flutter SDK İndir

1. Tarayıcıda açın: https://docs.flutter.dev/get-started/install/windows
2. **"flutter_windows_3.24.0-stable.zip"** dosyasını indirin
3. İndirilen zip'i **`C:\src\flutter`** klasörüne çıkarın

### Adım 2: PATH'e Ekle

1. Windows tuşu → **"Environment Variables"** yazın
2. **"Edit the system environment variables"** seçin
3. **"Environment Variables"** butonuna tıklayın
4. **"System variables"** → **"Path"** seçin → **"Edit"**
5. **"New"** → **`C:\src\flutter\bin`** ekleyin
6. Tüm pencereleri **OK** ile kapatın

### Adım 3: Kontrol

**YENİ bir PowerShell açın** (PATH değişikliği için):

```powershell
flutter --version
flutter doctor
```

---

## 📋 Sonraki Adımlar

### 1. Android Studio Kurulumu (Önerilir)

1. İndirin: https://developer.android.com/studio
2. Kurun (Standard installation)
3. Android SDK'yı kurun

### 2. Android Licenses

```powershell
flutter doctor --android-licenses
```

Tüm lisansları kabul edin (`y` + Enter).

### 3. Projeyi Test Et

```powershell
cd C:\Users\Lenovo\comp-senior-design-project\SmartRent\mobile
flutter pub get
flutter devices
flutter run
```

---

## ⚠️ Önemli Notlar

1. **PATH değişikliği** için terminal'i kapatıp yeniden açmanız gerekir
2. **Android Studio** kurulumu önerilir (emulator için)
3. **Visual Studio** Windows development için gerekli (opsiyonel)
4. İlk build uzun sürebilir, sabırlı olun

---

## 🐛 Sorun mu var?

Detaylı rehber için: `FLUTTER_SETUP_WINDOWS.md` dosyasına bakın.

---

**Kurulum tamamlandıktan sonra `flutter doctor` çıktısını paylaşın, eksikleri birlikte düzeltelim!** 🎯

