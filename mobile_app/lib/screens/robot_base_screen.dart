import 'package:flutter/material.dart';
import '../models/command_protocol.dart';
import '../models/device_connection.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/connection_badge.dart';
import '../widgets/directional_pad.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class RobotBaseScreen extends StatelessWidget {
  final ControllerHub hub;

  const RobotBaseScreen({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    final dev = hub.devices[ControllerType.robotBase]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PORTABLE ROBOTIC BASE'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConnectionBadge(status: dev.status, label: 'BASE'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Directional Control Console
          IndustrialCard(
            title: 'Directional Motion Control',
            icon: Icons.gamepad,
            child: Column(
              children: [
                DirectionalPad(
                  activeCommand: hub.lastBaseCommand,
                  onCommand: (cmd) => hub.sendBaseCommand(cmd),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: IndustrialTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: IndustrialTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ACTIVE MOTION STATE:', style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary)),
                      Text(
                        _describeMotion(hub.lastBaseCommand),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: IndustrialTheme.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Speed Modulation Console
          IndustrialCard(
            title: 'Velocity & Motor PWM Modulation',
            icon: Icons.speed,
            trailing: Text(
              '${hub.baseSpeed} / 255',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: IndustrialTheme.cyanAccent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: hub.baseSpeed.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label: '${hub.baseSpeed}',
                  onChanged: (val) {
                    hub.setBaseSpeed(val.round());
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0% (Stop)', style: TextStyle(fontSize: 11, color: IndustrialTheme.textMuted)),
                    Text(
                      '${((hub.baseSpeed / 255) * 100).round()}% DUTY CYCLE',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: IndustrialTheme.textSecondary),
                    ),
                    const Text('100% (255)', style: TextStyle(fontSize: 11, color: IndustrialTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),

          // Braking & Safety Architecture
          IndustrialCard(
            title: 'Electronic Braking System',
            icon: Icons.offline_bolt,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Dynamic Braking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('PULSES H-BRIDGE (45ms) ON STOP', style: TextStyle(fontSize: 11, color: IndustrialTheme.textSecondary)),
                  ],
                ),
                Switch(
                  value: hub.electronicBraking,
                  activeTrackColor: IndustrialTheme.cyanAccent,
                  onChanged: (_) => hub.toggleElectronicBraking(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: EmergencyStopButton(hub: hub),
    );
  }

  String _describeMotion(String cmd) {
    switch (cmd) {
      case CommandProtocol.baseForward: return 'DRIVING FORWARD';
      case CommandProtocol.baseBackward: return 'DRIVING BACKWARD';
      case CommandProtocol.baseLeft: return 'PIVOTING LEFT';
      case CommandProtocol.baseRight: return 'PIVOTING RIGHT';
      case CommandProtocol.baseForwardLeft: return 'STEERING FORWARD-LEFT';
      case CommandProtocol.baseForwardRight: return 'STEERING FORWARD-RIGHT';
      case CommandProtocol.baseBackLeft: return 'STEERING BACK-LEFT';
      case CommandProtocol.baseBackRight: return 'STEERING BACK-RIGHT';
      case CommandProtocol.baseStop: return 'HALTED / BRAKED';
      default: return 'IDLE';
    }
  }
}
