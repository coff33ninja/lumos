<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos App - Setup Guide

Complete guide to set up the Flutter development environment and build the Lumos mobile app.

## Prerequisites

- Windows 10/11
- Android Studio (already installed)
- Flutter SDK (already installed at `C:\Users\HLTWO\flutter`)
- Git (required by Flutter)

---

## Step 1: Add Flutter to PATH

Flutter is installed but not accessible from command line. We need to add it to your system PATH.

### Automatic Setup (Recommended)

Run the provided PowerShell script:

```powershell
.\setup-flutter-path.ps1
```

This script will:
- Add `C:\Users\HLTWO\flutter\bin` to your user PATH
- Verify Flutter installation
- Test Flutter command

### Manual Setup (Alternative)

If you prefer to do it manually:

1. Open **System Properties** → **Environment Variables**
2. Under **User variables**, select **Path** and click **Edit**
3. Click **New** and add: `C:\Users\HLTWO\flutter\bin`
4. Click **OK** to save
5. Restart PowerShell/VS Code

---

## Step 2: Install Git

Flutter requires Git to be installed and accessible.

### Using winget (Recommended)

```powershell
winget install --id Git.Git -e --source winget
```

### Manual Installation

1. Download Git from: https://git-scm.com/download/win
2. Run the installer with default options
3. Restart PowerShell/VS Code

---

## Step 3: Restart Terminal

**Important**: Close and reopen your PowerShell or VS Code terminal for PATH changes to take effect.

---

## Step 4: Verify Flutter Installation

After restarting your terminal, verify Flutter is working:

```powershell
flutter --version
```

Expected output:
```
Flutter 3.x.x • channel stable • https://github.com/flutter/flutter.git
Framework • revision xxxxx
Engine • revision xxxxx
Tools • Dart 3.x.x • DevTools 2.x.x
```

---

## Step 5: Run Flutter Doctor

Check what dependencies are missing:

```powershell
flutter doctor
```

This will show:
- ✓ Flutter SDK
- ✓ Android toolchain
- ✓ VS Code
- ✓ Connected devices

If anything is marked with ✗, follow the instructions provided by `flutter doctor` to fix it.

### Common Issues

**Android licenses not accepted:**
```powershell
flutter doctor --android-licenses
```
Press `y` to accept all licenses.

**Android SDK not found:**
- Open Android Studio
- Go to **Tools** → **SDK Manager**
- Ensure Android SDK is installed

---

## Step 6: Install Dependencies

Navigate to the Lumos app directory and install Flutter packages:

```powershell
cd C:\scipts\wolx\lumos_app
flutter pub get
```

This will download all dependencies listed in `pubspec.yaml`:
- http
- provider
- shared_preferences
- flutter_secure_storage
- multicast_dns (for mDNS agent discovery)
- uuid

---

## Step 7: Run the App (Development)

### On Android Emulator

1. Open Android Studio
2. Go to **Tools** → **Device Manager**
3. Create or start an Android Virtual Device (AVD)
4. Run the app:

```powershell
flutter run
```

### On Physical Android Device

1. Enable **Developer Options** on your Android device:
   - Go to **Settings** → **About Phone**
   - Tap **Build Number** 7 times
2. Enable **USB Debugging** in Developer Options
3. Connect device via USB
4. Run the app:

```powershell
flutter run
```

### On Chrome (Web - for UI testing only)

```powershell
flutter run -d chrome
```

**Note**: Network features won't work in web mode.

---

## Step 8: Build Release APK

Build the production-ready APK:

```powershell
flutter build apk --release
```

### Build Output

The APK will be created at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### APK Size

Expected size: ~15-20 MB

### Install APK on Device

Transfer the APK to your Android device and install it, or use:

```powershell
flutter install
```

---

## Step 9: Build App Bundle (for Google Play)

If you plan to publish to Google Play Store:

```powershell
flutter build appbundle --release
```

Output location:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## Troubleshooting

### Devices not discovered

**mDNS Discovery:**
- Ensure agent has `mdns_enabled: true` in config
- Check agent is running and accessible
- Verify devices are on same network/subnet
- Some networks block multicast traffic

**Manual Scanning:**
- Check agent is running
- Verify firewall allows port 8080
- Ensure on same network

### Flutter command not found

**Solution**: Restart your terminal after adding Flutter to PATH.

### Git not found

**Solution**: Install Git and restart terminal.

### Android licenses not accepted

**Solution**: Run `flutter doctor --android-licenses`

### Gradle build failed

**Solution**: 
```powershell
cd android
.\gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### Dependencies not resolving

**Solution**:
```powershell
flutter clean
flutter pub cache repair
flutter pub get
```

### Emulator not starting

**Solution**:
- Open Android Studio
- Go to **Tools** → **Device Manager**
- Delete and recreate the AVD
- Ensure virtualization is enabled in BIOS

### Build errors after code changes

**Solution**:
```powershell
flutter clean
flutter pub get
flutter run
```

---

## Development Workflow

### Hot Reload

While the app is running, press `r` in the terminal to hot reload changes without restarting.

### Hot Restart

Press `R` (capital R) to fully restart the app.

### Debugging

1. Set breakpoints in VS Code
2. Press `F5` or use **Run → Start Debugging**
3. Use Flutter DevTools for advanced debugging

### Code Analysis

Check for issues:
```powershell
flutter analyze
```

### Format Code

Auto-format Dart code:
```powershell
flutter format lib/
```

---

## VS Code Extensions (Recommended)

Make sure you have these installed:

1. **Flutter** (Dart-Code.flutter)
2. **Dart** (Dart-Code.dart-code)
3. **Flutter Widget Snippets** (optional)

---

## Project Structure

```
lumos_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/                      # Data models
│   ├── providers/                   # State management
│   ├── screens/                     # UI screens
│   ├── services/                    # API services
│   └── widgets/                     # Reusable widgets
├── android/                         # Android-specific files
├── pubspec.yaml                     # Dependencies
├── setup-flutter-path.ps1          # PATH setup script
└── README.md                        # Documentation
```

---

## Next Steps

1. ✅ Setup complete
2. ✅ Build APK
3. 📱 Install on device
4. 🔧 Configure Lumos agent on your PC
5. 🎮 Test wake/shutdown features
6. 🚀 Enjoy remote power control!

---

## Additional Resources

- **Flutter Documentation**: https://docs.flutter.dev
- **Dart Language**: https://dart.dev
- **Flutter Packages**: https://pub.dev
- **Lumos Agent API**: See `../lumos-agent/API_REFERENCE.md`

---

## Support

If you encounter issues:

1. Check `flutter doctor` output
2. Review error messages carefully
3. Search Flutter documentation
4. Check GitHub issues

---

**Last Updated**: 2026-02-23



