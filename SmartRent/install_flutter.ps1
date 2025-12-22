# Flutter Kurulum Script'i - Windows PowerShell
# Bu script'i yönetici olarak çalıştırın: Right-click → "Run as Administrator"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter Kurulum Script'i" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Flutter kurulum klasörü
$flutterPath = "C:\src\flutter"
$flutterZipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.0-stable.zip"
$flutterZipPath = "$env:TEMP\flutter_windows.zip"

# 1. Flutter klasörünü oluştur
Write-Host "[1/5] Flutter klasörü oluşturuluyor..." -ForegroundColor Yellow
if (-not (Test-Path "C:\src")) {
    New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
}

# 2. Flutter SDK'yı indir
Write-Host "[2/5] Flutter SDK indiriliyor (bu biraz zaman alabilir)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $flutterZipUrl -OutFile $flutterZipPath -UseBasicParsing
    Write-Host "✅ İndirme tamamlandı!" -ForegroundColor Green
} catch {
    Write-Host "❌ İndirme hatası: $_" -ForegroundColor Red
    Write-Host "Manuel olarak indirin: $flutterZipUrl" -ForegroundColor Yellow
    exit 1
}

# 3. Flutter SDK'yı çıkar
Write-Host "[3/5] Flutter SDK çıkarılıyor..." -ForegroundColor Yellow
if (Test-Path $flutterPath) {
    Write-Host "⚠️  Flutter zaten kurulu görünüyor: $flutterPath" -ForegroundColor Yellow
    $overwrite = Read-Host "Üzerine yazmak istiyor musunuz? (y/n)"
    if ($overwrite -ne "y") {
        Write-Host "Kurulum iptal edildi." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item -Path $flutterPath -Recurse -Force
}

Expand-Archive -Path $flutterZipPath -DestinationPath "C:\src" -Force
Remove-Item -Path $flutterZipPath -Force
Write-Host "✅ Çıkarma tamamlandı!" -ForegroundColor Green

# 4. PATH'e ekle
Write-Host "[4/5] PATH'e ekleniyor..." -ForegroundColor Yellow
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$flutterPath\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterPath\bin", "Machine")
    Write-Host "✅ PATH'e eklendi!" -ForegroundColor Green
    Write-Host "⚠️  Yeni bir terminal açmanız gerekecek!" -ForegroundColor Yellow
} else {
    Write-Host "✅ PATH'te zaten var!" -ForegroundColor Green
}

# 5. Flutter doctor çalıştır
Write-Host "[5/5] Flutter doctor kontrol ediliyor..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "KURULUM TAMAMLANDI!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Şimdi yapmanız gerekenler:" -ForegroundColor Yellow
Write-Host "1. Bu terminali kapatın ve YENİ bir PowerShell açın" -ForegroundColor White
Write-Host "2. Şu komutu çalıştırın: flutter doctor" -ForegroundColor White
Write-Host "3. Eksikleri kurun (Android Studio, Visual Studio, vb.)" -ForegroundColor White
Write-Host ""
Write-Host "Flutter kurulum klasörü: $flutterPath" -ForegroundColor Cyan
Write-Host ""

# Not: Yeni terminal açılmadan flutter komutu çalışmayacak
Write-Host "⚠️  ÖNEMLİ: PATH değişikliği için YENİ bir terminal açmanız gerekiyor!" -ForegroundColor Red
Write-Host ""

