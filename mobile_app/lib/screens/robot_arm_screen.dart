import 'package:flutter/material.dart';
import '../models/command_protocol.dart';
import '../models/device_connection.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/connection_badge.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class RobotArmScreen extends StatelessWidget {
  final ControllerHub hub;

  const RobotArmScreen({super.key, required this.hub});

  Widget _buildJointControlRow({
    required BuildContext context,
    required String jointName,
    required String motorSpec,
    required String leftLabel,
    required IconData leftIcon,
    required String leftCmd,
    required String rightLabel,
    required IconData rightIcon,
    required String rightCmd,
  }) {
    final isLeftActive = (hub.lastArmCommand == leftCmd);
    final isRightActive = (hub.lastArmCommand == rightCmd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(jointName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(motorSpec, style: const TextStyle(fontSize: 11, color: IndustrialTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(leftIcon, size: 18),
                label: Text(leftLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLeftActive
                      ? IndustrialTheme.cyanAccent.withValues(alpha: 0.25)
                      : IndustrialTheme.surfaceElevated,
                  foregroundColor: isLeftActive ? IndustrialTheme.cyanAccent : IndustrialTheme.textPrimary,
                  side: BorderSide(
                    color: isLeftActive ? IndustrialTheme.cyanAccent : IndustrialTheme.border,
                  ),
                ),
                onPressed: () => hub.sendArmCommand(leftCmd),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(rightIcon, size: 18),
                label: Text(rightLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRightActive
                      ? IndustrialTheme.cyanAccent.withValues(alpha: 0.25)
                      : IndustrialTheme.surfaceElevated,
                  foregroundColor: isRightActive ? IndustrialTheme.cyanAccent : IndustrialTheme.textPrimary,
                  side: BorderSide(
                    color: isRightActive ? IndustrialTheme.cyanAccent : IndustrialTheme.border,
                  ),
                ),
                onPressed: () => hub.sendArmCommand(rightCmd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dev = hub.devices[ControllerType.robotArm]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PORTABLE ROBOTIC ARM'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ConnectionBadge(status: dev.status, label: 'ARM'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Multi-Joint Articulation Console
          IndustrialCard(
            title: 'Joint Articulation Controls',
            icon: Icons.precision_manufacturing,
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.stop, color: IndustrialTheme.statusRed, size: 16),
              label: const Text('HALT ARM', style: TextStyle(color: IndustrialTheme.statusRed)),
              style: ElevatedButton.styleFrom(
                backgroundColor: IndustrialTheme.statusRed.withValues(alpha: 0.15),
                side: const BorderSide(color: IndustrialTheme.statusRed),
              ),
              onPressed: () => hub.sendArmCommand(CommandProtocol.armStop),
            ),
            child: Column(
              children: [
                // Joint 1: Waist Rotation
                _buildJointControlRow(
                  context: context,
                  jointName: 'Joint 1: Base / Waist Turret (M1)',
                  motorSpec: '30 RPM Centre-Shaft DC',
                  leftLabel: 'ROTATE LEFT',
                  leftIcon: Icons.rotate_left,
                  leftCmd: CommandProtocol.armWaistLeft,
                  rightLabel: 'ROTATE RIGHT',
                  rightIcon: Icons.rotate_right,
                  rightCmd: CommandProtocol.armWaistRight,
                ),

                // Joint 2: Shoulder Elevation
                _buildJointControlRow(
                  context: context,
                  jointName: 'Joint 2: Shoulder Elevation (M2)',
                  motorSpec: '10 RPM High-Torque DC',
                  leftLabel: 'ELEVATE UP',
                  leftIcon: Icons.arrow_upward,
                  leftCmd: CommandProtocol.armShoulderUp,
                  rightLabel: 'LOWER DOWN',
                  rightIcon: Icons.arrow_downward,
                  rightCmd: CommandProtocol.armShoulderDown,
                ),

                // Joint 3: Elbow Pitch
                _buildJointControlRow(
                  context: context,
                  jointName: 'Joint 3: Elbow / Wrist Pitch (M3)',
                  motorSpec: '10 RPM High-Torque DC',
                  leftLabel: 'TOP UP',
                  leftIcon: Icons.keyboard_double_arrow_up,
                  leftCmd: CommandProtocol.armTopUp,
                  rightLabel: 'TOP DOWN',
                  rightIcon: Icons.keyboard_double_arrow_down,
                  rightCmd: CommandProtocol.armTopDown,
                ),

                // End-Effector Gripper
                _buildJointControlRow(
                  context: context,
                  jointName: 'End-Effector: Clamp Gripper (M4/Servo)',
                  motorSpec: 'Dual Mode: DC Motor / MG946R',
                  leftLabel: 'OPEN JAWS',
                  leftIcon: Icons.open_in_full,
                  leftCmd: CommandProtocol.armGripperOpen,
                  rightLabel: 'CLOSE JAWS',
                  rightIcon: Icons.close_fullscreen,
                  rightCmd: CommandProtocol.armGripperClose,
                ),
              ],
            ),
          ),

          // Joint Safety and Interlocks
          IndustrialCard(
            title: 'Safety Interlocks & Protocol Protection',
            icon: Icons.security,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer, color: IndustrialTheme.statusAmber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Watchdog Timeout Active: Any continuous joint movement automatically halts after 3000ms if no keep-alive is received.',
                        style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Arm Action Token: "${hub.lastArmCommand}"',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: IndustrialTheme.cyanAccent),
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
