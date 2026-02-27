import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/lumos_api.dart';

class AgentPolicyScreen extends StatefulWidget {
  final Device device;

  const AgentPolicyScreen({super.key, required this.device});

  @override
  State<AgentPolicyScreen> createState() => _AgentPolicyScreenState();
}

class _AgentPolicyScreenState extends State<AgentPolicyScreen> {
  final _passwordController = TextEditingController();
  final _tokenIdController = TextEditingController();
  final _inboundPeerController = TextEditingController();
  final _outboundPeerController = TextEditingController();

  bool _loading = false;
  AgentPolicyState? _state;
  ApiActionAllowances _defaultAllowances = const ApiActionAllowances.allowAll();
  ApiActionAllowances _tokenAllowances = const ApiActionAllowances.allowAll();
  ApiActionAllowances _inboundAllowances = const ApiActionAllowances.allowAll();
  ApiActionAllowances _outboundAllowances =
      const ApiActionAllowances.allowAll();

  String? _selectedTokenId;
  String? _selectedInboundPeer;
  String? _selectedOutboundPeer;

  @override
  void initState() {
    super.initState();
    _passwordController.text = widget.device.password ?? '';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _tokenIdController.dispose();
    _inboundPeerController.dispose();
    _outboundPeerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agent Policies: ${widget.device.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Agent Admin Password',
              hintText: 'Required for /v1/policy/*',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _loadState,
            icon: const Icon(Icons.sync),
            label: Text(_loading ? 'Loading...' : 'Load Policy State'),
          ),
          const SizedBox(height: 16),
          if (_state == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'Load policy state to edit default, token, and relay allowances.'),
              ),
            ),
          if (_state != null) ...[
            _buildDefaultPolicyCard(),
            const SizedBox(height: 12),
            _buildTokenPolicyCard(),
            const SizedBox(height: 12),
            _buildRelayInboundPolicyCard(),
            const SizedBox(height: 12),
            _buildRelayOutboundPolicyCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultPolicyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Default Token Allowances',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _allowanceEditor(
              _defaultAllowances,
              (next) => setState(() => _defaultAllowances = next),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _saveDefaultAllowances,
              child: const Text('Save Default Token Policy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenPolicyCard() {
    final tokenIds = <String>{
      ...?_state?.tokens
          .map((e) => e['token_id']?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty),
      ...?_state?.tokenAllowances.keys,
    }.toList()
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Per-Token Allowances',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTokenId,
              decoration: const InputDecoration(
                labelText: 'Existing Token ID',
                border: OutlineInputBorder(),
              ),
              items: tokenIds
                  .map((id) => DropdownMenuItem(
                        value: id,
                        child: Text(_tokenLabel(id)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTokenId = value;
                  if (value != null && value.isNotEmpty) {
                    _tokenIdController.text = value;
                    _tokenAllowances = _state?.tokenAllowances[value] ??
                        const ApiActionAllowances.allowAll();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenIdController,
              decoration: const InputDecoration(
                labelText: 'Token ID',
                hintText: 'token_id from /v1/auth/token/list',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selected token scope: ${_selectedTokenScopeLabel()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Scope changes require token rotation/re-pairing.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            _allowanceEditor(
              _tokenAllowances,
              (next) => setState(() => _tokenAllowances = next),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveTokenAllowances,
                    child: const Text('Upsert Token Policy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _deleteTokenPolicy,
                    child: const Text('Delete Token Policy'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _tokenLabel(String tokenId) {
    final scope = _tokenScopeById(tokenId);
    if (scope == null || scope.trim().isEmpty) return tokenId;
    return '$tokenId ($scope)';
  }

  String? _tokenScopeById(String tokenId) {
    for (final token in _state?.tokens ?? const <Map<String, dynamic>>[]) {
      final id = token['token_id']?.toString() ?? '';
      if (id == tokenId) {
        final scope = token['scope']?.toString();
        if (scope != null && scope.trim().isNotEmpty) return scope.trim();
      }
    }
    return null;
  }

  String _selectedTokenScopeLabel() {
    final tokenId = _tokenIdController.text.trim();
    if (tokenId.isEmpty) return 'unknown';
    return _tokenScopeById(tokenId) ?? 'unknown';
  }

  Widget _buildRelayInboundPolicyCard() {
    final peers = <String>{
      ...?_state?.peers,
      ...?_state?.relayInboundAllowances.keys,
    }.toList()
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Relay Inbound (source agent)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedInboundPeer,
              decoration: const InputDecoration(
                labelText: 'Existing Source Agent ID',
                border: OutlineInputBorder(),
              ),
              items: peers
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedInboundPeer = value;
                  if (value != null && value.isNotEmpty) {
                    _inboundPeerController.text = value;
                    _inboundAllowances =
                        _state?.relayInboundAllowances[value] ??
                            const ApiActionAllowances.allowAll();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inboundPeerController,
              decoration: const InputDecoration(
                labelText: 'Source Agent ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _allowanceEditor(
              _inboundAllowances,
              (next) => setState(() => _inboundAllowances = next),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveInboundAllowances,
                    child: const Text('Upsert Inbound'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _deleteInboundPolicy,
                    child: const Text('Delete Inbound'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayOutboundPolicyCard() {
    final peers = <String>{
      ...?_state?.peers,
      ...?_state?.relayOutboundAllowances.keys,
    }.toList()
      ..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Relay Outbound (target agent)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedOutboundPeer,
              decoration: const InputDecoration(
                labelText: 'Existing Target Agent ID',
                border: OutlineInputBorder(),
              ),
              items: peers
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedOutboundPeer = value;
                  if (value != null && value.isNotEmpty) {
                    _outboundPeerController.text = value;
                    _outboundAllowances =
                        _state?.relayOutboundAllowances[value] ??
                            const ApiActionAllowances.allowAll();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _outboundPeerController,
              decoration: const InputDecoration(
                labelText: 'Target Agent ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _allowanceEditor(
              _outboundAllowances,
              (next) => setState(() => _outboundAllowances = next),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveOutboundAllowances,
                    child: const Text('Upsert Outbound'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _deleteOutboundPolicy,
                    child: const Text('Delete Outbound'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _allowanceEditor(
    ApiActionAllowances source,
    ValueChanged<ApiActionAllowances> onChanged,
  ) {
    Widget tile(String title, bool value, ValueChanged<bool> setter) {
      return SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: setter,
      );
    }

    return Column(
      children: [
        tile('Wake', source.wake, (v) => onChanged(_copy(source, wake: v))),
        tile(
          'Shutdown',
          source.shutdown,
          (v) => onChanged(_copy(source, shutdown: v)),
        ),
        tile('Reboot', source.reboot,
            (v) => onChanged(_copy(source, reboot: v))),
        tile('Sleep', source.sleep, (v) => onChanged(_copy(source, sleep: v))),
        tile('Relay', source.relay, (v) => onChanged(_copy(source, relay: v))),
      ],
    );
  }

  ApiActionAllowances _copy(
    ApiActionAllowances a, {
    bool? wake,
    bool? shutdown,
    bool? reboot,
    bool? sleep,
    bool? relay,
  }) {
    return ApiActionAllowances(
      wake: wake ?? a.wake,
      shutdown: shutdown ?? a.shutdown,
      reboot: reboot ?? a.reboot,
      sleep: sleep ?? a.sleep,
      relay: relay ?? a.relay,
    );
  }

  Future<void> _loadState() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _show('Password is required.', isError: true);
      return;
    }
    setState(() => _loading = true);
    final state = await LumosApi.getPolicyState(
      widget.device.address,
      password: password,
    );
    setState(() {
      _loading = false;
      _state = state;
      if (state != null) {
        _defaultAllowances = state.defaultTokenAllowances;
      }
    });
    if (state == null) {
      _show('Failed to load policy state.', isError: true);
    } else {
      _show('Policy state loaded.');
    }
  }

  Future<void> _saveDefaultAllowances() async {
    final result = await LumosApi.updateDefaultTokenPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      allowances: _defaultAllowances,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to update default policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Default policy updated'));
    await _loadState();
  }

  Future<void> _saveTokenAllowances() async {
    final tokenId = _tokenIdController.text.trim();
    if (tokenId.isEmpty) {
      _show('Token ID is required.', isError: true);
      return;
    }
    final result = await LumosApi.upsertTokenPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      tokenId: tokenId,
      allowances: _tokenAllowances,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to upsert token policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Token policy upserted'));
    await _loadState();
  }

  Future<void> _deleteTokenPolicy() async {
    final tokenId = _tokenIdController.text.trim();
    if (tokenId.isEmpty) {
      _show('Token ID is required.', isError: true);
      return;
    }
    final result = await LumosApi.deleteTokenPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      tokenId: tokenId,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to delete token policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Token policy deleted'));
    await _loadState();
  }

  Future<void> _saveInboundAllowances() async {
    final agentId = _inboundPeerController.text.trim();
    if (agentId.isEmpty) {
      _show('Source agent ID is required.', isError: true);
      return;
    }
    final result = await LumosApi.upsertRelayInboundPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      sourceAgentId: agentId,
      allowances: _inboundAllowances,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to upsert inbound policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Relay inbound policy upserted'));
    await _loadState();
  }

  Future<void> _deleteInboundPolicy() async {
    final agentId = _inboundPeerController.text.trim();
    if (agentId.isEmpty) {
      _show('Source agent ID is required.', isError: true);
      return;
    }
    final result = await LumosApi.deleteRelayInboundPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      sourceAgentId: agentId,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to delete inbound policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Relay inbound policy deleted'));
    await _loadState();
  }

  Future<void> _saveOutboundAllowances() async {
    final agentId = _outboundPeerController.text.trim();
    if (agentId.isEmpty) {
      _show('Target agent ID is required.', isError: true);
      return;
    }
    final result = await LumosApi.upsertRelayOutboundPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      targetAgentId: agentId,
      allowances: _outboundAllowances,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to upsert outbound policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Relay outbound policy upserted'));
    await _loadState();
  }

  Future<void> _deleteOutboundPolicy() async {
    final agentId = _outboundPeerController.text.trim();
    if (agentId.isEmpty) {
      _show('Target agent ID is required.', isError: true);
      return;
    }
    final result = await LumosApi.deleteRelayOutboundPolicy(
      widget.device.address,
      password: _passwordController.text.trim(),
      targetAgentId: agentId,
    );
    if (!result.ok) {
      _show(result.readableMessage('Failed to delete outbound policy'),
          isError: true);
      return;
    }
    _show(result.readableMessage('Relay outbound policy deleted'));
    await _loadState();
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
