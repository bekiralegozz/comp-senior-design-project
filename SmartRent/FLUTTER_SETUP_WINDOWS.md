# Flutter Kurulum Rehberi - Windows

## 🎯 Hedef
SmartRent mobile uygulamasını çalıştırabilmek için Flutter ve gerekli tüm araçları kurmak.

---

## 📋 Gereksinimler

- Windows 10 veya üzeri
- En az 2 GB boş disk alanı
- İnternet bağlantısı

---

## 🔧 Adım Adım Kurulum

### 1. Flutter SDK Kurulumu

#### 1.1 Flutter SDK İndirme

1. **Flutter SDK'yı indirin:**
   - https://docs.flutter.dev/get-started/install/windows
   - Veya direkt: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.0-stable.zip

2. **İndirilen zip dosyasını açın:**
   - Örnek: `C:\src\flutter` klasörüne çıkarın
   - ⚠️ **ÖNEMLİ:** `C:\Program Files\` gibi korumalı klasörlere kurmayın!

#### 1.2 PATH'e Ekleme

1. **Windows Arama** → "Environment Variables" yazın
2. **"Edit the system environment variables"** seçin
3. **"Environment Variables"** butonuna tıklayın
4. **"System variables"** altında **"Path"** seçin → **"Edit"**
5. **"New"** butonuna tıklayın
6. Flutter bin klasörünü ekleyin: `C:\src\flutter\bin`
7. **OK** ile tüm pencereleri kapatın

#### 1.3 Kurulumu Doğrulama

**Yeni bir PowerShell/Terminal açın** (PATH değişikliği için gerekli):

```powershell
flutter --version
```

Eğer Flutter versiyonu görünüyorsa ✅ kurulum başarılı!

---

### 2. Flutter Doctor Kontrolü

Flutter'ın eksik bağımlılıklarını kontrol edin:

```powershell
flutter doctor
```

**Beklenen çıktı:**
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.24.0, on Microsoft Windows [Version 10.0.26200])
[✓] Windows Version (Installed version of Windows is version 10 or higher)
[✓] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✓] Visual Studio - develop for Windows
[✓] Android Studio (not installed)
[✓] VS Code (not installed)
[✓] Connected device
[✓] Network resources
```

**Eksikler varsa:**
- Android Studio kurulumu gerekebilir
- Android SDK kurulumu gerekebilir
- Visual Studio kurulumu gerekebilir (Windows development için)

---

### 3. Android Studio Kurulumu (Önerilir)

#### 3.1 Android Studio İndirme

1. **Android Studio'yu indirin:**
   - https://developer.android.com/studio
   - İndirilen `.exe` dosyasını çalıştırın

2. **Kurulum:**
   - **"Standard"** kurulum seçin
   - Android SDK, Android SDK Platform, Android Virtual Device otomatik kurulur

#### 3.2 Android SDK Kurulumu

1. **Android Studio'yu açın**
2. **"More Actions"** → **"SDK Manager"**
3. **"SDK Platforms"** sekmesinde:
   - ✅ Android 14.0 (API 34) veya en son sürüm
   - ✅ Android SDK Platform-Tools
4. **"SDK Tools"** sekmesinde:
   - ✅ Android SDK Build-Tools
   - ✅ Android SDK Command-line Tools
   - ✅ Android Emulator
5. **"Apply"** → **"OK"**

#### 3.3 Android License Kabulü

```powershell
flutter doctor --android-licenses
```

Tüm lisansları kabul edin (`y` yazıp Enter).

---

### 4. Visual Studio Kurulumu (Windows Development İçin)

Eğer Windows'ta uygulama çalıştırmak istiyorsanız:

1. **Visual Studio 2022 Community** indirin:
   - https://visualstudio.microsoft.com/downloads/
   - **"Desktop development with C++"** workload'unu seçin

2. **Kurulum:**
   - Visual Studio Installer'ı çalıştırın
   - **"Desktop development with C++"** seçin
   - **"Install"**

---

### 5. Flutter Doctor Tekrar Kontrol

Tüm kurulumlar tamamlandıktan sonra:

```powershell
flutter doctor -v
```

Tüm eksikleri kontrol edin ve düzeltin.

---

### 6. Projeyi Test Etme

#### 6.1 Proje Klasörüne Gitme

```powershell
cd C:\Users\Lenovo\comp-senior-design-project\SmartRent\mobile
```

#### 6.2 Dependencies Yükleme

```powershell
flutter pub get
```

#### 6.3 Cihaz Kontrolü

**Fiziksel cihaz:**
```powershell
flutter devices
```

**Emulator başlatma:**
1. Android Studio → **"Device Manager"**
2. **"Create Device"** → Bir emulator oluşturun
3. Emulator'ü başlatın

#### 6.4 Uygulamayı Çalıştırma

```powershell
flutter run
```

Veya belirli bir cihaz için:
```powershell
flutter run -d <device-id>
```

---

## 🐛 Yaygın Sorunlar ve Çözümleri

### Sorun 1: "flutter: command not found"

**Çözüm:**
- PATH'e Flutter bin klasörünü eklediğinizden emin olun
- Terminal'i kapatıp yeniden açın
- PowerShell'i **yönetici olarak** çalıştırmayı deneyin

### Sorun 2: "Android SDK not found"

**Çözüm:**
```powershell
flutter config --android-sdk "C:\Users\<KullanıcıAdı>\AppData\Local\Android\Sdk"
```

### Sorun 3: "Android license not accepted"

**Çözüm:**
```powershell
flutter doctor --android-licenses
```

Tüm lisansları kabul edin.

### Sorun 4: "Gradle build failed"

**Çözüm:**
```powershell
cd android
.\gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### Sorun 5: "No devices found"

**Çözüm:**
- USB debugging'i açın (fiziksel cihaz için)
- Emulator'ü başlatın
- `flutter devices` komutuyla cihazları kontrol edin

---

## ✅ Kurulum Kontrol Listesi

- [ ] Flutter SDK kuruldu
- [ ] PATH'e eklendi
- [ ] `flutter --version` çalışıyor
- [ ] `flutter doctor` çalıştırıldı
- [ ] Android Studio kuruldu (veya Android SDK)
- [ ] Android licenses kabul edildi
- [ ] Visual Studio kuruldu (Windows development için)
- [ ] `flutter pub get` başarılı
- [ ] Cihaz/Emulator bağlı
- [ ] `flutter run` çalışıyor

---

## 🚀 Hızlı Başlangıç Komutları

```powershell
# Flutter versiyonunu kontrol et
flutter --version

# Eksikleri kontrol et
flutter doctor

# Proje dependencies yükle
cd SmartRent\mobile
flutter pub get

# Cihazları listele
flutter devices

# Uygulamayı çalıştır
flutter run

# Clean build
flutter clean
flutter pub get
```

---

## 📚 Ek Kaynaklar

- [Flutter Windows Installation](https://docs.flutter.dev/get-started/install/windows)
- [Flutter Doctor](https://docs.flutter.dev/tools/flutter-tool)
- [Android Studio Setup](https://developer.android.com/studio)

---

## 💡 İpuçları

1. **PATH değişiklikleri** için terminal'i kapatıp yeniden açın
2. **Android Studio** kurulumu önerilir (SDK yönetimi kolay)
3. **Emulator** kullanmak için Android Studio gerekli
4. **Fiziksel cihaz** kullanmak için USB debugging açık olmalı
5. **Gradle** ilk build'de uzun sürebilir, sabırlı olun

---

**Kurulum tamamlandıktan sonra `flutter doctor` komutunu çalıştırıp sonucu paylaşın, eksikleri birlikte düzeltelim!** 🎯

