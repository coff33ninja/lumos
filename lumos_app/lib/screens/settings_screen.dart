import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _portsController;
  late final TextEditingController _timeoutController;
  String _scanPreset = 'custom';

  @override
  void initState() {
    super.initState();
    final provider = context.read<DeviceProvider>();
    _portsController = TextEditingController(
      text: provider.scanPorts.join(','),
    );
    _timeoutController = TextEditingController(
      text: provider.scanTimeoutSeconds.toString(),
    );
    _scanPreset = _inferPreset(provider.scanPorts, provider.scanTimeoutSeconds);
  }

  @override
  void dispose() {
    _portsController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _scanPreset,
              decoration: const InputDecoration(
                labelText: 'Scan Preset',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'fast', child: Text('Fast (1s / 8080)')),
                DropdownMenuItem(
                    value: 'balanced', child: Text('Balanced (2s / 8080,8081)')),
                DropdownMenuItem(
                    value: 'deep', child: Text('Deep (4s / 8080,8081,8090)')),
                DropdownMenuItem(value: 'custom', child: Text('Custom')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _scanPreset = value;
                });
                _applyPreset(value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portsController,
              decoration: const InputDecoration(
                labelText: 'Scan Ports',
                hintText: '8080,8081,8090',
                helperText: 'Comma-separated ports to probe per host',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final raw = (value ?? '').trim();
                if (raw.isEmpty) {
                  return 'Enter at least one port';
                }
                final ports = _parsePorts(raw);
                if (ports.isEmpty) {
                  return 'Use valid ports between 1 and 65535';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _timeoutController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scan Timeout (seconds)',
                hintText: '2',
                helperText: 'Range: 1-10 seconds',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final timeout = int.tryParse((value ?? '').trim());
                if (timeout == null || timeout < 1 || timeout > 10) {
                  return 'Timeout must be between 1 and 10';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'When a saved online agent with password exists, scan runs via the agent /v1/ui/scan endpoint (agent-side allowances apply). Otherwise the app does direct host probing on the ports above.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Save Settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('About / Project Info'),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _parsePorts(String raw) {
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((p) => p >= 1 && p <= 65535)
        .toSet()
        .toList()
      ..sort();
  }

  String _inferPreset(List<int> ports, int timeout) {
    final normalized = [...ports]..sort();
    if (_listEquals(normalized, const [8080]) && timeout == 1) return 'fast';
    if (_listEquals(normalized, const [8080, 8081]) && timeout == 2) {
      return 'balanced';
    }
    if (_listEquals(normalized, const [8080, 8081, 8090]) && timeout == 4) {
      return 'deep';
    }
    return 'custom';
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _applyPreset(String preset) {
    switch (preset) {
      case 'fast':
        _portsController.text = '8080';
        _timeoutController.text = '1';
        break;
      case 'balanced':
        _portsController.text = '8080,8081';
        _timeoutController.text = '2';
        break;
      case 'deep':
        _portsController.text = '8080,8081,8090';
        _timeoutController.text = '4';
        break;
      default:
        // Custom: keep user values.
        break;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final ports = _parsePorts(_portsController.text);
    final timeout = int.parse(_timeoutController.text.trim());

    try {
      await context.read<DeviceProvider>().updateScanSettings(
            ports: ports,
            timeoutSeconds: timeout,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan settings saved'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
