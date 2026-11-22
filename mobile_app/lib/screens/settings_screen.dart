import 'package:flutter/material.dart';
import '../models/device_connection.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class SettingsScreen extends StatelessWidget {
  final ControllerHub hub;

  const SettingsScreen({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SYSTEM CONFIGURATION'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Operation Mode Card
          IndustrialCard(
            title: 'Demonstration & Simulation Engine',
            icon: Icons.developer_mode,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Demo / Mock Bridge Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('Simulates HC-05 responses and sensors', style: TextStyle(fontSize: 11, color: IndustrialTheme.textSecondary)),
                  ],
                ),
                Switch(
                  value: hub.isDemoMode,
                  activeTrackColor: IndustrialTheme.cyanAccent,
                  onChanged: (val) => hub.toggleDemoMode(val),
                ),
              ],
            ),
          ),

          // Bluetooth Connection Manager
          IndustrialCard(
            title: 'Bluetooth Classic HC-05 Endpoints',
            icon: Icons.bluetooth,
            child: Column(
              children: [
                _buildBluetoothDeviceRow(
                  context: context,
                  type: ControllerType.robotBase,
                  label: 'Robotic Base Controller',
                  mac: hub.devices[ControllerType.robotBase]!.defaultMacAddress,
                  status: hub.devices[ControllerType.robotBase]!.status,
                  onConnect: () => hub.connectDevice(ControllerType.robotBase),
                  onDisconnect: () => hub.disconnectDevice(ControllerType.robotBase),
                ),
                const Divider(),
                _buildBluetoothDeviceRow(
                  context: context,
                  type: ControllerType.robotArm,
                  label: 'Robotic Arm Controller',
                  mac: hub.devices[ControllerType.robotArm]!.defaultMacAddress,
                  status: hub.devices[ControllerType.robotArm]!.status,
                  onConnect: () => hub.connectDevice(ControllerType.robotArm),
                  onDisconnect: () => hub.disconnectDevice(ControllerType.robotArm),
                ),
              ],
            ),
          ),

          // Android Permissions & Compatibility Guide
          const IndustrialCard(
            title: 'Android Bluetooth Requirements',
            icon: Icons.phonelink_setup,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Bluetooth Classic (SPP / RFCOMM):\n'
                  '   The HC-05 operates on Bluetooth 2.0+EDR. It cannot be paired via BLE scanner.\n\n'
                  '2. Android 12+ (API 31+) Permissions:\n'
                  '   Requires BLUETOOTH_CONNECT and BLUETOOTH_SCAN runtime grants.\n\n'
                  '3. Pairing Passkey:\n'
                  '   Default HC-05 factory PIN is 1234. Pair in Android Settings first before opening app.',
                  style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),

          // Safety Disclaimer
          const IndustrialCard(
            title: 'Safety Interlock Notice',
            icon: Icons.shield,
            child: Text(
              'SOFTWARE EMERGENCY STOP DISCLAIMER:\n'
              'The in-app Emergency Stop sends an electronic halt command to microcontroller firmware. '
              'It is NOT a fail-safe substitute for a physical mechanical power cutoff switch or battery fuse. '
              'Always maintain access to the main battery isolation switch during physical operation.',
              style: TextStyle(fontSize: 11, color: IndustrialTheme.statusAmber, height: 1.4),
            ),
          ),
        ],
      ),
      bottomNavigationBar: EmergencyStopButton(hub: hub),
    );
  }

  Widget _buildBluetoothDeviceRow({
    required BuildContext context,
    required ControllerType type,
    required String label,
    required String mac,
    required ConnectionStatus status,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    final isConnected = (status == ConnectionStatus.connected);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(mac, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: IndustrialTheme.textMuted)),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isConnected ? IndustrialTheme.statusRed.withValues(alpha: 0.15) : IndustrialTheme.surfaceElevated,
              foregroundColor: isConnected ? IndustrialTheme.statusRed : IndustrialTheme.cyanAccent,
            ),
            onPressed: isConnected ? onDisconnect : onConnect,
            child: Text(isConnected ? 'DISCONNECT' : 'CONNECT'),
          ),
        ],
      ),
    );
  }
}
