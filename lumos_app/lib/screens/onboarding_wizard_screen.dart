import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import 'add_device_screen.dart';
import 'scan_network_screen.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _controller = PageController();
  int _step = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == 2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Wizard'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildStepIndicator(),
          const SizedBox(height: 12),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepCard(
                  title: 'Step 1: Find Agents',
                  description:
                      'Scan your network to discover running Lumos agents.',
                  icon: Icons.radar,
                  actionLabel: 'Open Network Scan',
                  onAction: _openScanAndAdvance,
                ),
                _buildStepCard(
                  title: 'Step 2: Add a Device',
                  description:
                      'Add the discovered device and save its password if you want power controls.',
                  icon: Icons.devices_other,
                  actionLabel: 'Open Add Device',
                  onAction: _openAddDeviceAndAdvance,
                ),
                _buildStepCard(
                  title: 'Step 3: Test Wake/Power',
                  description:
                      'From the home screen, test wake or status refresh to confirm connectivity.',
                  icon: Icons.bolt,
                  actionLabel: 'Finish Setup',
                  onAction: _finishSetup,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: () => _goTo(_step - 1),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                ElevatedButton(
                  onPressed: isLast ? _finishSetup : () => _goTo(_step + 1),
                  child: Text(isLast ? 'Complete' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final active = index == _step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 26 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? Colors.tealAccent : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String description,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: Colors.teal),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishSetup() async {
    await context.read<DeviceProvider>().completeOnboarding();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _openScanAndAdvance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanNetworkScreen(),
      ),
    );
    if (!mounted) return;
    if (_step < 1) {
      _goTo(1);
    }
  }

  Future<void> _openAddDeviceAndAdvance() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDeviceScreen(),
      ),
    );
    if (!mounted) return;
    final hasDevices = context.read<DeviceProvider>().devices.isNotEmpty;
    if (added == true || hasDevices) {
      _goTo(2);
    }
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
    });
    _controller.animateToPage(
      step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}
