import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/device_provider.dart';
import '../services/lumos_api.dart';

class ScanNetworkScreen extends StatefulWidget {
  const ScanNetworkScreen({super.key});

  @override
  State<ScanNetworkScreen> createState() => _ScanNetworkScreenState();
}

class _ScanNetworkScreenState extends State<ScanNetworkScreen> {
  bool _isScanning = false;
  List<Map<String, dynamic>> _results = [];
  final _networkController = TextEditingController();
  List<String> _detectedNetworks = const [];

  @override
  void initState() {
    super.initState();
    _loadDetectedNetworks();
  }

  @override
  void dispose() {
    _networkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final scanPortsLabel = provider.scanPorts.join(',');
    final presetLabel = _inferPresetLabel(
      provider.scanPorts,
      provider.scanTimeoutSeconds,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Network'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _networkController,
                  decoration: const InputDecoration(
                    labelText: 'Network (optional)',
                    hintText: '192.168.1.0/24',
                    border: OutlineInputBorder(),
                    helperText: 'Leave empty for auto-detection',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Preset: $presetLabel | Ports: $scanPortsLabel | Timeout: ${provider.scanTimeoutSeconds}s',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _detectedNetworks.isEmpty
                          ? 'Detected networks: none (manual CIDR may be needed)'
                          : 'Detected networks: ${_detectedNetworks.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isScanning
                          ? _scanProgressLabel(provider)
                          : _lastScanSummaryLabel(provider),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanNetwork,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar),
                    label: Text(_isScanning ? 'Scanning...' : 'Scan Network'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Scanning network...'
                              : 'No devices found yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.computer),
                          title: Text(result['agent_id'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(result['address'] ?? ''),
                              if (result['os'] != null)
                                Text('OS: ${result['os']}'),
                              if (_firstMac(result) != null)
                                Text('MAC: ${_firstMac(result)}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addDevice(result),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _inferPresetLabel(List<int> ports, int timeout) {
    final sorted = [...ports]..sort();
    if (_listEquals(sorted, const [8080]) && timeout == 1) return 'Fast';
    if (_listEquals(sorted, const [8080, 8081]) && timeout == 2) {
      return 'Balanced';
    }
    if (_listEquals(sorted, const [8080, 8081, 8090]) && timeout == 4) {
      return 'Deep';
    }
    return 'Custom';
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _scanProgressLabel(DeviceProvider provider) {
    final total = provider.scanProgressTotalPorts;
    final current = provider.scanProgressCurrentPort;
    if (total <= 0) return 'Scanning...';
    final clamped = current.clamp(0, total);
    return 'Scanning port profile $clamped of $total...';
  }

  String _lastScanSummaryLabel(DeviceProvider provider) {
    final total = provider.lastScanHostsTotal;
    final reachable = provider.lastScanHostsReachable;
    final durationMs = provider.lastScanDurationMs;
    if (total <= 0 && reachable <= 0 && durationMs <= 0) {
      return 'Last scan summary will appear here.';
    }
    return 'Last scan: $reachable agent(s) found, $total host target(s) checked, ${durationMs}ms total.';
  }

  Future<void> _scanNetwork() async {
    setState(() {
      _isScanning = true;
      _results = [];
    });

    try {
      final provider = context.read<DeviceProvider>();
      final requestedNetwork = _networkController.text.trim();
      final mergeByAddress = <String, Map<String, dynamic>>{};

      if (requestedNetwork.isNotEmpty) {
        final single = await provider.scanNetwork(requestedNetwork);
        for (final result in single) {
          final address = result['address']?.toString();
          if (address != null && address.isNotEmpty) {
            mergeByAddress[address] = result;
          }
        }
      } else if (_detectedNetworks.isNotEmpty) {
        final primary = _detectedNetworks.first;
        final firstPass = await provider.scanNetwork(primary);
        for (final result in firstPass) {
          final address = result['address']?.toString();
          if (address != null && address.isNotEmpty) {
            mergeByAddress[address] = result;
          }
        }

        final remaining = _detectedNetworks.skip(1).toList(growable: false);
        if (mergeByAddress.isEmpty && remaining.isNotEmpty && mounted) {
          final shouldContinue = await _confirmAdditionalScan(remaining);
          if (shouldContinue == true) {
            for (final network in remaining) {
              final pass = await provider.scanNetwork(network);
              for (final result in pass) {
                final address = result['address']?.toString();
                if (address != null && address.isNotEmpty) {
                  mergeByAddress[address] = result;
                }
              }
            }
          }
        }
      } else {
        final fallback = await provider.scanNetwork(null);
        for (final result in fallback) {
          final address = result['address']?.toString();
          if (address != null && address.isNotEmpty) {
            mergeByAddress[address] = result;
          }
        }
      }

      setState(() {
        _results = mergeByAddress.values.toList(growable: false);
      });
    } catch (e) {
      final message = e is StateError ? e.message : 'Scan failed: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _loadDetectedNetworks() async {
    final detected = await LumosApi.detectLocalSubnets();
    if (!mounted) return;
    setState(() {
      _detectedNetworks = detected;
    });
  }

  Future<bool?> _confirmAdditionalScan(List<String> remaining) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Other Networks?'),
        content: Text(
          'No agents were found on ${_detectedNetworks.first}. '
          'Scan additional detected networks?\n\n${remaining.join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDevice(Map<String, dynamic> result) async {
    final passwordController = TextEditingController();
    var selectedScope = 'power-admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add ${result['agent_id']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Address: ${result['address']}'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Agent Password (One-Time Pairing)',
                  hintText: 'Used once to mint a secure token',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedScope,
                decoration: const InputDecoration(
                  labelText: 'Token Scope',
                  border: OutlineInputBorder(),
                  helperText: 'Applied only if password pairing is used',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'power-admin',
                    child: Text('power-admin (full access)'),
                  ),
                  DropdownMenuItem(
                    value: 'wake-only',
                    child: Text('wake-only'),
                  ),
                  DropdownMenuItem(
                    value: 'read-only',
                    child: Text('read-only'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedScope = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final pairingPassword = passwordController.text.trim();
      var effectiveScope = selectedScope;
      if (pairingPassword.isNotEmpty && selectedScope != 'power-admin') {
        final status = await LumosApi.getStatus(result['address'].toString());
        if (!LumosApi.supportsScopedPairing(status)) {
          effectiveScope = 'power-admin';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Agent does not advertise scoped pairing; using power-admin scope.'),
              ),
            );
          }
        }
      }

      await context.read<DeviceProvider>().addDeviceWithPairing(
            id: const Uuid().v4(),
            agentId: result['agent_id']?.toString(),
            name: result['agent_id'] ?? 'Unknown Device',
            address: result['address'],
            os: result['os'] ?? 'unknown',
            pairingPassword:
                pairingPassword.isNotEmpty ? pairingPassword : null,
            pairingScope: effectiveScope,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    passwordController.dispose();
  }

  String? _firstMac(Map<String, dynamic> result) {
    final direct = result['mac']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final interfaces = result['interfaces'];
    if (interfaces is List && interfaces.isNotEmpty) {
      final first = interfaces.first;
      if (first is Map) {
        final mac = first['mac']?.toString();
        if (mac != null && mac.isNotEmpty) {
          return mac;
        }
      }
    }
    return null;
  }
}
