import 'package:flutter/material.dart';
import '../models/device_connection.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/connection_badge.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class DashboardScreen extends StatelessWidget {
  final ControllerHub hub;
  final ValueChanged<int> onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.hub,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final baseDev = hub.devices[ControllerType.robotBase]!;
    final armDev = hub.devices[ControllerType.robotArm]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AUTOMATION CELL OVERVIEW'),
        actions: [
          if (hub.isDemoMode)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: IndustrialTheme.cyanAccent.withValues(alpha: 0.15),
                border: Border.all(color: IndustrialTheme.cyanAccent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DEMO / SIM MODE',
                style: TextStyle(
                  color: IndustrialTheme.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Emergency Stop Banner if active
          if (hub.isEmergencyStopped)
            Container(
              color: IndustrialTheme.statusRed,
              padding: const EdgeInsets.all(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'SYSTEM HALTED: EMERGENCY STOP ENGAGED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Subsystem 1: Robotic Base Card
          IndustrialCard(
            title: 'Subsystem 1: Portable Robotic Base',
            icon: Icons.directions_car,
            trailing: ConnectionBadge(
              status: baseDev.status,
              label: 'BASE',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Last Command: ${hub.lastBaseCommand}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Speed: ${hub.baseSpeed} PWM (${((hub.baseSpeed / 255) * 100).round()}%)'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Brake System: ${hub.electronicBraking ? "ENABLED" : "DISABLED"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: hub.electronicBraking ? IndustrialTheme.statusGreen : IndustrialTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.gamepad, size: 16),
                      label: const Text('CONTROL BASE'),
                      onPressed: () => onNavigateToTab(1),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subsystem 2: Robotic Arm Card
          IndustrialCard(
            title: 'Subsystem 2: Portable Robotic Arm',
            icon: Icons.precision_manufacturing,
            trailing: ConnectionBadge(
              status: armDev.status,
              label: 'ARM',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Action: ${hub.lastArmCommand}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Gripper: ${hub.gripperClosed ? "CLOSED" : "OPEN"}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('4-DOF Multi-Motor Articulation', style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary)),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.handyman, size: 16),
                      label: const Text('CONTROL ARM'),
                      onPressed: () => onNavigateToTab(2),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subsystems 3 & 4: Conveyor System Card
          IndustrialCard(
            title: 'Subsystems 3 & 4: Conveyor System',
            icon: Icons.conveyor_belt,
            trailing: const ConnectionBadge(
              status: ConnectionStatus.connected,
              label: 'CONVEYOR',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sorting Belt: ${hub.sortingBeltRunning ? "CRUISING" : "STOPPED"}'),
                    Text('Diverter Angle: ${hub.diverterAngle}°'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Color Optical Stage: ${hub.detectedColor}',
                  style: const TextStyle(color: IndustrialTheme.cyanAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('3-Stage Transfer: Non-blocking FSM', style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary)),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sort, size: 16),
                      label: const Text('VIEW CONVEYORS'),
                      onPressed: () => onNavigateToTab(3),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subsystem 5: Surveillance Camera Card
          IndustrialCard(
            title: 'Subsystem 5: Surveillance Camera',
            icon: Icons.videocam,
            trailing: ConnectionBadge(
              status: hub.cameraService.isConnected ? ConnectionStatus.connected : ConnectionStatus.disconnected,
              label: 'CAMERA',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Feed URL: ${hub.cameraService.streamUrl}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('AI-Thinker ESP32-CAM (OV2640)', style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary)),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.live_tv, size: 16),
                      label: const Text('VIEW STREAM'),
                      onPressed: () => onNavigateToTab(4),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Power and LiPo Safety Reference Card
          IndustrialCard(
            title: 'Battery & Electrical Safety Telemetry',
            icon: Icons.battery_charging_full,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield, color: IndustrialTheme.statusAmber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Orange 3S 11.1V 2200mAh 30C LiPo Pack: Maintain >= 9.9V (3.3V/cell cutoff). Master 10A fuse active.',
                        style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hub.isDemoMode
                      ? 'Simulated Logic Voltage: 5.04V | Battery: 11.8V (Normal)'
                      : 'Physical Hardware Telemetry: Awaiting controller data',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: IndustrialTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: EmergencyStopButton(hub: hub),
    );
  }
}
