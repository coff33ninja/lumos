class Device {
  final String id;
  final String? agentId;
  final String name;
  final String address;
  final String? mac;
  final String os;
  final String? agentVersion;
  final String? agentAppRange;
  final DeviceStatus status;
  final String? password;
  final String? token;
  final String? tokenId;
  final String? tokenScope;
  final DateTime? lastSeen;
  final DateTime? lastCommandAt;
  final String? lastCommandAction;
  final bool? lastCommandSuccess;
  final String? lastCommandMessage;
  final List<NetworkInterface> interfaces;
  final bool allowWake;
  final bool allowShutdown;
  final bool allowReboot;
  final bool allowSleep;

  Device({
    required this.id,
    this.agentId,
    required this.name,
    required this.address,
    this.mac,
    required this.os,
    this.agentVersion,
    this.agentAppRange,
    this.status = DeviceStatus.unknown,
    this.password,
    this.token,
    this.tokenId,
    this.tokenScope,
    this.lastSeen,
    this.lastCommandAt,
    this.lastCommandAction,
    this.lastCommandSuccess,
    this.lastCommandMessage,
    this.interfaces = const [],
    this.allowWake = true,
    this.allowShutdown = true,
    this.allowReboot = true,
    this.allowSleep = true,
  });

  Device copyWith({
    String? id,
    String? agentId,
    String? name,
    String? address,
    String? mac,
    String? os,
    String? agentVersion,
    String? agentAppRange,
    DeviceStatus? status,
    String? password,
    String? token,
    String? tokenId,
    String? tokenScope,
    DateTime? lastSeen,
    DateTime? lastCommandAt,
    String? lastCommandAction,
    bool? lastCommandSuccess,
    String? lastCommandMessage,
    List<NetworkInterface>? interfaces,
    bool? allowWake,
    bool? allowShutdown,
    bool? allowReboot,
    bool? allowSleep,
  }) {
    return Device(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      name: name ?? this.name,
      address: address ?? this.address,
      mac: mac ?? this.mac,
      os: os ?? this.os,
      agentVersion: agentVersion ?? this.agentVersion,
      agentAppRange: agentAppRange ?? this.agentAppRange,
      status: status ?? this.status,
      password: password ?? this.password,
      token: token ?? this.token,
      tokenId: tokenId ?? this.tokenId,
      tokenScope: tokenScope ?? this.tokenScope,
      lastSeen: lastSeen ?? this.lastSeen,
      lastCommandAt: lastCommandAt ?? this.lastCommandAt,
      lastCommandAction: lastCommandAction ?? this.lastCommandAction,
      lastCommandSuccess: lastCommandSuccess ?? this.lastCommandSuccess,
      lastCommandMessage: lastCommandMessage ?? this.lastCommandMessage,
      interfaces: interfaces ?? this.interfaces,
      allowWake: allowWake ?? this.allowWake,
      allowShutdown: allowShutdown ?? this.allowShutdown,
      allowReboot: allowReboot ?? this.allowReboot,
      allowSleep: allowSleep ?? this.allowSleep,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'name': name,
      'address': address,
      'mac': mac,
      'os': os,
      'agentVersion': agentVersion,
      'agentAppRange': agentAppRange,
      'status': status.toString(),
      'password': password,
      'token': token,
      'tokenId': tokenId,
      'tokenScope': tokenScope,
      'lastSeen': lastSeen?.toIso8601String(),
      'lastCommandAt': lastCommandAt?.toIso8601String(),
      'lastCommandAction': lastCommandAction,
      'lastCommandSuccess': lastCommandSuccess,
      'lastCommandMessage': lastCommandMessage,
      'interfaces': interfaces.map((i) => i.toJson()).toList(),
      'allowWake': allowWake,
      'allowShutdown': allowShutdown,
      'allowReboot': allowReboot,
      'allowSleep': allowSleep,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      agentId: json['agentId'] ?? json['agent_id'],
      name: json['name'],
      address: json['address'],
      mac: json['mac'],
      os: json['os'],
      agentVersion: json['agentVersion'] ?? json['agent_version'],
      agentAppRange: json['agentAppRange'] ?? json['agent_app_range'],
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DeviceStatus.unknown,
      ),
      password: json['password'],
      token: json['token'],
      tokenId: json['tokenId'],
      tokenScope: json['tokenScope'] ?? json['token_scope'],
      lastSeen:
          json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      lastCommandAt: json['lastCommandAt'] != null
          ? DateTime.parse(json['lastCommandAt'])
          : null,
      lastCommandAction: json['lastCommandAction'],
      lastCommandSuccess: json['lastCommandSuccess'],
      lastCommandMessage: json['lastCommandMessage'],
      interfaces: (json['interfaces'] as List?)
              ?.map((i) => NetworkInterface.fromJson(i))
              .toList() ??
          [],
      allowWake: json['allowWake'] is bool ? json['allowWake'] : true,
      allowShutdown:
          json['allowShutdown'] is bool ? json['allowShutdown'] : true,
      allowReboot: json['allowReboot'] is bool ? json['allowReboot'] : true,
      allowSleep: json['allowSleep'] is bool ? json['allowSleep'] : true,
    );
  }
}

class NetworkInterface {
  final String name;
  final String mac;
  final List<String> ips;

  NetworkInterface({
    required this.name,
    required this.mac,
    required this.ips,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mac': mac,
      'ips': ips,
    };
  }

  factory NetworkInterface.fromJson(Map<String, dynamic> json) {
    return NetworkInterface(
      name: json['name'],
      mac: json['mac'],
      ips: List<String>.from(json['ips']),
    );
  }
}

enum DeviceStatus {
  online,
  offline,
  sleeping,
  unknown,
}
