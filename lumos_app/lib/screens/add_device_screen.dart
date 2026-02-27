import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/device_provider.dart';
import '../services/lumos_api.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedOS = 'windows';
  String _selectedPairScope = 'power-admin';

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Device'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'My PC',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a device name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: '192.168.1.100:8080 or https://192.168.1.100:8443',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedOS,
              decoration: const InputDecoration(
                labelText: 'Operating System',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'windows', child: Text('Windows')),
                DropdownMenuItem(value: 'linux', child: Text('Linux')),
                DropdownMenuItem(value: 'macos', child: Text('macOS')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedOS = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Agent Password (One-Time Pairing)',
                hintText: 'Used once to mint a secure token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedPairScope,
              decoration: const InputDecoration(
                labelText: 'Token Scope',
                border: OutlineInputBorder(),
                helperText: 'Used when password pairing is provided',
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
                setState(() {
                  _selectedPairScope = value;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveDevice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Add Device'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var effectiveScope = _selectedPairScope;
    final pairingPassword = _passwordController.text.trim();
    if (pairingPassword.isNotEmpty && effectiveScope != 'power-admin') {
      final status = await LumosApi.getStatus(_addressController.text.trim());
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
          name: _nameController.text,
          address: _addressController.text,
          os: _selectedOS,
          agentId: null,
          pairingPassword: pairingPassword.isNotEmpty ? pairingPassword : null,
          pairingScope: effectiveScope,
        );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
