import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/release_info_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final String _buildRef =
      const String.fromEnvironment('LUMOS_BUILD_REF', defaultValue: 'dev');

  PackageInfo? _packageInfo;
  ReleaseInfo? _releaseInfo;
  bool _loadingRelease = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pkg = await PackageInfo.fromPlatform();
    final release = await ReleaseInfoService.getLatestRelease();
    if (!mounted) return;
    setState(() {
      _packageInfo = pkg;
      _releaseInfo = release;
      _loadingRelease = false;
    });
  }

  Future<void> _refreshRelease() async {
    setState(() {
      _loadingRelease = true;
    });
    final release =
        await ReleaseInfoService.getLatestRelease(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _releaseInfo = release;
      _loadingRelease = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pkg = _packageInfo;
    final release = _releaseInfo;
    final localAppVersion = pkg == null ? '' : pkg.version.trim();
    final remoteTag = release?.tag.trim() ?? '';
    final appUpdateAvailable = localAppVersion.isNotEmpty &&
        remoteTag.isNotEmpty &&
        ReleaseInfoService.isRemoteNewer(
          localVersion: localAppVersion,
          remoteVersion: remoteTag,
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Lumos'),
        actions: [
          IconButton(
            onPressed: _loadingRelease ? null : _refreshRelease,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh release info',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App Version'),
            subtitle: Text(
              pkg == null
                  ? 'Loading...'
                  : '${pkg.version} (${pkg.buildNumber}) · build $_buildRef',
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Latest GitHub Release'),
            subtitle: _loadingRelease
                ? const Text('Loading release info...')
                : (release == null
                    ? const Text(
                        'Release info unavailable (using offline mode).')
                    : Text(
                        '${release.tag.isNotEmpty ? release.tag : release.name}\n'
                        '${release.prerelease ? 'Channel: prerelease' : 'Channel: stable'}\n'
                        'Published: ${release.publishedAt.isEmpty ? 'unknown' : release.publishedAt}\n'
                        '${release.fromCache ? 'Source: cached' : 'Source: github'}\n'
                        'Release URL: ${release.url}\n'
                        'APK: ${release.apkAsset?.url ?? 'not found in assets'}\n'
                        'Agent (Windows): ${release.windowsAgentAsset?.url ?? 'not found in assets'}\n'
                        'Agent (Linux): ${release.linuxAgentAsset?.url ?? 'not found in assets'}',
                      )),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('APK Update Status'),
            subtitle: Text(
              appUpdateAvailable
                  ? 'Update available (local: $localAppVersion, latest tag: $remoteTag)'
                  : (remoteTag.isEmpty
                      ? 'Latest release unavailable.'
                      : 'No newer APK tag detected from current version signal.'),
            ),
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Author / Maintainer'),
            subtitle:
                Text('coff33ninja · https://github.com/coff33ninja/lumos'),
          ),
          const Divider(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Intent: This project is built to provide practical, useful remote power control without forcing paid software choices.\n\n'
                'I am learning and improving this product continuously with user feedback and support.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Disclaimer: Provided as-is without warranty. Use at your own risk. '
                'The author is not liable for damages, downtime, data loss, or misuse. '
                'Always test in your own environment and apply appropriate security controls.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
