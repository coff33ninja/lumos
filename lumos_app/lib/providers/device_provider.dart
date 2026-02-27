import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import '../models/device.dart';
import '../services/lumos_api.dart';
import '../services/mdns_discovery.dart';
import '../services/release_info_service.dart';

class DeviceProvider with ChangeNotifier {
  static const String _minimumAgentVersionForPower = String.fromEnvironment(
    'LUMOS_MIN_AGENT_VERSION',
    defaultValue: 'v1.0.0',
  );

  List<Device> _devices = [];
  bool _isLoading = false;
  String? _error;
  List<int> _scanPorts = [8080];
  int _scanTimeoutSeconds = 2;
  bool _onboardingComplete = false;
  int _scanProgressCurrentPort = 0;
  int _scanProgressTotalPorts = 0;
  int _lastScanHostsTotal = 0;
  int _lastScanHostsReachable = 0;
  int _lastScanDurationMs = 0;
  final Map<String, IOWebSocketChannel> _eventChannels = {};
  final Map<String, StreamSubscription<dynamic>> _eventSubscriptions = {};
  int _liveEventConnections = 0;
  String? _lastEventError;
  ReleaseInfo? _latestRelease;
  bool _isLoadingReleaseInfo = false;
  late final Future<void> _initialLoadFuture;
  String? _appSemVer;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<int> get scanPorts => List<int>.unmodifiable(_scanPorts);
  int get scanTimeoutSeconds => _scanTimeoutSeconds;
  bool get onboardingComplete => _onboardingComplete;
  bool get shouldShowOnboarding => !_onboardingComplete && _devices.isEmpty;
  int get scanProgressCurrentPort => _scanProgressCurrentPort;
  int get scanProgressTotalPorts => _scanProgressTotalPorts;
  int get lastScanHostsTotal => _lastScanHostsTotal;
  int get lastScanHostsReachable => _lastScanHostsReachable;
  int get lastScanDurationMs => _lastScanDurationMs;
  int get liveEventConnections => _liveEventConnections;
  String? get lastEventError => _lastEventError;
  ReleaseInfo? get latestRelease => _latestRelease;
  bool get isLoadingReleaseInfo => _isLoadingReleaseInfo;

  DeviceProvider() {
    _initialLoadFuture = loadDevices();
    unawaited(refreshLatestReleaseInfo());
  }

  Future<void> ensureLoaded() => _initialLoadFuture;

  /// Load devices and settings from storage.
  Future<void> loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = prefs.getString('devices');
      var migratedAuth = false;
      if (devicesJson != null) {
        final decoded = json.decode(devicesJson);
        final loaded = <Device>[];
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              try {
                final parsed = Device.fromJson(item);
                final hasToken =
                    parsed.token != null && parsed.token!.isNotEmpty;
                final hasPassword =
                    parsed.password != null && parsed.password!.isNotEmpty;
                if (hasToken && hasPassword) {
                  loaded.add(parsed.copyWith(password: null));
                  migratedAuth = true;
                } else {
                  loaded.add(parsed);
                }
              } catch (_) {
                // Skip malformed legacy entries rather than failing full load.
              }
            } else if (item is Map) {
              try {
                final parsed = Device.fromJson(Map<String, dynamic>.from(item));
                final hasToken =
                    parsed.token != null && parsed.token!.isNotEmpty;
                final hasPassword =
                    parsed.password != null && parsed.password!.isNotEmpty;
                if (hasToken && hasPassword) {
                  loaded.add(parsed.copyWith(password: null));
                  migratedAuth = true;
                } else {
                  loaded.add(parsed);
                }
              } catch (_) {
                // Skip malformed legacy entries rather than failing full load.
              }
            }
          }
        }
        _devices = loaded;
      }

      final scanPortsCsv = prefs.getString('scan_ports');
      if (scanPortsCsv != null && scanPortsCsv.trim().isNotEmpty) {
        final parsed = scanPortsCsv
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .where((p) => p >= 1 && p <= 65535)
            .toSet()
            .toList()
          ..sort();
        if (parsed.isNotEmpty) {
          _scanPorts = parsed;
        }
      }

      final timeout = prefs.getInt('scan_timeout_seconds');
      if (timeout != null && timeout >= 1 && timeout <= 10) {
        _scanTimeoutSeconds = timeout;
      }

      _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      if (migratedAuth) {
        await saveDevices();
      }

      _syncEventStreams();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load devices: $e';
      notifyListeners();
    }
  }

  Future<void> completeOnboarding({bool complete = true}) async {
    _onboardingComplete = complete;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', _onboardingComplete);
    notifyListeners();
  }

  /// Save devices to storage.
  Future<void> saveDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = json.encode(_devices.map((d) => d.toJson()).toList());
      await prefs.setString('devices', devicesJson);
    } catch (e) {
      _error = 'Failed to save devices: $e';
      notifyListeners();
    }
  }

  Future<void> updateScanSettings({
    required List<int> ports,
    required int timeoutSeconds,
  }) async {
    final normalized = ports.where((p) => p >= 1 && p <= 65535).toSet().toList()
      ..sort();
    if (normalized.isEmpty) {
      throw ArgumentError('At least one valid port is required.');
    }
    if (timeoutSeconds < 1 || timeoutSeconds > 10) {
      throw ArgumentError('Timeout must be between 1 and 10 seconds.');
    }

    _scanPorts = normalized;
    _scanTimeoutSeconds = timeoutSeconds;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scan_ports', _scanPorts.join(','));
    await prefs.setInt('scan_timeout_seconds', _scanTimeoutSeconds);
    notifyListeners();
  }

  /// Add a new device.
  Future<void> addDevice(Device device) async {
    _devices.add(device);
    await saveDevices();
    _syncEventStreams();
    notifyListeners();
  }

  /// Create a device and pair token using one-time password.
  Future<Device> addDeviceWithPairing({
    required String id,
    required String name,
    required String address,
    required String os,
    String? agentId,
    String? pairingPassword,
    String pairingScope = 'power-admin',
  }) async {
    String? token;
    String? tokenId;
    String? tokenScope;
    String? fallbackPassword;

    final trimmedPassword = pairingPassword?.trim() ?? '';
    if (trimmedPassword.isNotEmpty) {
      final pair = await LumosApi.pairToken(
        address,
        trimmedPassword,
        label: 'lumos-app:$name',
        scope: pairingScope,
      );
      if (pair != null) {
        token = pair['token'];
        tokenId = pair['token_id'];
        tokenScope = pair['scope'];
      } else {
        // Fallback for older agents that do not support /v1/auth/pair.
        fallbackPassword = trimmedPassword;
      }
    }

    var status = DeviceStatus.unknown;
    var discoveredOs = os;
    String? discoveredVersion;
    String? discoveredAppRange;
    List<NetworkInterface> interfaces = const [];
    String? primaryMac;
    final liveStatus = await LumosApi.getStatus(address);
    if (liveStatus != null) {
      status = DeviceStatus.online;
      discoveredOs = liveStatus['os']?.toString() ?? os;
      discoveredVersion = liveStatus['version']?.toString();
      discoveredAppRange = _extractAgentAppRange(liveStatus);
      agentId = liveStatus['agent_id']?.toString() ?? agentId;
      interfaces = (liveStatus['interfaces'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(NetworkInterface.fromJson)
              .toList() ??
          const [];
      if (interfaces.isNotEmpty) {
        primaryMac = interfaces.first.mac;
      }
    }

    final device = Device(
      id: id,
      agentId: agentId,
      name: name,
      address: address,
      os: discoveredOs,
      password: fallbackPassword,
      token: token,
      tokenId: tokenId,
      tokenScope: tokenScope,
      status: status,
      interfaces: interfaces,
      mac: primaryMac,
      lastSeen: status == DeviceStatus.online ? DateTime.now() : null,
      agentVersion: discoveredVersion,
      agentAppRange: discoveredAppRange,
    );
    await addDevice(device);
    return device;
  }

  /// Update device.
  Future<void> updateDevice(String id, Device device) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index != -1) {
      _devices[index] = device;
      await saveDevices();
      _syncEventStreams();
      notifyListeners();
    }
  }

  Future<void> updateDeviceAllowances(
    String id, {
    required bool allowWake,
    required bool allowShutdown,
    required bool allowReboot,
    required bool allowSleep,
  }) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _devices[index] = _devices[index].copyWith(
      allowWake: allowWake,
      allowShutdown: allowShutdown,
      allowReboot: allowReboot,
      allowSleep: allowSleep,
    );
    await saveDevices();
    notifyListeners();
  }

  /// Remove device.
  Future<void> removeDevice(String id) async {
    _devices.removeWhere((d) => d.id == id);
    _disconnectEventStream(id);
    await saveDevices();
    notifyListeners();
  }

  /// Revoke device token when possible, then remove it from local state.
  Future<bool> deleteDevice(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final device = _devices[index];

    if (device.token != null && device.token!.isNotEmpty) {
      await LumosApi.revokeSelfToken(
        device.address,
        token: device.token!,
      );
    }

    await removeDevice(id);
    return true;
  }

  /// Refresh all device statuses.
  Future<void> refreshAll() async {
    await ensureLoaded();
    _isLoading = true;
    _error = null;
    notifyListeners();

    for (int i = 0; i < _devices.length; i++) {
      final device = _devices[i];
      final status = await LumosApi.getStatus(device.address);

      if (status != null) {
        final interfaces = (status['interfaces'] as List?)
                ?.map((i) => NetworkInterface.fromJson(i))
                .toList() ??
            const <NetworkInterface>[];
        final primaryMac = interfaces.isNotEmpty ? interfaces.first.mac : null;
        _devices[i] = device.copyWith(
          agentId: status['agent_id']?.toString() ?? device.agentId,
          agentVersion: status['version']?.toString() ?? device.agentVersion,
          agentAppRange: _extractAgentAppRange(status) ?? device.agentAppRange,
          status: DeviceStatus.online,
          lastSeen: DateTime.now(),
          interfaces: interfaces,
          mac: primaryMac,
        );
      } else {
        _devices[i] = device.copyWith(
          status: DeviceStatus.offline,
        );
      }
    }

    _isLoading = false;
    await saveDevices();
    _syncEventStreams();
    notifyListeners();
  }

  /// Wake device.
  Future<bool> wakeDevice(String id, String mac) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final device = _devices[index];
    if (!device.allowWake) {
      _recordCommandResult(
        index,
        action: 'wake',
        success: false,
        message:
            'policy_denied: wake disabled for this device in app allowances',
      );
      return false;
    }

    // Wake should work without credentials by default via app-side magic packet.
    var success = await LumosApi.sendDirectWake(mac);
    var message =
        success ? 'Wake packet sent (direct app broadcast)' : 'Wake failed';

    // If direct wake fails, try authenticated hive/agent-assisted wake paths.
    if (!success) {
      final hasDeviceAuth =
          (device.token != null && device.token!.isNotEmpty) ||
              (device.password != null && device.password!.isNotEmpty);
      if (hasDeviceAuth) {
        final result = await LumosApi.wakeDetailed(
          device.address,
          mac,
          password: device.password,
          token: device.token,
        );
        success = result.ok;
        if (success) {
          message = 'Wake packet sent (target agent)';
        } else {
          message = result.readableMessage('Wake failed');
        }
      }
    }

    if (!success && device.agentId != null && device.agentId!.isNotEmpty) {
      for (final relay in _devices) {
        if (relay.id == device.id || relay.status != DeviceStatus.online) {
          continue;
        }
        final hasRelayAuth = (relay.token != null && relay.token!.isNotEmpty) ||
            (relay.password != null && relay.password!.isNotEmpty);
        if (!hasRelayAuth) {
          continue;
        }
        final result = await LumosApi.relayDetailed(
          relay.address,
          relay.password,
          device.agentId!,
          'wake',
          mac: mac,
          token: relay.token,
        );
        success = result.ok;
        if (success) {
          message = 'Wake packet sent (registered relay: ${relay.name})';
          break;
        } else if (result.reason == 'policy_denied') {
          message = result.readableMessage('Wake denied by relay policy');
        }
      }
    }

    if (!success) {
      for (final relay in _devices) {
        if (relay.id == device.id || relay.status != DeviceStatus.online) {
          continue;
        }
        final hasRelayAuth = (relay.token != null && relay.token!.isNotEmpty) ||
            (relay.password != null && relay.password!.isNotEmpty);
        if (!hasRelayAuth) {
          continue;
        }
        final result = await LumosApi.wakeDetailed(
          relay.address,
          mac,
          password: relay.password,
          token: relay.token,
        );
        success = result.ok;
        if (success) {
          message = 'Wake packet sent (relay agent broadcast: ${relay.name})';
          break;
        } else if (result.reason == 'policy_denied') {
          message = result.readableMessage('Wake denied by relay policy');
        }
      }
    }

    _recordCommandResult(
      index,
      action: 'wake',
      success: success,
      message: message,
    );
    return success;
  }

  /// Shutdown device.
  Future<bool> shutdownDevice(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final device = _devices[index];
    if (!device.allowShutdown) {
      _recordCommandResult(
        index,
        action: 'shutdown',
        success: false,
        message:
            'policy_denied: shutdown disabled for this device in app allowances',
      );
      return false;
    }
    if ((device.token == null || device.token!.isEmpty) &&
        (device.password == null || device.password!.isEmpty)) {
      _recordCommandResult(
        index,
        action: 'shutdown',
        success: false,
        message: 'Missing auth credentials',
      );
      return false;
    }
    if (!await _enforcePowerCompatibility(
      index,
      device,
      action: 'shutdown',
    )) {
      return false;
    }

    final isDryRun = await _isDryRunEnabled(device.address);
    final result = await LumosApi.shutdownDetailed(
      device.address,
      password: device.password,
      token: device.token,
    );
    final success = result.ok;
    if (success && !isDryRun) {
      _devices[index] = device.copyWith(status: DeviceStatus.offline);
    }
    _recordCommandResult(
      index,
      action: 'shutdown',
      success: success,
      message: success
          ? (isDryRun
              ? 'Dry run enabled: shutdown was simulated'
              : 'Shutdown command sent')
          : result.readableMessage('Shutdown failed'),
    );
    return success;
  }

  /// Reboot device.
  Future<bool> rebootDevice(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final device = _devices[index];
    if (!device.allowReboot) {
      _recordCommandResult(
        index,
        action: 'reboot',
        success: false,
        message:
            'policy_denied: reboot disabled for this device in app allowances',
      );
      return false;
    }
    if ((device.token == null || device.token!.isEmpty) &&
        (device.password == null || device.password!.isEmpty)) {
      _recordCommandResult(
        index,
        action: 'reboot',
        success: false,
        message: 'Missing auth credentials',
      );
      return false;
    }
    if (!await _enforcePowerCompatibility(
      index,
      device,
      action: 'reboot',
    )) {
      return false;
    }

    final isDryRun = await _isDryRunEnabled(device.address);
    final result = await LumosApi.rebootDetailed(
      device.address,
      password: device.password,
      token: device.token,
    );
    final success = result.ok;
    _recordCommandResult(
      index,
      action: 'reboot',
      success: success,
      message: success
          ? (isDryRun
              ? 'Dry run enabled: reboot was simulated'
              : 'Reboot command sent')
          : result.readableMessage('Reboot failed'),
    );
    return success;
  }

  /// Sleep device.
  Future<bool> sleepDevice(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index == -1) return false;
    final device = _devices[index];
    if (!device.allowSleep) {
      _recordCommandResult(
        index,
        action: 'sleep',
        success: false,
        message:
            'policy_denied: sleep disabled for this device in app allowances',
      );
      return false;
    }
    if ((device.token == null || device.token!.isEmpty) &&
        (device.password == null || device.password!.isEmpty)) {
      _recordCommandResult(
        index,
        action: 'sleep',
        success: false,
        message: 'Missing auth credentials',
      );
      return false;
    }
    if (!await _enforcePowerCompatibility(
      index,
      device,
      action: 'sleep',
    )) {
      return false;
    }

    final isDryRun = await _isDryRunEnabled(device.address);
    final result = await LumosApi.sleepDetailed(
      device.address,
      password: device.password,
      token: device.token,
    );
    final success = result.ok;
    if (success && !isDryRun) {
      _devices[index] = device.copyWith(status: DeviceStatus.sleeping);
    }
    _recordCommandResult(
      index,
      action: 'sleep',
      success: success,
      message: success
          ? (isDryRun
              ? 'Dry run enabled: sleep was simulated'
              : 'Sleep command sent')
          : result.readableMessage('Sleep failed'),
    );
    return success;
  }

  /// Scan network for devices.
  Future<List<Map<String, dynamic>>> scanNetwork(String? network) async {
    final probePorts = {..._scanPorts, 8080}.toList()..sort();

    _scanProgressCurrentPort = 0;
    _scanProgressTotalPorts = probePorts.length;
    _lastScanHostsTotal = 0;
    _lastScanHostsReachable = 0;
    _lastScanDurationMs = 0;
    notifyListeners();

    // Try mDNS discovery first (fast and efficient)
    final mdnsResults = <String, Map<String, dynamic>>{};
    try {
      final discovered = await MdnsDiscovery.discoverAgents(
        timeout: const Duration(seconds: 3),
      );
      for (final result in discovered) {
        final address = result['address']?.toString();
        if (address != null && address.isNotEmpty) {
          mdnsResults[address] = result;
        }
      }

      // If mDNS found agents, enrich and return them
      if (mdnsResults.isNotEmpty) {
        _lastScanHostsReachable = mdnsResults.length;
        _scanProgressCurrentPort = _scanProgressTotalPorts;
        notifyListeners();
        return _enrichScanResultsWithStatus(
          mdnsResults.values.toList(growable: false),
        );
      }
    } catch (e) {
      // mDNS failed, fall back to HTTP scanning
    }

    // Prefer server-side scan when we have a configured scanner.
    Device? scanner;
    for (final device in _devices) {
      if (device.status == DeviceStatus.online &&
          ((device.token != null && device.token!.isNotEmpty) ||
              (device.password != null && device.password!.isNotEmpty))) {
        scanner = device;
        break;
      }
    }

    final scannerToken = scanner?.token?.trim();
    final scannerPassword = scanner?.password?.trim();
    final hasScannerAuth = (scannerToken != null && scannerToken.isNotEmpty) ||
        (scannerPassword != null && scannerPassword.isNotEmpty);

    if (scanner != null && hasScannerAuth) {
      final mergedByAddress = <String, Map<String, dynamic>>{};
      var totalHosts = 0;
      var totalDurationMs = 0;
      for (var i = 0; i < probePorts.length; i++) {
        final port = probePorts[i];
        _scanProgressCurrentPort = i + 1;
        notifyListeners();
        final response = await LumosApi.scanNetworkWithStats(
          scanner.address,
          password: scannerPassword,
          token: scannerToken,
          network: network,
          port: port,
          timeoutSeconds: _scanTimeoutSeconds,
        );
        final results = List<Map<String, dynamic>>.from(
          response['results'] ?? const [],
        );
        totalHosts += (response['hosts_total'] as num?)?.toInt() ?? 0;
        totalDurationMs += (response['duration_ms'] as num?)?.toInt() ?? 0;
        for (final result in results) {
          final address = result['address'] as String?;
          if (address != null) {
            mergedByAddress[address] = result;
          }
        }
      }
      _lastScanHostsTotal = totalHosts;
      _lastScanHostsReachable = mergedByAddress.length;
      _lastScanDurationMs = totalDurationMs;
      notifyListeners();
      if (mergedByAddress.isNotEmpty) {
        return await _enrichScanResultsWithStatus(
          mergedByAddress.values.toList(growable: false),
        );
      }

      // If agent-side scan yields nothing (for example stale password on scanner),
      // try direct probing from the app as a resilient fallback.
      final fallback = await LumosApi.discoverAgents(
        network: network,
        ports: probePorts,
        timeoutSeconds: _scanTimeoutSeconds,
      );
      _lastScanHostsReachable = fallback.length;
      notifyListeners();
      return _enrichScanResultsWithStatus(fallback);
    }

    // Fallback to direct app-side discovery without password.
    final fallback = await LumosApi.discoverAgents(
      network: network,
      ports: probePorts,
      timeoutSeconds: _scanTimeoutSeconds,
    );
    _scanProgressCurrentPort = _scanProgressTotalPorts;
    _lastScanHostsReachable = fallback.length;
    notifyListeners();
    return _enrichScanResultsWithStatus(fallback);
  }

  Future<List<Map<String, dynamic>>> _enrichScanResultsWithStatus(
    List<Map<String, dynamic>> results,
  ) async {
    if (results.isEmpty) return results;
    final enriched = await Future.wait(results.map((result) async {
      final address = result['address']?.toString();
      if (address == null || address.isEmpty) {
        return result;
      }
      final status = await LumosApi.getStatus(address);
      if (status == null) {
        return result;
      }
      final interfaces = (status['interfaces'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];
      final primaryMac =
          interfaces.isNotEmpty ? interfaces.first['mac']?.toString() : null;
      return {
        ...result,
        if (status['os'] != null) 'os': status['os'],
        if (interfaces.isNotEmpty) 'interfaces': interfaces,
        if (primaryMac != null && primaryMac.isNotEmpty) 'mac': primaryMac,
      };
    }));
    return List<Map<String, dynamic>>.from(enriched, growable: false);
  }

  void _recordCommandResult(
    int index, {
    required String action,
    required bool success,
    required String message,
  }) {
    final current = _devices[index];
    _devices[index] = current.copyWith(
      lastCommandAt: DateTime.now(),
      lastCommandAction: action,
      lastCommandSuccess: success,
      lastCommandMessage: message,
    );
    saveDevices();
    notifyListeners();
  }

  bool _enforceMinimumAgentVersion(
    int index,
    Device device, {
    required String action,
  }) {
    final minimumKey =
        ReleaseInfoService.versionSortKey(_minimumAgentVersionForPower);
    final deviceVersion = device.agentVersion?.trim() ?? '';
    final actualKey = ReleaseInfoService.versionSortKey(deviceVersion);
    final isSupported =
        minimumKey != null && actualKey != null && actualKey >= minimumKey;
    if (isSupported) return true;

    _recordCommandResult(
      index,
      action: action,
      success: false,
      message:
          'agent_version_unsupported: requires >= $_minimumAgentVersionForPower (found ${deviceVersion.isEmpty ? 'unknown' : deviceVersion})',
    );
    return false;
  }

  Future<bool> _enforcePowerCompatibility(
    int index,
    Device device, {
    required String action,
  }) async {
    if (!_enforceMinimumAgentVersion(index, device, action: action)) {
      return false;
    }

    final appRange = device.agentAppRange?.trim() ?? '';
    if (appRange.isEmpty || appRange == '*') {
      return true;
    }

    final appVersion = await _getCurrentAppSemVer();
    final isSupported = appVersion.isNotEmpty &&
        ReleaseInfoService.isVersionInComparatorRange(
          version: appVersion,
          range: appRange,
        );
    if (isSupported) return true;

    _recordCommandResult(
      index,
      action: action,
      success: false,
      message:
          'app_version_unsupported: agent requires app $appRange (found ${appVersion.isEmpty ? 'unknown' : appVersion})',
    );
    return false;
  }

  String? _extractAgentAppRange(Map<String, dynamic>? status) {
    if (status == null) return null;

    final compatibility = status['compatibility'];
    if (compatibility is Map) {
      final raw = compatibility['app_range']?.toString().trim() ?? '';
      if (raw.isNotEmpty) {
        return raw;
      }
    }

    final legacy = status['app_range']?.toString().trim() ?? '';
    if (legacy.isNotEmpty) {
      return legacy;
    }
    return null;
  }

  Future<String> _getCurrentAppSemVer() async {
    if (_appSemVer != null && _appSemVer!.isNotEmpty) {
      return _appSemVer!;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final raw = info.version.trim();
      if (raw.isEmpty) return '';
      _appSemVer = raw.split('+').first.trim();
      return _appSemVer!;
    } catch (_) {
      return '';
    }
  }

  void _syncEventStreams() {
    final activeIds = <String>{};
    for (final device in _devices) {
      final hasAuth = (device.token != null && device.token!.isNotEmpty) ||
          (device.password != null && device.password!.isNotEmpty);
      if (device.status == DeviceStatus.online && hasAuth) {
        activeIds.add(device.id);
        if (!_eventChannels.containsKey(device.id)) {
          _connectEventStream(device);
        }
      }
    }

    final stale =
        _eventChannels.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in stale) {
      _disconnectEventStream(id);
    }
    _liveEventConnections = _eventChannels.length;
  }

  void _connectEventStream(Device device) {
    IOWebSocketChannel? channel;
    try {
      channel = LumosApi.connectEvents(
        device.address,
        password: device.password,
        token: device.token,
        secure: false,
      );
      _eventChannels[device.id] = channel;
      _liveEventConnections = _eventChannels.length;
      final sub = channel.stream.listen(
        (raw) => _handleEventPayload(device.id, raw),
        onError: (e) {
          _lastEventError = 'Event stream error (${device.name}): $e';
          _disconnectEventStream(device.id);
          notifyListeners();
        },
        onDone: () {
          _disconnectEventStream(device.id);
          notifyListeners();
        },
        cancelOnError: true,
      );
      _eventSubscriptions[device.id] = sub;
    } catch (e) {
      _lastEventError = 'Event stream connect failed (${device.name}): $e';
      if (channel != null) {
        try {
          channel.sink.close();
        } catch (_) {}
      }
      _disconnectEventStream(device.id);
      notifyListeners();
    }
  }

  void _disconnectEventStream(String deviceId) {
    final sub = _eventSubscriptions.remove(deviceId);
    sub?.cancel();
    final channel = _eventChannels.remove(deviceId);
    if (channel != null) {
      try {
        channel.sink.close();
      } catch (_) {}
    }
    _liveEventConnections = _eventChannels.length;
  }

  void _handleEventPayload(String deviceId, dynamic raw) {
    Map<String, dynamic>? event;
    try {
      if (raw is String) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          event = decoded;
        }
      } else if (raw is Map<String, dynamic>) {
        event = raw;
      }
    } catch (_) {
      return;
    }
    if (event == null) return;

    final eventType = event['type']?.toString();
    if (eventType != 'audit') return;

    final data = event['data'];
    if (data is! Map<String, dynamic>) return;

    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx == -1) return;

    final action = data['action']?.toString() ?? 'unknown';
    final success = data['success'] == true;
    final message = data['message']?.toString() ?? '';
    final isDryRunEvent = message.toLowerCase().contains('dry-run');
    final timestampRaw = data['timestamp']?.toString();
    DateTime at;
    if (timestampRaw != null && timestampRaw.isNotEmpty) {
      at = DateTime.tryParse(timestampRaw)?.toLocal() ?? DateTime.now();
    } else {
      at = DateTime.now();
    }

    var status = _devices[idx].status;
    if (success && action == 'shutdown' && !isDryRunEvent) {
      status = DeviceStatus.offline;
    } else if (success && action == 'sleep' && !isDryRunEvent) {
      status = DeviceStatus.sleeping;
    }

    _devices[idx] = _devices[idx].copyWith(
      status: status,
      lastCommandAt: at,
      lastCommandAction: action,
      lastCommandSuccess: success,
      lastCommandMessage: message,
    );
    saveDevices();
    notifyListeners();
  }

  Future<bool> _isDryRunEnabled(String address) async {
    final status = await LumosApi.getStatus(address);
    return status?['dry_run'] == true;
  }

  Future<void> refreshLatestReleaseInfo({bool force = false}) async {
    _isLoadingReleaseInfo = true;
    notifyListeners();
    final latest = await ReleaseInfoService.getLatestRelease(
      forceRefresh: force,
    );
    _latestRelease = latest;
    _isLoadingReleaseInfo = false;
    notifyListeners();
  }

  @override
  void dispose() {
    final ids = _eventChannels.keys.toList(growable: false);
    for (final id in ids) {
      _disconnectEventStream(id);
    }
    super.dispose();
  }
}
