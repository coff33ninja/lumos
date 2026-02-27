import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/lumos_api.dart';

class TokenManagementScreen extends StatefulWidget {
  final Device device;

  const TokenManagementScreen({super.key, required this.device});

  @override
  State<TokenManagementScreen> createState() => _TokenManagementScreenState();
}

class _TokenManagementScreenState extends State<TokenManagementScreen> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _supported = true;
  List<AgentTokenRecord> _tokens = const [];

  @override
  void initState() {
    super.initState();
    _passwordController.text = widget.device.password ?? '';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tokens: ${widget.device.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Agent Admin Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _loadTokens,
            icon: const Icon(Icons.sync),
            label: Text(_loading ? 'Loading...' : 'Load Tokens'),
          ),
          const SizedBox(height: 12),
          if (!_supported)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'This agent does not advertise token admin capabilities.',
                ),
              ),
            ),
          if (_supported && _tokens.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No tokens found.'),
              ),
            ),
          if (_supported)
            ..._tokens.map(
              (token) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.label.isEmpty ? '(no label)' : token.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('ID: ${token.id}'),
                      Text('Scope: ${token.scope}'),
                      Text('Last used: ${token.lastUsedAt ?? 'never'}'),
                      Text('Revoked: ${token.revokedAt ?? 'no'}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _loading || token.revokedAt != null
                                ? null
                                : () => _rotateToken(token),
                            child: const Text('Rotate'),
                          ),
                          OutlinedButton(
                            onPressed: _loading || token.revokedAt != null
                                ? null
                                : () => _changeScope(token),
                            child: const Text('Change Scope'),
                          ),
                          OutlinedButton(
                            onPressed: _loading || token.revokedAt != null
                                ? null
                                : () => _revokeToken(token),
                            child: const Text('Revoke'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadTokens() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _show('Password is required.', isError: true);
      return;
    }
    setState(() => _loading = true);
    final status = await LumosApi.getStatus(widget.device.address);
    final supported = LumosApi.supportsTokenAdmin(status);
    List<AgentTokenRecord> tokens = const [];
    if (supported) {
      tokens = await LumosApi.listTokens(
        widget.device.address,
        password: password,
      );
    }
    setState(() {
      _loading = false;
      _supported = supported;
      _tokens = tokens;
    });
    if (!supported) {
      _show('Token admin unsupported on this agent.', isError: true);
      return;
    }
    _show('Loaded ${tokens.length} token(s).');
  }

  Future<void> _rotateToken(AgentTokenRecord token) async {
    final password = _passwordController.text.trim();
    setState(() => _loading = true);
    final rotated = await LumosApi.rotateToken(
      widget.device.address,
      password: password,
      tokenId: token.id,
    );
    setState(() => _loading = false);
    if (rotated == null) {
      _show('Failed to rotate token.', isError: true);
      return;
    }
    await _rebindIfCurrentToken(
      oldTokenId: token.id,
      newToken: rotated['token'] ?? '',
      newTokenId: rotated['token_id'],
      newScope: token.scope,
    );
    _show('Token rotated.');
    await _loadTokens();
  }

  Future<void> _changeScope(AgentTokenRecord token) async {
    final selectedScope = await showDialog<String>(
      context: context,
      builder: (context) {
        var scope = token.scope;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Change Token Scope'),
            content: DropdownButtonFormField<String>(
              initialValue: scope,
              items: const [
                DropdownMenuItem(
                    value: 'power-admin',
                    child: Text('power-admin (full access)')),
                DropdownMenuItem(value: 'wake-only', child: Text('wake-only')),
                DropdownMenuItem(value: 'read-only', child: Text('read-only')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => scope = value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, scope),
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    if (selectedScope == null || selectedScope == token.scope) return;

    final password = _passwordController.text.trim();
    setState(() => _loading = true);
    final paired = await LumosApi.pairToken(
      widget.device.address,
      password,
      label: token.label.isEmpty ? 'lumos-app' : token.label,
      scope: selectedScope,
    );
    if (paired == null) {
      setState(() => _loading = false);
      _show('Failed to mint replacement token.', isError: true);
      return;
    }
    await LumosApi.revokeTokenById(
      widget.device.address,
      password: password,
      tokenId: token.id,
    );
    setState(() => _loading = false);

    await _rebindIfCurrentToken(
      oldTokenId: token.id,
      newToken: paired['token'] ?? '',
      newTokenId: paired['token_id'],
      newScope: paired['scope'] ?? selectedScope,
    );
    _show('Scope changed via re-pair + revoke.');
    await _loadTokens();
  }

  Future<void> _revokeToken(AgentTokenRecord token) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Revoke Token'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Revoke'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final password = _passwordController.text.trim();
    setState(() => _loading = true);
    final result = await LumosApi.revokeTokenById(
      widget.device.address,
      password: password,
      tokenId: token.id,
    );
    setState(() => _loading = false);
    if (!result.ok) {
      _show(result.readableMessage('Failed to revoke token.'), isError: true);
      return;
    }
    final provider = context.read<DeviceProvider>();
    final idx = provider.devices.indexWhere((d) => d.id == widget.device.id);
    final current = idx == -1 ? null : provider.devices[idx];
    if (current != null && current.tokenId == token.id) {
      await provider.updateDevice(
        current.id,
        current.copyWith(
          token: null,
          tokenId: null,
          tokenScope: null,
        ),
      );
    }
    _show('Token revoked.');
    await _loadTokens();
  }

  Future<void> _rebindIfCurrentToken({
    required String oldTokenId,
    required String newToken,
    required String? newTokenId,
    required String newScope,
  }) async {
    if (newToken.isEmpty) return;
    final provider = context.read<DeviceProvider>();
    final idx = provider.devices.indexWhere((d) => d.id == widget.device.id);
    final current = idx == -1 ? null : provider.devices[idx];
    if (current == null || current.tokenId != oldTokenId) {
      return;
    }
    await provider.updateDevice(
      current.id,
      current.copyWith(
        token: newToken,
        tokenId: (newTokenId != null && newTokenId.isNotEmpty)
            ? newTokenId
            : current.tokenId,
        tokenScope: newScope,
        password: null,
      ),
    );
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}
