<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Google Play Store Publishing Guide for Lumos

Complete step-by-step guide to publish the Lumos Android app to Google Play Store.

## Overview

Lumos is a LAN-first remote power-control stack with:
- **lumos_app**: Flutter Android client for device discovery, pairing, and power control
- **lumos-agent**: Go service for Wake-on-LAN, power actions, relay, policy, and web admin (Windows/Linux)

The entire project is open source at: https://github.com/coff33ninja/lumos

This guide covers everything needed for a successful Play Store launch.

---

## 1. Prepare the Android Build

### 1.1 Verify Build Configuration

Check `lumos_app/android/app/build.gradle`:

```gradle
android {
    namespace "com.lumos.app"
    defaultConfig {
        applicationId "com.lumos.app"        // Already set
        versionCode 1                         // Current: 1 (from pubspec.yaml)
        versionName "1.1.0"                   // Current: 1.1.0 (from pubspec.yaml)
    }
}
```

**Current version**: 1.1.0+1 (as defined in `lumos_app/pubspec.yaml`)

### 1.2 Release Signing (CI-Only)

**IMPORTANT**: Lumos uses CI-only release signing via GitHub Actions. Local release builds are blocked by design.

The release workflow (`.github/workflows/release.yml`) handles:
- APK signing using `uber-apk-signer` in CI
- Environment variables for signing credentials:
  - `LUMOS_ANDROID_STORE_FILE`
  - `LUMOS_ANDROID_STORE_PASSWORD`
  - `LUMOS_ANDROID_KEY_ALIAS`
  - `LUMOS_ANDROID_KEY_PASSWORD`

If you need to set up signing for the first time:

```bash
keytool -genkey -v -keystore ~/lumos-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then configure the environment variables in GitHub Actions secrets.

**CRITICAL**: Back up your keystore and passwords securely. You'll need the same key for all future updates.

### 1.3 Build Release Bundle (AAB)

Google Play requires Android App Bundle format (not APK).

**For CI releases** (recommended):
- Push a tag matching `v*` (e.g., `v1.1.0`) to trigger the release workflow
- GitHub Actions will build and sign the AAB automatically
- Download from: https://github.com/coff33ninja/lumos/releases/latest

**For local testing** (unsigned):
```bash
cd lumos_app
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**Note**: Local release builds will fail signing checks. Use CI for production releases.

---

## 2. Google Play Developer Account Setup

### 2.1 Create Developer Account

1. Go to: https://play.google.com/console
2. Sign in with your Google account
3. Pay the one-time $25 registration fee
4. Complete identity verification (ID + selfie video may be required)

### 2.2 Complete Developer Profile

- Developer name
- Contact email
- Payment and tax information (for future monetization)

---

## 3. Create App in Play Console

### 3.1 Initialize App Entry

1. In Play Console: **All apps** → **Create app**
2. Fill in:
   - **App name**: Lumos
   - **Default language**: English
   - **App or Game**: App
   - **Free or Paid**: Free
   - Accept declarations
3. Click **Create app**

---

## 4. Complete Store Listing

### 4.1 App Details

Navigate to **Store presence** → **Main store listing**

#### Short Description (80 characters max)
```
LAN-first power control: Wake, shutdown, and manage your network devices.
```

#### Full Description
```
Lumos puts your local network in your pocket.

A LAN-first remote power-control stack for discovering, monitoring, and controlling devices on your home or office network — with no mandatory cloud dependency.

FEATURES
• Automatic device discovery via mDNS
• Wake-on-LAN: remotely power on your PCs and servers
• Power control: shutdown, reboot, sleep
• Token-based authentication with scope control
• Policy-driven command permissions
• Peer relay for multi-agent orchestration
• Works across VPN networks (e.g., Tailscale)
• 100% local — no accounts, no mandatory cloud

DESIGNED FOR
• Home lab enthusiasts
• Network administrators
• Smart home power users
• Anyone who wants direct control of their LAN devices

PRIVACY FIRST
Lumos never sends data outside your network. No tracking, no analytics, no backend. Everything stays local.

OPEN SOURCE
The companion Windows/Linux Go agent is fully open source:
https://github.com/coff33ninja/lumos

Requires Android 6.0+. Works on Wi-Fi and VPN networks.
```

### 4.2 Graphics Assets

Prepare and upload:

| Asset | Specification | Notes |
|-------|--------------|-------|
| App icon | 512×512 PNG, 32-bit | No rounded corners (Play handles that) |
| Feature graphic | 1024×500 PNG/JPG | Shows app UI on branded background |
| Phone screenshots | Min 2, max 8 | Device list, WoL action, settings |

**Screenshot suggestions**:
1. Device discovery list (showing online/offline devices)
2. Individual device control screen (Wake, Shutdown actions)
3. Settings / pairing screen
4. Dark mode (if available)

### 4.3 Contact Details

- **Email**: Your developer email
- **Website**: GitHub repository URL
- **Privacy Policy**: URL to hosted privacy policy (see section 5)

---

## 5. Privacy Policy

### 5.1 Create Privacy Policy Document

Create a file `privacy-policy.html` or `privacy-policy.md`:

```markdown
# Privacy Policy — Lumos

Last updated: March 2026

Lumos is a LAN-first remote power-control application for discovering and controlling devices on your local network using mDNS, Wake-on-LAN, and power management commands.

## Data Collection

Lumos does not collect, store, or transmit any personal data to external servers. All communication occurs locally within the user's private network or VPN.

## Device Information

Device names, IP addresses, MAC addresses, and authentication tokens entered or discovered by the app are stored locally on your Android device only using SharedPreferences. This data is never uploaded to any external server.

## Network Access

The app uses your local Wi-Fi network (or VPN connection) solely to:
- Discover Lumos agents via mDNS
- Communicate with agents you have paired with
- Send power control commands (wake, shutdown, reboot, sleep)

All network communication stays within your private network or VPN tunnel.

## Authentication

The app uses a password-based pairing flow to generate long-lived authentication tokens. These tokens are stored locally on your device and are used for day-to-day operations. Passwords are never stored permanently.

## Third-Party Services

Lumos does not use:
- Analytics services
- Advertising networks
- Crash reporting services
- Third-party SDKs that collect data

## Open Source

The entire Lumos project is open source and available at:
https://github.com/coff33ninja/lumos

The companion Windows/Linux agent (lumos-agent) is written in Go and is fully auditable.

## Contact

For questions or security concerns: [your-email]

For security vulnerabilities, please use GitHub Security Advisories:
https://github.com/coff33ninja/lumos/security/advisories
```

### 5.2 Host Privacy Policy

Options:
- **GitHub Pages**: Commit to `docs/` folder and enable GitHub Pages
- **Your own domain**: Host on your website
- **Notion**: Create a public page

Get the URL and add it to Play Console → **App content** → **Privacy policy**

---

## 6. App Content Declarations

### 6.1 Data Safety Form

Navigate to **App content** → **Data safety**

| Question | Answer |
|----------|--------|
| Does your app collect or share user data? | **No** |
| Does your app use encryption? | **Yes** — standard (HTTPS/TLS via Flutter) |
| Is your app a VPN? | **No** |

### 6.2 Target Audience

Navigate to **App content** → **Target audience & content**

- **Primarily directed at children?**: No
- **Target age group**: 18+

### 6.3 Content Rating

Navigate to **App content** → **Content rating**

Complete the questionnaire:

| Question | Answer |
|----------|--------|
| Violence | None |
| Sexual content | None |
| Controlled substances | None |
| Profanity | None |
| Gambling | None |

**Expected rating**: Everyone

### 6.4 Ads Declaration

Navigate to **App content** → **Ads**

- **Does your app contain ads?**: No (assuming Lumos has no ads)

---

## 7. Permissions Audit

### 7.1 Required Permissions (Safe)

Current permissions in `lumos_app/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

These are normal and safe:
- `INTERNET`: Required for network communication with agents
- `ACCESS_NETWORK_STATE`: Check network connectivity status
- `WAKE_LOCK`: Keep device awake during network operations

Google won't flag these permissions.

### 7.2 Remove Dangerous Permissions

If present, remove:
- `REQUEST_INSTALL_PACKAGES`
- `SYSTEM_ALERT_WINDOW`
- `QUERY_ALL_PACKAGES`

These trigger manual review and are unnecessary for Lumos.

---

## 8. Upload and Release

### 8.1 Internal Testing (Recommended First)

1. Navigate to **Release** → **Testing** → **Internal testing**
2. Click **Create new release**
3. Enable **Play App Signing** when prompted
4. Upload `app-release.aab`
5. Add release notes:
   ```
   Initial release of Lumos v1.0.0
   - Local network device discovery via mDNS
   - Wake-on-LAN support
   - Clean device management interface
   ```
6. Add testers (your Gmail or Google Group)
7. Click **Review release** → **Start rollout to Internal testing**

### 8.2 Test Internal Build

1. Install from Play Store on your test device
2. Verify mDNS discovery works
3. Test Wake-on-LAN functionality
4. Check all UI screens

### 8.3 Production Release

Once internal testing passes:

1. Navigate to **Release** → **Production**
2. Click **Create new release**
3. Upload the same `app-release.aab` (or rebuild with same versionCode)
4. Add release notes
5. Choose **Countries/regions**: "Available in all countries" (or select specific ones)
6. Complete any remaining checklist items
7. Click **Review release** → **Start rollout to Production**

---

## 9. Review Process

### 9.1 Timeline

- **First app review**: 1-3 days (sometimes longer for new accounts)
- **Updates**: Usually faster (hours to 1 day)

### 9.2 Common Rejection Reasons (Pre-empted)

| Risk | Status for Lumos |
|------|------------------|
| No privacy policy | ✅ Covered above |
| Crash on launch | ✅ Test via Internal track first |
| Misleading description | ✅ Description is accurate |
| Dangerous permissions | ✅ None present |
| Login required, no demo account | ✅ No login in Lumos |
| Copyright content | ✅ N/A |

### 9.3 If Rejected

- Check email for specific policy violation
- Update app, listing, or privacy policy as needed
- Resubmit with explanation

---

## 10. Post-Launch Maintenance

### 10.1 Version Management

For each update:

1. Increment `versionCode` in `build.gradle` (e.g., 1 → 2)
2. Update `versionName` (e.g., "1.0.0" → "1.1.0")
3. Build new AAB: `flutter build appbundle --release`
4. Upload to Production with release notes

### 10.2 CI/CD Integration (Optional)

After first manual upload, you can automate future releases:

- Use Google Play Developer API
- Wire GitHub Actions to upload AABs to Internal/Production tracks
- Tag releases in Git (e.g., `v1.1.0`) to trigger auto-publish

### 10.3 Keep Policies Updated

If you add:
- Analytics or crash reporting
- Remote control from outside LAN
- Cloud features
- User accounts

Update:
- Privacy policy
- Data Safety form
- Permissions in AndroidManifest.xml

---

## 11. Pre-Submission Checklist

Before clicking "Submit for review":

- [ ] `versionCode` and `versionName` set correctly
- [ ] Built with `flutter build appbundle --release`
- [ ] Signed with upload keystore (backed up securely)
- [ ] Privacy policy URL live and accessible
- [ ] App icon 512×512 uploaded
- [ ] Feature graphic 1024×500 uploaded
- [ ] At least 2 phone screenshots uploaded
- [ ] Data Safety form completed
- [ ] Content rating survey completed
- [ ] Target audience set to 18+ / not for children
- [ ] Release notes added
- [ ] Tested via Internal Testing track on real device
- [ ] All checklist items in Play Console marked complete

---

## 12. Package Name

Current package name (already configured):

```
com.lumos.app
```

This is set in `lumos_app/android/app/build.gradle` and must remain consistent for all future updates.

---

## 13. Resources

- **Play Console**: https://play.google.com/console
- **Flutter Release Docs**: https://docs.flutter.dev/deployment/android
- **Play App Signing**: https://support.google.com/googleplay/android-developer/answer/9842756
- **Data Safety Guide**: https://support.google.com/googleplay/android-developer/answer/10787469
- **Lumos Repository**: https://github.com/coff33ninja/lumos
- **Lumos Releases**: https://github.com/coff33ninja/lumos/releases/latest
- **Lumos Documentation**: https://github.com/coff33ninja/lumos/tree/main/docs

---

## 14. Project-Specific Notes

### Current Release
- **Version**: v1.1.0 (stable)
- **Package**: com.lumos.app
- **Min SDK**: Android 6.0+
- **Target SDK**: 36

### Key Features
- mDNS device discovery (`_lumos-agent._tcp`)
- Wake-on-LAN support
- Power control (shutdown, reboot, sleep)
- Token-based authentication with scopes (power-admin, wake-only, read-only)
- Policy management for fine-grained action control
- Peer relay for multi-agent orchestration
- VPN support (tested with Tailscale)

### Architecture
- **Frontend**: Flutter (Dart) - Android app
- **Backend**: Go - Windows/Linux agent
- **Storage**: SharedPreferences (local device storage)
- **Network**: HTTP/HTTPS REST API + WebSocket events
- **Discovery**: mDNS multicast DNS

### Security Posture
- LAN-first design with optional VPN support
- No mandatory cloud dependency
- Auto-generated secure credentials on first run
- Token-based auth with rate limiting
- Optional TLS support
- Encrypted state files
- Open source and auditable

### Why Google Should Approve
- Clean permission set (INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK)
- No sensitive permissions
- No data collection or analytics
- Clear privacy policy
- Open source project
- Legitimate use case (network administration)
- No misleading claims

---

**Good luck with your launch! 🚀**

