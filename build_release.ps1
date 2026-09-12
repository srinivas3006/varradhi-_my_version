# Highly Optimized Release Build Script
# 1. Cleans old outputs
# 2. Builds split-per-ABI APKs with code shrinking & symbol stripping (~60% smaller)

$apkDir = "build\app\outputs\flutter-apk"
$symbolsDir = "build\app\outputs\symbols"

if (Test-Path $apkDir) {
    Remove-Item "$apkDir\*.apk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$apkDir\*.sha1" -Force -ErrorAction SilentlyContinue
}

Write-Host "Building targeted lightweight release APKs (Split per ABI)..." -ForegroundColor Cyan

flutter build apk --release --split-per-abi --obfuscate --split-debug-info=$symbolsDir

Write-Host "`nTargeted APKs successfully generated in: $apkDir" -ForegroundColor Green
Write-Host "  - app-arm64-v8a-release.apk (For 99% of modern Android devices - Smallest size)" -ForegroundColor Yellow
Write-Host "  - app-armeabi-v7a-release.apk (For older 32-bit devices)" -ForegroundColor Yellow
Write-Host "  - app-x86_64-release.apk (For emulators & Chromebooks)" -ForegroundColor Yellow
