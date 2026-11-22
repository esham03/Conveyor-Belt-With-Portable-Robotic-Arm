import 'package:flutter/material.dart';
import '../models/command_protocol.dart';
import '../theme/industrial_theme.dart';

class DirectionalPad extends StatelessWidget {
  final String activeCommand;
  final ValueChanged<String> onCommand;

  const DirectionalPad({
    super.key,
    required this.activeCommand,
    required this.onCommand,
  });

  Widget _buildPadButton({
    required String label,
    required IconData icon,
    required String command,
    bool isStop = false,
  }) {
    final isActive = (activeCommand == command);

    Color bgColor = isStop
        ? IndustrialTheme.statusRed.withValues(alpha: 0.25)
        : (isActive ? IndustrialTheme.cyanAccent.withValues(alpha: 0.3) : IndustrialTheme.surfaceElevated);

    Color fgColor = isStop
        ? IndustrialTheme.statusRed
        : (isActive ? IndustrialTheme.cyanAccent : IndustrialTheme.textPrimary);

    Color borderColor = isStop
        ? IndustrialTheme.statusRed
        : (isActive ? IndustrialTheme.cyanAccent : IndustrialTheme.border);

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isActive ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onCommand(command),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: isStop ? 28 : 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPadButton(label: 'FWD-L', icon: Icons.north_west, command: CommandProtocol.baseForwardLeft),
            const SizedBox(width: 8),
            _buildPadButton(label: 'FORWARD', icon: Icons.arrow_upward, command: CommandProtocol.baseForward),
            const SizedBox(width: 8),
            _buildPadButton(label: 'FWD-R', icon: Icons.north_east, command: CommandProtocol.baseForwardRight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPadButton(label: 'LEFT', icon: Icons.arrow_back, command: CommandProtocol.baseLeft),
            const SizedBox(width: 8),
            _buildPadButton(label: 'HALT', icon: Icons.stop_circle, command: CommandProtocol.baseStop, isStop: true),
            const SizedBox(width: 8),
            _buildPadButton(label: 'RIGHT', icon: Icons.arrow_forward, command: CommandProtocol.baseRight),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPadButton(label: 'BCK-L', icon: Icons.south_west, command: CommandProtocol.baseBackLeft),
            const SizedBox(width: 8),
            _buildPadButton(label: 'BACK', icon: Icons.arrow_downward, command: CommandProtocol.baseBackward),
            const SizedBox(width: 8),
            _buildPadButton(label: 'BCK-R', icon: Icons.south_east, command: CommandProtocol.baseBackRight),
          ],
        ),
      ],
    );
  }
}
