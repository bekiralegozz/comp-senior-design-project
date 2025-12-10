# Flutter uygulamasını Chrome'da başlat
# Bu script'i mobile klasöründe çalıştırın

# Doğru klasöre git
$mobilePath = "C:\Users\Lenovo\comp-senior-design-project\SmartRent\mobile"
Set-Location $mobilePath

# PATH'i güncelle
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Kontrol
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "❌ HATA: pubspec.yaml bulunamadı!" -ForegroundColor Red
    Write-Host "Mevcut klasör: $(Get-Location)" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ pubspec.yaml bulundu" -ForegroundColor Green
Write-Host "📁 Klasör: $(Get-Location)" -ForegroundColor Cyan
Write-Host "🚀 Chrome'da başlatılıyor..." -ForegroundColor Cyan
Write-Host ""

# Flutter'ı Chrome'da çalıştır
flutter run -d chrome
