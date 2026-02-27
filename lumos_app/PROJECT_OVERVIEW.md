<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos Mobile App - Project Overview

## What is Lumos?

Lumos is a modern, secure mobile application for controlling Lumos agents - providing Wake-on-LAN and remote power management capabilities for Windows and Linux machines. It's designed to be a superior alternative to Wolow with better security, design, and cross-platform support.

## Key Features

### Core Functionality
- **Wake-on-LAN**: Send magic packets to wake sleeping devices
- **Remote Shutdown**: Securely shutdown devices with password protection
- **Remote Reboot**: Restart devices remotely
- **Sleep Mode**: Put devices into sleep/suspend mode
- **Network Scanning**: Auto-discover Lumos agents on your network
- **mDNS Discovery**: Zero-config agent detection via multicast DNS
- **Device Management**: Add, edit, and remove devices
- **Status Monitoring**: Real-time device online/offline status
- **Peer Management**: Configure agent-to-agent relay registrations

### Security
- **Password Protection**: All destructive commands require agent password
- **Secure Storage**: Passwords stored using Flutter Secure Storage
- **Token-based Auth**: Support for API tokens (future)
- **HTTPS Support**: Ready for TLS/SSL connections

### User Experience
- **Modern UI**: Beautiful gradient designs with smooth animations
- **Dark Theme**: Eye-friendly dark mode by default
- **Pull-to-Refresh**: Easy status updates
- **Confirmation Dialogs**: Prevent accidental shutdowns
- **OS-Specific Icons**: Visual indicators for Windows/Linux/macOS
- **Status Indicators**: Color-coded online/offline/sleeping states

## Architecture

### Technology Stack
- **Framework**: Flutter 3.0+
- **Language**: Dart
- **State Management**: Provider pattern
- **Storage**: SharedPreferences + Flutter Secure Storage
- **Networking**: HTTP package
- **Network Discovery**: Multicast DNS (mDNS)

### Project Structure

```
lumos_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/
│   │   └── device.dart             # Device data model
│   ├── providers/
│   │   └── device_provider.dart    # State management
│   ├── screens/
│   │   ├── home_screen.dart        # Main device list
│   │   ├── add_device_screen.dart  # Manual device addition
│   │   ├── scan_network_screen.dart # Network scanner
│   │   ├── settings_screen.dart    # App settings
│   │   ├── about_screen.dart       # About/version info
│   │   ├── agent_policy_screen.dart # Per-device policy management
│   │   ├── peer_management_screen.dart # Peer registration management
│   │   └── onboarding_wizard_screen.dart # First-run setup
│   ├── services/
│   │   ├── lumos_api.dart          # API client
│   │   ├── mdns_discovery.dart     # mDNS agent discovery
│   │   └── release_info_service.dart # Version checking
│   └── widgets/
│       └── device_card.dart        # Device UI component
├── android/                         # Android-specific files
├── ios/                            # iOS-specific files (when created)
├── pubspec.yaml                    # Dependencies
└── README.md                       # Documentation
```

### Data Flow

```
User Action
    ↓
Widget (UI)
    ↓
Provider (State Management)
    ↓
LumosApi (Service Layer)
    ↓
HTTP Request
    ↓
Lumos Agent (Go Backend)
    ↓
OS Command (Wake/Shutdown/etc)
```

## API Integration

The app communicates with Lumos agents via REST API:

### Endpoints Used

| Endpoint | Method | Purpose | Auth |
|----------|--------|---------|------|
| `/v1/status` | GET | Get agent status | None |
| `/v1/command/wake` | POST | Send WoL packet | Optional |
| `/v1/command/power` | POST | Shutdown/reboot/sleep | Required |
| `/v1/peer/relay` | POST | Relay to other agents | Required |
| `/v1/ui/scan` | POST | Scan network | Basic Auth |
| `/v1/ui/state` | GET | Get UI state | Basic Auth |
| `/v1/policy/state` | GET | Get policy state with peers | Password |
| `/v1/ui/peer/upsert` | POST | Add/update peer | Basic Auth |
| `/v1/ui/peer/delete` | POST | Delete peer | Basic Auth |

### Authentication Methods

1. **Password Header**: `X-Lumos-Password: <password>`
2. **Basic Auth**: `Authorization: Basic <base64(lumos:password)>`
3. **Token Header**: `X-Lumos-Token: <token>` (future)

## mDNS Discovery Service

The `MdnsDiscovery` service provides zero-configuration agent discovery using multicast DNS.

### Features

- **Auto-discovery**: Finds agents advertising `_lumos-agent._tcp` service
- **Timeout control**: Configurable discovery timeout (default 5 seconds)
- **Availability check**: Detects if mDNS is supported on device
- **Agent ID extraction**: Parses agent ID from mDNS domain name

### Usage

```dart
// Discover agents with default timeout
final agents = await MdnsDiscovery.discoverAgents();

// Custom timeout
final agents = await MdnsDiscovery.discoverAgents(
  timeout: Duration(seconds: 10),
);

// Check if mDNS is available
final available = await MdnsDiscovery.isAvailable();
```

### Response Format

```dart
[
  {
    'agent_id': 'WORKSHOP',
    'address': '192.168.1.100:8080',
    'host': 'WORKSHOP.local',
    'port': 8080,
    'discovered_via': 'mdns',
  }
]
```

### Agent Configuration

For mDNS discovery to work, agents must have:

```json
{
  "mdns_enabled": true,
  "mdns_service": "_lumos-agent._tcp"
}
```

### Limitations

- Requires multicast support on network
- May not work on some corporate/guest networks
- Discovery timeout affects responsiveness
- Only discovers agents on same subnet

## Device Model

```dart
class Device {
  String id;              // UUID
  String name;            // User-friendly name
  String address;         // IP:port (e.g., "192.168.1.100:8080")
  String? mac;            // MAC address (optional)
  String os;              // "windows", "linux", "macos"
  DeviceStatus status;    // online, offline, sleeping, unknown
  String? password;       // Agent password (encrypted in storage)
  DateTime? lastSeen;     // Last successful connection
  List<NetworkInterface> interfaces; // Network interfaces with MACs
}
```

## State Management

Using Provider pattern for reactive state:

```dart
DeviceProvider
├── devices: List<Device>
├── isLoading: bool
├── error: String?
├── loadDevices()        // Load from storage
├── saveDevices()        // Persist to storage
├── addDevice()          // Add new device
├── updateDevice()       // Update existing
├── removeDevice()       // Delete device
├── refreshAll()         // Update all statuses
├── wakeDevice()         // Send WoL
├── shutdownDevice()     // Shutdown
├── rebootDevice()       // Reboot
├── sleepDevice()        // Sleep
└── scanNetwork()        // Discover agents
```

## UI Components

### HomeScreen
- Header with app branding
- Device list with cards
- Pull-to-refresh
- Floating action buttons (Add, Scan)
- Empty state for no devices

### DeviceCard
- Status indicator (colored dot)
- Device name and address
- OS badge
- MAC address chips
- Action buttons (Wake, Shutdown, Reboot, Sleep)
- Policy management button (tune icon)
- Peer management button (hub icon)
- Delete button
- Gradient background based on status

### AddDeviceScreen
- Form for manual device entry
- Name, address, OS, password fields
- Validation

### ScanNetworkScreen
- Network CIDR input (optional)
- Scan button with loading state
- Results list
- Quick-add discovered devices

### PeerManagementScreen
- Authentication with agent password
- View registered peers for an agent
- Add new peers with ID, address, and password verification
- Delete existing peer registrations
- Real-time feedback on operations
- Enables full peer mesh setup from mobile app

## Security Considerations

### Password Storage
- Passwords stored using `flutter_secure_storage`
- Encrypted at rest on device
- Never transmitted in plain text (HTTPS recommended)

### Command Authorization
- Wake: Optional password (configurable in agent)
- Shutdown/Reboot/Sleep: Always requires password
- Confirmation dialogs for destructive actions

### Network Security
- Supports HTTPS connections
- Agent can require TLS
- Token-based auth ready for implementation

## Future Enhancements

### Planned Features
- [ ] Device groups and bulk actions
- [ ] Scheduled wake/shutdown
- [ ] Push notifications
- [ ] Widgets for home screen
- [ ] Shortcuts/Siri integration
- [ ] Battery monitoring for laptops
- [ ] Uptime tracking
- [ ] Action history/logs
- [ ] Dark/light theme toggle
- [ ] Multi-language support

### Advanced Features
- [ ] Agent-to-agent relay support
- [ ] VPN/WAN support
- [ ] Mesh network topology view
- [ ] Health monitoring dashboard
- [ ] Custom automation rules
- [ ] Integration with smart home platforms

## Development Setup

### Prerequisites
1. Flutter SDK 3.0.0+
2. Android Studio (for Android)
3. Xcode (for iOS, macOS only)
4. VS Code or Android Studio IDE

### Getting Started

```bash
# Clone repository
cd lumos_app

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build release APK
flutter build apk --release
```

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Analyze code
flutter analyze
```

## Deployment

### Android
1. Update version in `pubspec.yaml`
2. Build release APK: `flutter build apk --release`
3. Sign APK (production)
4. Upload to Google Play Store

### iOS
1. Update version in `pubspec.yaml`
2. Build iOS: `flutter build ios --release`
3. Open in Xcode
4. Sign with Apple Developer certificate
5. Upload to App Store Connect

## Troubleshooting

### Devices not discovered

**mDNS Discovery:**
- Ensure agent has `mdns_enabled: true` in config
- Check `mdns_service` is set to `_lumos-agent._tcp`
- Verify devices are on the same network/subnet
- Some networks block multicast traffic

**Manual Scanning:**
- Ensure Lumos agent is running on target machines
- Check firewall settings (port 8080 by default)
- Verify network connectivity

**Wake not working**
- Enable WoL in BIOS
- Use Ethernet (not Wi-Fi)
- Check MAC address is correct

**Shutdown fails**
- Verify password is correct
- Check agent has permissions
- Ensure device is online

**Build errors**
- Run `flutter clean`
- Delete `pubspec.lock`
- Run `flutter pub get`
- Restart IDE

## Performance

### Optimizations
- Lazy loading of device list
- Cached network status
- Debounced refresh calls
- Efficient state updates
- Minimal rebuilds with Provider

### Resource Usage
- Small APK size (~15-20 MB)
- Low memory footprint
- Minimal battery drain
- Fast startup time

## Contributing

### Code Style
- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused

### Pull Request Process
1. Fork repository
2. Create feature branch
3. Make changes with tests
4. Update documentation
5. Submit PR with description

## License

[Add license information]

## Support

For issues, questions, or contributions:
- GitHub Issues: [Add link]
- Documentation: See README.md
- API Reference: See ../lumos-agent/API_REFERENCE.md

---

**Built with ❤️ using Flutter**



