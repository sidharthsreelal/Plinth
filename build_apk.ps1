# GrooveLocal - Build Script
# Run this after Flutter SDK is fully installed

# Add Flutter to PATH
$env:Path = "$env:USERPROFILE\flutter\bin;$env:Path"

# Navigate to project
Set-Location -Path "D:\Projects\Plinth\groovelocal"

# Step 1: Get dependencies
Write-Host "Step 1: Getting dependencies..." -ForegroundColor Cyan
flutter pub get

# Step 2: Build debug APK (faster, no signing required)
Write-Host "`nStep 2: Building debug APK..." -ForegroundColor Cyan
flutter build apk --debug

# Step 3: If you want release APK (requires signing setup)
# Write-Host "`nStep 3: Building release APK..." -ForegroundColor Cyan
# flutter build apk --release --no-shrink

Write-Host "`nBuild complete! APK location:" -ForegroundColor Green
Write-Host "D:\Projects\Plinth\groovelocal\build\outputs\flutter-apk\app-debug.apk" -ForegroundColor Yellow
