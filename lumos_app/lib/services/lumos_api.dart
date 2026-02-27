import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class ApiCommandResult {
  final bool ok;
  final int statusCode;
  final String? message;
  final String? reason;

  const ApiCommandResult({
    required this.ok,
    this.statusCode = 0,
    this.message,
    this.reason,
  });

  String readableMessage(String fallback) {
    if ((reason ?? '') == 'policy_denied') {
      final friendly = _humanizePolicyDenied(message);
      if (friendly != null) return friendly;
    }
    final raw = message?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    if (reason != null && reason!.isNotEmpty) return reason!;
    return fallback;
  }

  static String? _humanizePolicyDenied(String? rawMessage) {
    final raw = rawMessage?.trim();
    if (raw == null || raw.isEmpty) return null;
    final scopeMatch =
        RegExp(r'scope=([a-z-]+)', caseSensitive: false).firstMatch(raw);
    final actionMatch =
        RegExp(r'action=([a-z-]+)', caseSensitive: false).firstMatch(raw);
    if (scopeMatch != null) {
      final scope = scopeMatch.group(1) ?? 'unknown';
      final action = actionMatch?.group(1);
      if (action != null && action.isNotEmpty) {
        return 'Denied by token scope "$scope" for action "$action"';
      }
      return 'Denied by token scope "$scope"';
    }
    return raw;
  }
}

class ApiActionAllowances {
  final bool wake;
  final bool shutdown;
  final bool reboot;
  final bool sleep;
  final bool relay;

  const ApiActionAllowances({
    required this.wake,
    required this.shutdown,
    required this.reboot,
    required this.sleep,
    required this.relay,
  });

  const ApiActionAllowances.allowAll()
      : wake = true,
        shutdown = true,
        reboot = true,
        sleep = true,
        relay = true;

  Map<String, dynamic> toJson() => {
        'wake': wake,
        'shutdown': shutdown,
        'reboot': reboot,
        'sleep': sleep,
        'relay': relay,
      };

  factory ApiActionAllowances.fromJson(Map<String, dynamic> json) {
    bool readBool(String key) => json[key] == true;
    return ApiActionAllowances(
      wake: readBool('wake'),
      shutdown: readBool('shutdown'),
      reboot: readBool('reboot'),
      sleep: readBool('sleep'),
      relay: readBool('relay'),
    );
  }
}

class AgentPolicyState {
  final ApiActionAllowances defaultTokenAllowances;
  final Map<String, ApiActionAllowances> tokenAllowances;
  final Map<String, ApiActionAllowances> relayInboundAllowances;
  final Map<String, ApiActionAllowances> relayOutboundAllowances;
  final List<Map<String, dynamic>> tokens;
  final List<String> peers;

  const AgentPolicyState({
    required this.defaultTokenAllowances,
    required this.tokenAllowances,
    required this.relayInboundAllowances,
    required this.relayOutboundAllowances,
    required this.tokens,
    required this.peers,
  });
}

class AgentTokenRecord {
  final String id;
  final String label;
  final String scope;
  final String? lastUsedAt;
  final String? revokedAt;
  final String? createdAt;

  const AgentTokenRecord({
    required this.id,
    required this.label,
    required this.scope,
    this.lastUsedAt,
    this.revokedAt,
    this.createdAt,
  });

  factory AgentTokenRecord.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['token_id'] ?? '').toString().trim();
    return AgentTokenRecord(
      id: id,
      label: (json['label'] ?? '').toString(),
      scope: (json['scope'] ?? 'power-admin').toString(),
      lastUsedAt: json['last_used_at']?.toString(),
      revokedAt: json['revoked_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class LumosApi {
  static const int defaultPort = 8080;
  static const Duration timeout = Duration(seconds: 5);

  static Uri _httpUri(String address, String path) {
    final normalized = address.trim();
    final hasScheme = normalized.contains('://');
    final base = Uri.parse(hasScheme ? normalized : 'http://$normalized');
    return base.replace(path: path, query: null, fragment: null);
  }

  /// Get agent status
  static Future<Map<String, dynamic>?> getStatus(String address) async {
    try {
      final uri = _httpUri(address, '/v1/status');
      final response = await http.get(uri).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // Device unreachable
    }
    return null;
  }

  /// Send Wake-on-LAN magic packet
  static Future<bool> wake(
    String address,
    String mac, {
    String? password,
    String? token,
  }) async {
    final result = await wakeDetailed(
      address,
      mac,
      password: password,
      token: token,
    );
    return result.ok;
  }

  static Future<ApiCommandResult> wakeDetailed(
    String address,
    String mac, {
    String? password,
    String? token,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/command/wake');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['X-Lumos-Token'] = token;
      } else if (password != null && password.isNotEmpty) {
        headers['X-Lumos-Password'] = password;
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode({'mac': mac}),
          )
          .timeout(timeout);

      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }

  /// Shutdown device
  static Future<bool> shutdown(
    String address, {
    String? password,
    String? token,
  }) async {
    final result = await shutdownDetailed(
      address,
      password: password,
      token: token,
    );
    return result.ok;
  }

  static Future<ApiCommandResult> shutdownDetailed(
    String address, {
    String? password,
    String? token,
  }) async {
    return _sendPowerAction(
      address,
      action: 'shutdown',
      password: password,
      token: token,
    );
  }

  /// Reboot device
  static Future<bool> reboot(
    String address, {
    String? password,
    String? token,
  }) async {
    final result = await rebootDetailed(
      address,
      password: password,
      token: token,
    );
    return result.ok;
  }

  static Future<ApiCommandResult> rebootDetailed(
    String address, {
    String? password,
    String? token,
  }) async {
    return _sendPowerAction(
      address,
      action: 'reboot',
      password: password,
      token: token,
    );
  }

  /// Sleep device
  static Future<bool> sleep(
    String address, {
    String? password,
    String? token,
  }) async {
    final result = await sleepDetailed(
      address,
      password: password,
      token: token,
    );
    return result.ok;
  }

  static Future<ApiCommandResult> sleepDetailed(
    String address, {
    String? password,
    String? token,
  }) async {
    return _sendPowerAction(
      address,
      action: 'sleep',
      password: password,
      token: token,
    );
  }

  static Future<ApiCommandResult> _sendPowerAction(
    String address, {
    required String action,
    String? password,
    String? token,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/command/power');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['X-Lumos-Token'] = token;
      } else if (password != null && password.isNotEmpty) {
        headers['X-Lumos-Password'] = password;
      }
      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode({'action': action}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) return _parseApiResult(response);

      // Safe mode may require a second confirmed request.
      if (response.statusCode == 409) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final confirmToken = decoded['confirm_token']?.toString() ?? '';
          if (confirmToken.isNotEmpty) {
            final confirmedHeaders = <String, String>{
              ...headers,
              'X-Lumos-Confirm-Token': confirmToken,
            };
            final confirmed = await http
                .post(
                  uri,
                  headers: confirmedHeaders,
                  body: json.encode({'action': action}),
                )
                .timeout(timeout);
            return _parseApiResult(confirmed);
          }
        }
      }
      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }

  /// Relay command to another agent
  static Future<bool> relay(
      String address, String? password, String targetAgentId, String action,
      {String? mac, String? token}) async {
    final result = await relayDetailed(
      address,
      password,
      targetAgentId,
      action,
      mac: mac,
      token: token,
    );
    return result.ok;
  }

  static Future<ApiCommandResult> relayDetailed(
      String address, String? password, String targetAgentId, String action,
      {String? mac, String? token}) async {
    try {
      final uri = _httpUri(address, '/v1/peer/relay');
      final body = <String, dynamic>{
        'target_agent_id': targetAgentId,
        'action': action,
      };

      if (mac != null) {
        body['mac'] = mac;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['X-Lumos-Token'] = token;
      } else if (password != null && password.isNotEmpty) {
        headers['X-Lumos-Password'] = password;
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode(body),
          )
          .timeout(timeout);

      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }

  /// Scan network for Lumos agents
  static Future<List<Map<String, dynamic>>> scanNetwork(
    String address, {
    String? password,
    String? token,
    String? network,
    int port = defaultPort,
    int timeoutSeconds = 2,
  }) async {
    final data = await scanNetworkWithStats(
      address,
      password: password,
      token: token,
      network: network,
      port: port,
      timeoutSeconds: timeoutSeconds,
    );
    return List<Map<String, dynamic>>.from(data['results'] ?? const []);
  }

  /// Scan network and include host-count metadata from agent response.
  static Future<Map<String, dynamic>> scanNetworkWithStats(
    String address, {
    String? password,
    String? token,
    String? network,
    int port = defaultPort,
    int timeoutSeconds = 2,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/scan');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['X-Lumos-Token'] = token;
      } else if (password != null && password.isNotEmpty) {
        headers['X-Lumos-Password'] = password;
      }
      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode({
              if (network != null) 'network': network,
              'port': port,
              'timeout': timeoutSeconds,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'results':
              List<Map<String, dynamic>>.from(data['results'] ?? const []),
          'hosts_total': data['hosts_total'] ?? 0,
          'hosts_reachable': data['hosts_reachable'] ?? 0,
          'duration_ms': data['duration_ms'] ?? 0,
          'scanned': data['scanned'] ?? network ?? 'auto-detected',
        };
      }
    } catch (e) {
      // Scan failed
    }
    return const {
      'results': <Map<String, dynamic>>[],
      'hosts_total': 0,
      'hosts_reachable': 0,
      'duration_ms': 0,
      'scanned': '',
    };
  }

  /// Pair and mint a long-lived token from password auth.
  static Future<Map<String, String>?> pairToken(
    String address,
    String password, {
    String label = 'lumos-app',
    String scope = 'power-admin',
  }) async {
    try {
      final uri = _httpUri(address, '/v1/auth/pair');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Lumos-Password': password,
            },
            body: json.encode({
              'label': label,
              'scope': scope,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token']?.toString();
        final tokenId = data['token_id']?.toString();
        final responseScope = data['scope']?.toString();
        if (token != null && token.isNotEmpty) {
          return {
            'token': token,
            if (tokenId != null && tokenId.isNotEmpty) 'token_id': tokenId,
            'scope': (responseScope != null && responseScope.isNotEmpty)
                ? responseScope
                : scope,
          };
        }
      }
    } catch (_) {
      // Pair failed
    }
    return null;
  }

  /// Send WOL directly from app (works even when target agent is offline).
  static Future<bool> sendDirectWake(String mac) async {
    try {
      final parsedMac = _parseMac(mac);
      if (parsedMac == null) return false;
      final packet = _buildMagicPacket(parsedMac);

      final broadcasts = <String>{'255.255.255.255'};
      final subnets = await detectLocalSubnets();
      for (final subnet in subnets) {
        final parts = subnet.split('/');
        if (parts.isEmpty) continue;
        final octets = parts.first.split('.');
        if (octets.length != 4) continue;
        broadcasts.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
      }

      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;
      var sent = false;
      try {
        for (final host in broadcasts) {
          for (final port in const [9, 7]) {
            final count = socket.send(packet, InternetAddress(host), port);
            if (count > 0) sent = true;
          }
        }
      } finally {
        socket.close();
      }
      return sent;
    } catch (_) {
      return false;
    }
  }

  /// Revoke currently used token without requiring password.
  static Future<bool> revokeSelfToken(
    String address, {
    required String token,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/auth/token/self/revoke');
      final response = await http.post(
        uri,
        headers: {
          'X-Lumos-Token': token,
        },
      ).timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<AgentTokenRecord>> listTokens(
    String address, {
    required String password,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/auth/token/list');
      final response = await http.get(
        uri,
        headers: {
          'X-Lumos-Password': password,
        },
      ).timeout(timeout);
      if (response.statusCode != 200) return const [];
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final tokens = decoded['tokens'];
      if (tokens is! List) return const [];
      return tokens
          .whereType<Map>()
          .map((e) => AgentTokenRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, String>?> rotateToken(
    String address, {
    required String password,
    required String tokenId,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/auth/token/rotate');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Lumos-Password': password,
            },
            body: json.encode({'token_id': tokenId}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token']?.toString();
        final newTokenId = data['token_id']?.toString();
        if (token != null && token.isNotEmpty) {
          return {
            'token': token,
            if (newTokenId != null && newTokenId.isNotEmpty)
              'token_id': newTokenId,
          };
        }
      }
    } catch (_) {
      // rotate failed
    }
    return null;
  }

  static Future<ApiCommandResult> revokeTokenById(
    String address, {
    required String password,
    required String tokenId,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/auth/token/revoke');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Lumos-Password': password,
            },
            body: json.encode({'token_id': tokenId}),
          )
          .timeout(timeout);
      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }

  static bool supportsScopedPairing(Map<String, dynamic>? status) {
    if (status == null) return false;
    final caps = status['capabilities'];
    if (caps is Map) {
      final raw = caps['auth_token_scope'];
      if (raw is bool) return raw;
      if (raw != null && raw.toString().toLowerCase() == 'true') return true;
    }
    return false;
  }

  static bool supportsTokenAdmin(Map<String, dynamic>? status) {
    if (status == null) return false;
    final caps = status['capabilities'];
    if (caps is Map) {
      final list = caps['auth_token_list'];
      final rotate = caps['auth_token_rotate'];
      final listOk = list == true || list?.toString().toLowerCase() == 'true';
      final rotateOk =
          rotate == true || rotate?.toString().toLowerCase() == 'true';
      return listOk && rotateOk;
    }
    return false;
  }

  /// Discover Lumos agents directly from the app without auth.
  /// If [network] is provided, it must be IPv4 CIDR, e.g. 192.168.1.0/24.
  static Future<List<String>> detectLocalSubnets() async {
    final out = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        if (!_shouldScanInterface(iface.name)) {
          continue;
        }
        for (final addr in iface.addresses) {
          final ip = addr.address.trim();
          final octets = ip.split('.');
          if (octets.length != 4) continue;
          final a = int.tryParse(octets[0]);
          final b = int.tryParse(octets[1]);
          final c = int.tryParse(octets[2]);
          if (a == null || b == null || c == null) continue;
          out.add('$a.$b.$c.0/24');
        }
      }
    } catch (_) {
      // Best effort; fallback list is used by discoverAgents.
    }
    final sorted = out.toList()..sort();
    return sorted;
  }

  static bool _shouldScanInterface(String rawName) {
    final name = rawName.trim().toLowerCase();
    if (name.isEmpty) return false;

    // Explicitly exclude common mobile/cellular interfaces.
    const mobileMarkers = [
      'rmnet',
      'ccmni',
      'pdp',
      'cell',
      'mobile',
      'wwan',
      'lte',
      '5g',
      '4g',
      'ril',
    ];
    for (final marker in mobileMarkers) {
      if (name.contains(marker)) return false;
    }

    // Include common Wi-Fi, LAN, and VPN interfaces.
    const allowedMarkers = [
      'wlan',
      'wifi',
      'wl',
      'eth',
      'en',
      'lan',
      'tun',
      'tap',
      'utun',
      'ppp',
      'vpn',
      'wg',
      'tailscale',
      'zt',
    ];
    for (final marker in allowedMarkers) {
      if (name.contains(marker)) return true;
    }

    // Keep unknown names to avoid false negatives on OEM/custom interface names.
    return true;
  }

  /// Discover Lumos agents directly from the app without auth.
  /// If [network] is provided, it must be IPv4 CIDR, e.g. 192.168.1.0/24.
  static Future<List<Map<String, dynamic>>> discoverAgents({
    String? network,
    List<int> ports = const [defaultPort],
    int timeoutSeconds = 1,
  }) async {
    final normalizedPorts =
        ports.where((p) => p >= 1 && p <= 65535).toSet().toList()..sort();
    if (normalizedPorts.isEmpty) {
      normalizedPorts.add(defaultPort);
    }

    final ranges = <String>[];
    if (network != null && network.trim().isNotEmpty) {
      ranges.add(network.trim());
    } else {
      final detected = await detectLocalSubnets();
      if (detected.isNotEmpty) {
        ranges.addAll(detected);
      } else {
        // Fast defaults for typical home/emulator setups.
        ranges.addAll([
          '192.168.0.0/24',
          '192.168.1.0/24',
          '10.0.2.0/24',
        ]);
      }
    }

    final candidates = <String>{};
    for (final range in ranges) {
      candidates.addAll(_expandCidr(range));
    }

    final found = <Map<String, dynamic>>[];
    final batchSize = 32;
    final ips = candidates.toList(growable: false);

    for (var i = 0; i < ips.length; i += batchSize) {
      final end = min(i + batchSize, ips.length);
      final batch = ips.sublist(i, end);
      final futures = <Future<Map<String, dynamic>?>>[];
      for (final ip in batch) {
        for (final port in normalizedPorts) {
          futures.add(_probeAgent(
            ip,
            port: port,
            timeoutSeconds: timeoutSeconds,
          ));
        }
      }
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) {
          found.add(result);
        }
      }
    }

    final byAddress = <String, Map<String, dynamic>>{};
    for (final item in found) {
      final address = item['address'] as String?;
      if (address != null) {
        byAddress[address] = item;
      }
    }

    return byAddress.values.toList(growable: false);
  }

  static Future<Map<String, dynamic>?> _probeAgent(
    String ip, {
    required int port,
    required int timeoutSeconds,
  }) async {
    final address = '$ip:$port';
    try {
      final uri = Uri.parse('http://$address/v1/status');
      final response = await http
          .get(uri)
          .timeout(Duration(milliseconds: max(300, timeoutSeconds * 1000)));
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) {
        return null;
      }

      return {
        'agent_id': data['agent_id'] ?? data['hostname'] ?? ip,
        'address': address,
        'os': data['os'] ?? 'unknown',
      };
    } catch (_) {
      return null;
    }
  }

  static List<String> _expandCidr(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) {
      return const [];
    }

    final prefix = int.tryParse(parts[1]);
    final octets = parts[0].split('.');
    if (prefix == null || prefix < 0 || prefix > 32 || octets.length != 4) {
      return const [];
    }

    final nums = octets.map(int.tryParse).toList();
    if (nums.any((n) => n == null || n < 0 || n > 255)) {
      return const [];
    }

    final base =
        ((nums[0]! << 24) | (nums[1]! << 16) | (nums[2]! << 8) | nums[3]!) &
            0xFFFFFFFF;
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    final network = base & mask;
    final broadcast = network | (~mask & 0xFFFFFFFF);

    // Avoid excessive scans for broad ranges.
    if (broadcast - network > 2048) {
      return const [];
    }

    final start = network + 1;
    final end = broadcast - 1;
    if (start > end) {
      return const [];
    }

    final ips = <String>[];
    for (var value = start; value <= end; value++) {
      final a = (value >> 24) & 0xFF;
      final b = (value >> 16) & 0xFF;
      final c = (value >> 8) & 0xFF;
      final d = value & 0xFF;
      ips.add('$a.$b.$c.$d');
    }
    return ips;
  }

  static List<int>? _parseMac(String mac) {
    final hex = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (hex.length != 12) return null;
    final bytes = <int>[];
    for (var i = 0; i < 12; i += 2) {
      final value = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (value == null) return null;
      bytes.add(value);
    }
    return bytes;
  }

  static List<int> _buildMagicPacket(List<int> mac) {
    final packet = <int>[];
    packet.addAll(List<int>.filled(6, 0xFF));
    for (var i = 0; i < 16; i++) {
      packet.addAll(mac);
    }
    return packet;
  }

  /// Get UI state (requires basic auth)
  static Future<Map<String, dynamic>?> getUIState(
    String address,
    String password,
  ) async {
    try {
      final uri = _httpUri(address, '/v1/ui/state');
      final response = await http.get(
        uri,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('lumos:$password'))}',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // Failed
    }
    return null;
  }

  /// Open websocket event stream from agent.
  static Uri _wsEventsUri(String address, {bool secure = false}) {
    final normalized = address.trim();
    final parsed = normalized.contains('://')
        ? Uri.tryParse(normalized)
        : Uri.tryParse('http://$normalized');
    final hostPort = parsed?.authority ?? normalized;
    final scheme = secure
        ? 'wss'
        : ((parsed?.scheme.toLowerCase() == 'https') ? 'wss' : 'ws');
    return Uri.parse('$scheme://$hostPort/v1/events');
  }

  static IOWebSocketChannel connectEvents(
    String address, {
    String? password,
    String? token,
    bool secure = false,
  }) {
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['X-Lumos-Token'] = token;
    } else if (password != null && password.isNotEmpty) {
      headers['X-Lumos-Password'] = password;
    }
    return IOWebSocketChannel.connect(
      _wsEventsUri(address, secure: secure),
      headers: headers,
      pingInterval: const Duration(seconds: 20),
    );
  }

  static ApiCommandResult _parseApiResult(http.Response response) {
    String? message;
    String? reason;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawMessage = decoded['message']?.toString();
        final rawReason = decoded['reason']?.toString();
        if (rawMessage != null && rawMessage.isNotEmpty) message = rawMessage;
        if (rawReason != null && rawReason.isNotEmpty) reason = rawReason;
      }
    } catch (_) {}
    return ApiCommandResult(
      ok: response.statusCode == 200,
      statusCode: response.statusCode,
      message: message,
      reason: reason,
    );
  }

  static Future<AgentPolicyState?> getPolicyState(
    String address, {
    required String password,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/policy/state');
      final response = await http.get(
        uri,
        headers: {
          'X-Lumos-Password': password,
        },
      ).timeout(timeout);
      if (response.statusCode != 200) return null;
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return AgentPolicyState(
        defaultTokenAllowances: _readAllowances(
          decoded['default_token_allowances'],
        ),
        tokenAllowances: _readAllowancesMap(decoded['token_allowances']),
        relayInboundAllowances: _readAllowancesMap(
          decoded['relay_inbound_allowances'],
        ),
        relayOutboundAllowances: _readAllowancesMap(
          decoded['relay_outbound_allowances'],
        ),
        tokens: (decoded['tokens'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const [],
        peers: (decoded['peers'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<ApiCommandResult> updateDefaultTokenPolicy(
    String address, {
    required String password,
    required ApiActionAllowances allowances,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/default-token',
      password: password,
      body: {'allowances': allowances.toJson()},
    );
  }

  static Future<ApiCommandResult> upsertTokenPolicy(
    String address, {
    required String password,
    required String tokenId,
    required ApiActionAllowances allowances,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/token/upsert',
      password: password,
      body: {
        'token_id': tokenId,
        'allowances': allowances.toJson(),
      },
    );
  }

  static Future<ApiCommandResult> deleteTokenPolicy(
    String address, {
    required String password,
    required String tokenId,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/token/delete',
      password: password,
      body: {'key': tokenId},
    );
  }

  static Future<ApiCommandResult> upsertRelayInboundPolicy(
    String address, {
    required String password,
    required String sourceAgentId,
    required ApiActionAllowances allowances,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/relay-inbound/upsert',
      password: password,
      body: {
        'agent_id': sourceAgentId,
        'allowances': allowances.toJson(),
      },
    );
  }

  static Future<ApiCommandResult> deleteRelayInboundPolicy(
    String address, {
    required String password,
    required String sourceAgentId,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/relay-inbound/delete',
      password: password,
      body: {'key': sourceAgentId},
    );
  }

  static Future<ApiCommandResult> upsertRelayOutboundPolicy(
    String address, {
    required String password,
    required String targetAgentId,
    required ApiActionAllowances allowances,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/relay-outbound/upsert',
      password: password,
      body: {
        'agent_id': targetAgentId,
        'allowances': allowances.toJson(),
      },
    );
  }

  static Future<ApiCommandResult> deleteRelayOutboundPolicy(
    String address, {
    required String password,
    required String targetAgentId,
  }) async {
    return _postPolicy(
      address,
      '/v1/policy/relay-outbound/delete',
      password: password,
      body: {'key': targetAgentId},
    );
  }

  static Future<ApiCommandResult> _postPolicy(
    String address,
    String path, {
    required String password,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = _httpUri(address, path);
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Lumos-Password': password,
            },
            body: json.encode(body),
          )
          .timeout(timeout);
      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }

  static ApiActionAllowances _readAllowances(dynamic value) {
    if (value is Map<String, dynamic>) {
      return ApiActionAllowances.fromJson(value);
    }
    if (value is Map) {
      return ApiActionAllowances.fromJson(Map<String, dynamic>.from(value));
    }
    return const ApiActionAllowances.allowAll();
  }

  static Map<String, ApiActionAllowances> _readAllowancesMap(dynamic value) {
    if (value is! Map) return const {};
    final out = <String, ApiActionAllowances>{};
    value.forEach((k, v) {
      final key = k.toString().trim();
      if (key.isEmpty) return;
      out[key] = _readAllowances(v);
    });
    return out;
  }

  /// Upsert peer (add or update peer registration)
  static Future<ApiCommandResult> upsertPeer(
    String address, {
    required String password,
    required String peerId,
    required String peerAddress,
    required String peerPassword,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/ui/peer/upsert');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization':
                  'Basic ${base64Encode(utf8.encode('lumos:$password'))}',
            },
            body: json.encode({
              'agent_id': peerId,
              'address': peerAddress,
              'password': peerPassword,
            }),
          )
          .timeout(timeout);
      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }

  /// Delete peer registration
  static Future<ApiCommandResult> deletePeer(
    String address, {
    required String password,
    required String peerId,
  }) async {
    try {
      final uri = _httpUri(address, '/v1/ui/peer/delete');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization':
                  'Basic ${base64Encode(utf8.encode('lumos:$password'))}',
            },
            body: json.encode({
              'agent_id': peerId,
            }),
          )
          .timeout(timeout);
      return _parseApiResult(response);
    } catch (e) {
      return ApiCommandResult(ok: false, message: e.toString());
    }
  }
}
