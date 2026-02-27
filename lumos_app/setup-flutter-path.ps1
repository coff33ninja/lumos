# Setup Flutter PATH
$flutterPath = "E:\FLUTTER\flutter\bin"

# Get current user PATH
$currentPath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)

# Check if Flutter is already in PATH
if ($currentPath -notlike "*$flutterPath*") {
    Write-Host "Adding Flutter to PATH..." -ForegroundColor Green
    
    # Add Flutter to PATH
    $newPath = $currentPath + ";" + $flutterPath
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, [System.EnvironmentVariableTarget]::User)
    
    Write-Host "Flutter added to PATH successfully!" -ForegroundColor Green
    Write-Host "Please restart PowerShell or VS Code for changes to take effect." -ForegroundColor Yellow
}
else {
    Write-Host "Flutter is already in PATH!" -ForegroundColor Cyan
}

# Refresh PATH in current session
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)

Write-Host "`nTesting Flutter..." -ForegroundColor Cyan
& "$flutterPath\flutter.exe" --version
