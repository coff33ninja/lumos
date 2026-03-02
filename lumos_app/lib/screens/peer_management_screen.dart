import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/lumos_api.dart';

class PeerManagementScreen extends StatefulWidget {
  final Device device;

  const PeerManagementScreen({
    super.key,
    required this.device,
  });

  @override
  State<PeerManagementScreen> createState() => _PeerManagementScreenState();
}

class _PeerManagementScreenState extends State<PeerManagementScreen> {
  final _passwordController = TextEditingController();
  final _peerIdController = TextEditingController();
  final _peerAddressController = TextEditingController();
  final _peerPasswordController = TextEditingController();

  bool _loading = false;
  String? _message;
  bool _isError = false;
  List<String> _peers = [];
  bool _joinHive = false; // New: Join hive toggle

  @override
  void initState() {
    super.initState();
    _loadPeers();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _peerIdController.dispose();
    _peerAddressController.dispose();
    _peerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Management'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F1E),
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildAuthCard(),
                    const SizedBox(height: 16),
                    _buildPeerListCard(),
                    const SizedBox(height: 16),
                    _buildAddPeerCard(),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      _buildMessageCard(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: const Color(0xFF1E1E2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[300],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'About Peer Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Register other Lumos agents as peers to enable agent-to-agent relay commands. '
              'Peers can forward wake/power commands to devices they can reach.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Device: ${widget.device.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            Text(
              'Address: ${widget.device.address}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Card(
      color: const Color(0xFF1E1E2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Authentication',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Agent Password',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Required for peer operations',
                hintStyle: const TextStyle(color: Colors.white38),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[300]!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerListCard() {
    return Card(
      color: const Color(0xFF1E1E2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Registered Peers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: _loadPeers,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_peers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No peers registered yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ),
              )
            else
              ..._peers.map((peer) => _buildPeerItem(peer)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerItem(String peerId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue[300]!.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hub,
            color: Colors.blue[300],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              peerId,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deletePeer(peerId),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPeerCard() {
    return Card(
      color: const Color(0xFF1E1E2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Peer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _peerIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Peer Agent ID',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g., DESKTOP-ABC123',
                hintStyle: const TextStyle(color: Colors.white38),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[300]!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _peerAddressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Peer Address',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g., 192.168.1.100:8080',
                hintStyle: const TextStyle(color: Colors.white38),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[300]!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _peerPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Peer Password',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Required to verify peer access',
                hintStyle: const TextStyle(color: Colors.white38),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[300]!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Join Hive toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _joinHive ? Colors.orange.withValues(alpha: 0.5) : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hub_outlined,
                    color: _joinHive ? Colors.orange[300] : Colors.white54,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Hive (Auto-sync Cluster Key)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automatically sync cluster key for peer-to-peer communication',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _joinHive,
                    onChanged: (value) {
                      setState(() {
                        _joinHive = value;
                      });
                    },
                    activeTrackColor: Colors.orange[300],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addPeer,
                icon: const Icon(Icons.add),
                label: const Text('Add Peer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard() {
    return Card(
      color: _isError
          ? const Color(0xFF3E1E1E)
          : const Color(0xFF1E3E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isError ? Icons.error_outline : Icons.check_circle_outline,
              color: _isError ? Colors.redAccent : Colors.greenAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPeers() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _show('Please enter agent password first', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final state = await LumosApi.getPolicyState(
        widget.device.address,
        password: password,
      );

      if (state == null) {
        _show('Failed to load peers. Check password.', isError: true);
        return;
      }

      setState(() {
        _peers = state.peers;
        _loading = false;
      });
    } catch (e) {
      _show('Error loading peers: $e', isError: true);
    }
  }

  Future<void> _addPeer() async {
    final password = _passwordController.text.trim();
    final peerId = _peerIdController.text.trim();
    final peerAddress = _peerAddressController.text.trim();
    final peerPassword = _peerPasswordController.text.trim();

    if (password.isEmpty) {
      _show('Please enter agent password', isError: true);
      return;
    }

    if (peerId.isEmpty || peerAddress.isEmpty) {
      _show('Peer ID and address are required', isError: true);
      return;
    }

    if (peerPassword.isEmpty) {
      _show('Peer password is required for verification', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await LumosApi.upsertPeer(
        widget.device.address,
        password: password,
        peerId: peerId,
        peerAddress: peerAddress,
        peerPassword: peerPassword,
        autoHandshake: _joinHive, // Pass join hive flag
      );

      if (result.ok) {
        final successMsg = _joinHive 
            ? 'Peer joined hive successfully (cluster key synced)'
            : 'Peer added successfully';
        _show(successMsg);
        _peerIdController.clear();
        _peerAddressController.clear();
        _peerPasswordController.clear();
        setState(() {
          _joinHive = false; // Reset toggle
        });
        await _loadPeers();
      } else {
        _show(
          result.readableMessage('Failed to add peer'),
          isError: true,
        );
      }
    } catch (e) {
      _show('Error adding peer: $e', isError: true);
    }
  }

  Future<void> _deletePeer(String peerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Peer'),
        content: Text('Remove peer "$peerId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _show('Please enter agent password', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await LumosApi.deletePeer(
        widget.device.address,
        password: password,
        peerId: peerId,
      );

      if (result.ok) {
        _show('Peer deleted successfully');
        await _loadPeers();
      } else {
        _show(
          result.readableMessage('Failed to delete peer'),
          isError: true,
        );
      }
    } catch (e) {
      _show('Error deleting peer: $e', isError: true);
    }
  }

  void _show(String message, {bool isError = false}) {
    setState(() {
      _message = message;
      _isError = isError;
      _loading = false;
    });
  }
}
