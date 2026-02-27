# Build Lumos APK
Write-Host "Building Lumos APK..." -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes on first build..." -ForegroundColor Yellow
Write-Host ""

# Build the APK
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "APK location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
    
    # Show APK size
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $size = (Get-Item $apkPath).Length / 1MB
        Write-Host "APK size: $([math]::Round($size, 2)) MB" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "Build failed!" -ForegroundColor Red
    Write-Host "Check the error messages above." -ForegroundColor Yellow
}
