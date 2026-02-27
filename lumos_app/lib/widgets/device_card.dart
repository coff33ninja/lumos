import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/agent_policy_screen.dart';
import '../screens/peer_management_screen.dart';
import '../screens/token_management_screen.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/release_info_service.dart';

class DeviceCard extends StatelessWidget {
  final Device device;

  const DeviceCard({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final latestReleaseTag = provider.latestRelease?.tag ?? '';
    final hasAgentVersion =
        device.agentVersion != null && device.agentVersion!.trim().isNotEmpty;
    final agentUpdateAvailable = hasAgentVersion &&
        latestReleaseTag.isNotEmpty &&
        ReleaseInfoService.isRemoteNewer(
          localVersion: device.agentVersion!.trim(),
          remoteVersion: latestReleaseTag,
        );
    final hasAuth = (device.token != null && device.token!.isNotEmpty) ||
        (device.password != null && device.password!.isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getStatusColor().withValues(alpha: 0.1),
              _getStatusColor().withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildOSBadge(),
                  IconButton(
                    onPressed: () => _openPeerManagementScreen(context),
                    icon: const Icon(Icons.hub),
                    color: Colors.orangeAccent,
                    tooltip: 'Peer Management',
                  ),
                  IconButton(
                    onPressed: () => _openPolicyScreen(context),
                    icon: const Icon(Icons.tune),
                    color: Colors.lightBlueAccent,
                    tooltip: 'Agent Policy',
                  ),
                  IconButton(
                    onPressed: () => _openTokenManagementScreen(context),
                    icon: const Icon(Icons.key),
                    color: Colors.amberAccent,
                    tooltip: 'Token Management',
                  ),
                  IconButton(
                    onPressed: () => _handleDelete(context),
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.redAccent,
                    tooltip: 'Delete Agent',
                  ),
                ],
              ),
              if (device.interfaces.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: device.interfaces.map((iface) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        iface.mac,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildCapabilityBadges(
                  hasAuth,
                  agentVersion: device.agentVersion,
                  latestReleaseTag: latestReleaseTag,
                  agentUpdateAvailable: agentUpdateAvailable,
                ),
              ),
              const SizedBox(height: 10),
              _buildHealthRow(),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionButton(
                    context,
                    icon: Icons.power_settings_new,
                    label: 'Wake',
                    color: Colors.green,
                    onPressed:
                        device.status != DeviceStatus.online && device.allowWake
                            ? () => _handleWake(context)
                            : null,
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    icon: Icons.power_off,
                    label: 'Shutdown',
                    color: Colors.red,
                    onPressed: device.status == DeviceStatus.online &&
                            hasAuth &&
                            device.allowShutdown
                        ? () => _handleShutdown(context)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    icon: Icons.refresh,
                    label: 'Reboot',
                    color: Colors.orange,
                    onPressed: device.status == DeviceStatus.online &&
                            hasAuth &&
                            device.allowReboot
                        ? () => _handleReboot(context)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    icon: Icons.bedtime,
                    label: 'Sleep',
                    color: Colors.blue,
                    onPressed: device.status == DeviceStatus.online &&
                            hasAuth &&
                            device.allowSleep
                        ? () => _handleSleep(context)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _getStatusColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildOSBadge() {
    IconData icon;
    switch (device.os.toLowerCase()) {
      case 'windows':
        icon = Icons.window;
        break;
      case 'linux':
        icon = Icons.computer;
        break;
      case 'darwin':
      case 'macos':
        icon = Icons.apple;
        break;
      default:
        icon = Icons.devices;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: Colors.white70),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null
              ? color.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          foregroundColor: onPressed != null ? color : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (device.status) {
      case DeviceStatus.online:
        return Colors.green;
      case DeviceStatus.offline:
        return Colors.red;
      case DeviceStatus.sleeping:
        return Colors.blue;
      case DeviceStatus.unknown:
        return Colors.grey;
    }
  }

  List<Widget> _buildCapabilityBadges(
    bool hasAuth, {
    String? agentVersion,
    required String latestReleaseTag,
    required bool agentUpdateAvailable,
  }) {
    final supportsPower = _supportsPowerActions();
    return [
      _capabilityChip('Wake', device.interfaces.isNotEmpty),
      _capabilityChip('Power', supportsPower && hasAuth),
      _capabilityChip(
          'Pair Token', device.token != null && device.token!.isNotEmpty),
      if (device.tokenScope != null && device.tokenScope!.trim().isNotEmpty)
        _capabilityChip('Scope', true, value: device.tokenScope!.trim()),
      if (agentVersion != null && agentVersion.trim().isNotEmpty)
        _capabilityChip('Agent Ver', true, value: agentVersion.trim()),
      if (latestReleaseTag.trim().isNotEmpty)
        _capabilityChip('Latest', true, value: latestReleaseTag.trim()),
      if (agentUpdateAvailable)
        _capabilityChip('Agent Update', true, value: 'available'),
    ];
  }

  Widget _capabilityChip(String label, bool supported, {String? value}) {
    final text = value == null || value.isEmpty
        ? '$label: ${supported ? 'Yes' : 'No'}'
        : '$label: $value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: supported
            ? Colors.teal.withValues(alpha: 0.22)
            : Colors.grey.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: supported ? Colors.tealAccent : Colors.white54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHealthRow() {
    if (device.lastCommandAt == null || device.lastCommandAction == null) {
      return Text(
        'Health: No command history yet',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      );
    }
    final success = device.lastCommandSuccess == true;
    final when = _formatRelative(device.lastCommandAt!);
    return Text(
      'Health: ${device.lastCommandAction} ${success ? 'succeeded' : 'failed'} $when'
      '${device.lastCommandMessage != null ? ' (${device.lastCommandMessage})' : ''}',
      style: TextStyle(
        color:
            success ? Colors.greenAccent.shade100 : Colors.redAccent.shade100,
        fontSize: 12,
      ),
    );
  }

  String _formatRelative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool _supportsPowerActions() {
    final os = device.os.toLowerCase();
    return os == 'windows' || os == 'linux';
  }

  Future<void> _openPolicyScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentPolicyScreen(device: device),
      ),
    );
  }

  Future<void> _openTokenManagementScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TokenManagementScreen(device: device),
      ),
    );
  }

  Future<void> _openPeerManagementScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PeerManagementScreen(device: device),
      ),
    );
  }

  Future<void> _handleWake(BuildContext context) async {
    if (device.interfaces.isEmpty) {
      _showError(context, 'No MAC address available');
      return;
    }

    final provider = context.read<DeviceProvider>();
    final success = await provider.wakeDevice(
      device.id,
      device.interfaces.first.mac,
    );

    if (context.mounted) {
      if (success) {
        _showSuccess(context, 'Wake signal sent');
      } else {
        _showError(
          context,
          _latestCommandMessage(
            provider,
            fallback: 'Failed to wake device',
          ),
        );
      }
    }
  }

  Future<void> _handleShutdown(BuildContext context) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Shutdown ${device.name}?',
      'This will power off the device.',
    );

    if (!confirmed) return;

    if (context.mounted) {
      final provider = context.read<DeviceProvider>();
      final success = await provider.shutdownDevice(device.id);

      if (context.mounted) {
        if (success) {
          _showSuccess(
            context,
            _latestCommandMessage(
              provider,
              fallback: 'Shutdown command sent',
            ),
          );
        } else {
          _showError(
            context,
            _latestCommandMessage(
              provider,
              fallback: 'Failed to shutdown device',
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReboot(BuildContext context) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Reboot ${device.name}?',
      'This will restart the device.',
    );

    if (!confirmed) return;

    if (context.mounted) {
      final provider = context.read<DeviceProvider>();
      final success = await provider.rebootDevice(device.id);

      if (context.mounted) {
        if (success) {
          _showSuccess(
            context,
            _latestCommandMessage(
              provider,
              fallback: 'Reboot command sent',
            ),
          );
        } else {
          _showError(
            context,
            _latestCommandMessage(
              provider,
              fallback: 'Failed to reboot device',
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSleep(BuildContext context) async {
    final provider = context.read<DeviceProvider>();
    final success = await provider.sleepDevice(device.id);

    if (context.mounted) {
      if (success) {
        _showSuccess(
          context,
          _latestCommandMessage(
            provider,
            fallback: 'Sleep command sent',
          ),
        );
      } else {
        _showError(
          context,
          _latestCommandMessage(
            provider,
            fallback: 'Failed to sleep device',
          ),
        );
      }
    }
  }

  String _latestCommandMessage(
    DeviceProvider provider, {
    required String fallback,
  }) {
    for (final d in provider.devices) {
      if (d.id == device.id) {
        final message = d.lastCommandMessage?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
        break;
      }
    }
    return fallback;
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Delete ${device.name}?',
      'This removes the agent from the app. If token auth exists, it will be revoked on the agent.',
    );
    if (!confirmed) return;

    if (context.mounted) {
      final provider = context.read<DeviceProvider>();
      final success = await provider.deleteDevice(device.id);
      if (context.mounted) {
        if (success) {
          _showSuccess(context, 'Agent deleted');
        } else {
          _showError(context, 'Failed to delete agent');
        }
      }
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
