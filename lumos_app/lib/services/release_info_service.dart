import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseInfo {
  final String tag;
  final String name;
  final String url;
  final String publishedAt;
  final bool prerelease;
  final List<ReleaseAsset> assets;
  final DateTime fetchedAt;
  final bool fromCache;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.url,
    required this.publishedAt,
    required this.prerelease,
    required this.assets,
    required this.fetchedAt,
    required this.fromCache,
  });

  ReleaseAsset? get apkAsset => _assetByNameSuffix('app-release.apk');
  ReleaseAsset? get windowsAgentAsset => _assetByNameSuffix('agent.exe');
  ReleaseAsset? get linuxAgentAsset => _assetByNameSuffix('agent-linux-amd64');

  ReleaseAsset? _assetByNameSuffix(String suffix) {
    for (final asset in assets) {
      if (asset.name.toLowerCase().endsWith(suffix.toLowerCase())) {
        return asset;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'name': name,
        'url': url,
        'published_at': publishedAt,
        'prerelease': prerelease,
        'assets': assets.map((e) => e.toJson()).toList(growable: false),
      };

  static ReleaseInfo? fromCacheJson(String jsonRaw, DateTime fetchedAt) {
    try {
      final decoded = json.decode(jsonRaw);
      if (decoded is! Map<String, dynamic>) return null;
      return ReleaseInfo(
        tag: decoded['tag']?.toString() ?? '',
        name: decoded['name']?.toString() ?? '',
        url: decoded['url']?.toString() ?? '',
        publishedAt: decoded['published_at']?.toString() ?? '',
        prerelease: decoded['prerelease'] == true,
        assets: (decoded['assets'] as List?)
                ?.whereType<Map>()
                .map((e) => ReleaseAsset.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
        fetchedAt: fetchedAt,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }
}

class ReleaseAsset {
  final String name;
  final String url;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'size': size,
      };

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReleaseInfoService {
  static const _apiUrl =
      'https://api.github.com/repos/coff33ninja/lumos/releases/latest';
  static const _cacheKeyData = 'release_info_cache_data_v2';
  static const _cacheKeyAt = 'release_info_cache_at_v2';
  static const _cacheTtl = Duration(hours: 6);

  static Future<ReleaseInfo?> getLatestRelease({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);
    final now = DateTime.now().toUtc();

    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt) <= _cacheTtl) {
      return cached;
    }

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'lumos-app',
        },
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          final item = Map<String, dynamic>.from(decoded);
          final release = ReleaseInfo(
            tag: item['tag_name']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            url: item['html_url']?.toString() ?? '',
            publishedAt: item['published_at']?.toString() ?? '',
            prerelease: item['prerelease'] == true,
            assets: ((item['assets'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => ReleaseAsset(
                      name: e['name']?.toString() ?? '',
                      url: e['browser_download_url']?.toString() ?? '',
                      size: (e['size'] as num?)?.toInt() ?? 0,
                    ))
                .where((e) => e.name.isNotEmpty && e.url.isNotEmpty)
                .toList(growable: false),
            fetchedAt: now,
            fromCache: false,
          );
          await prefs.setString(_cacheKeyData, json.encode(release.toJson()));
          await prefs.setString(_cacheKeyAt, now.toIso8601String());
          return release;
        }
      }
    } catch (_) {
      // Fall back to cache below.
    }

    return cached;
  }

  static ReleaseInfo? _readCache(SharedPreferences prefs) {
    final data = prefs.getString(_cacheKeyData);
    final atRaw = prefs.getString(_cacheKeyAt);
    if (data == null || atRaw == null) return null;
    final at = DateTime.tryParse(atRaw)?.toUtc();
    if (at == null) return null;
    return ReleaseInfo.fromCacheJson(data, at);
  }

  static bool isRemoteNewer({
    required String localVersion,
    required String remoteVersion,
  }) {
    final local = _releaseSortKey(localVersion);
    final remote = _releaseSortKey(remoteVersion);
    if (local == null || remote == null) {
      return localVersion.trim() != remoteVersion.trim() &&
          localVersion.trim().isNotEmpty;
    }
    return remote > local;
  }

  static int? versionSortKey(String raw) => _releaseSortKey(raw);

  static bool isVersionInComparatorRange({
    required String version,
    required String range,
  }) {
    final parsedVersion = _parseSemVer(version);
    if (parsedVersion == null) return false;

    final rawRange = range.trim();
    if (rawRange.isEmpty) return false;
    if (rawRange == '*') return true;

    final tokens = rawRange
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return false;

    for (final token in tokens) {
      if (!_matchesComparator(parsedVersion, token)) {
        return false;
      }
    }
    return true;
  }

  static int? _releaseSortKey(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final dateMatch = RegExp(r'(\d{4})[.\-](\d{2})[.\-](\d{2})[-_]?(\d{4})?')
        .firstMatch(clean);
    if (dateMatch != null) {
      final y = int.tryParse(dateMatch.group(1) ?? '');
      final m = int.tryParse(dateMatch.group(2) ?? '');
      final d = int.tryParse(dateMatch.group(3) ?? '');
      final hmRaw = dateMatch.group(4) ?? '0000';
      final hh = hmRaw.length >= 2 ? int.tryParse(hmRaw.substring(0, 2)) : 0;
      final mm = hmRaw.length >= 4 ? int.tryParse(hmRaw.substring(2, 4)) : 0;
      if (y != null && m != null && d != null) {
        return y * 100000000 +
            m * 1000000 +
            d * 10000 +
            (hh ?? 0) * 100 +
            (mm ?? 0);
      }
    }

    final semver = RegExp(r'v?(\d+)\.(\d+)\.(\d+)').firstMatch(clean);
    if (semver != null) {
      final major = int.tryParse(semver.group(1) ?? '');
      final minor = int.tryParse(semver.group(2) ?? '');
      final patch = int.tryParse(semver.group(3) ?? '');
      if (major != null && minor != null && patch != null) {
        return major * 1000000 + minor * 1000 + patch;
      }
    }
    return null;
  }

  static _SemVer? _parseSemVer(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) return null;
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    final buildSeparator = normalized.indexOf('+');
    if (buildSeparator >= 0) {
      normalized = normalized.substring(0, buildSeparator);
    }

    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.\-]+))?$',
    ).firstMatch(normalized);
    if (match == null) return null;

    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '');
    if (major == null || minor == null || patch == null) {
      return null;
    }
    return _SemVer(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: match.group(4)?.trim() ?? '',
    );
  }

  static int _compareSemVer(_SemVer left, _SemVer right) {
    if (left.major != right.major) {
      return left.major.compareTo(right.major);
    }
    if (left.minor != right.minor) {
      return left.minor.compareTo(right.minor);
    }
    if (left.patch != right.patch) {
      return left.patch.compareTo(right.patch);
    }

    final leftPre = left.preRelease.trim();
    final rightPre = right.preRelease.trim();
    if (leftPre.isEmpty && rightPre.isEmpty) return 0;
    if (leftPre.isEmpty) return 1;
    if (rightPre.isEmpty) return -1;
    return leftPre.compareTo(rightPre);
  }

  static bool _matchesComparator(_SemVer version, String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return true;

    final match = RegExp(r'^(>=|<=|>|<|==|=)\s*(.+)$').firstMatch(trimmed);
    final comparator = match?.group(1) ?? '=';
    final rhsRaw = (match?.group(2) ?? trimmed).trim();
    final rhs = _parseSemVer(rhsRaw);
    if (rhs == null) return false;

    final cmp = _compareSemVer(version, rhs);
    switch (comparator) {
      case '>':
        return cmp > 0;
      case '>=':
        return cmp >= 0;
      case '<':
        return cmp < 0;
      case '<=':
        return cmp <= 0;
      case '=':
      case '==':
        return cmp == 0;
      default:
        return false;
    }
  }
}

class _SemVer {
  final int major;
  final int minor;
  final int patch;
  final String preRelease;

  const _SemVer({
    required this.major,
    required this.minor,
    required this.patch,
    required this.preRelease,
  });
}
