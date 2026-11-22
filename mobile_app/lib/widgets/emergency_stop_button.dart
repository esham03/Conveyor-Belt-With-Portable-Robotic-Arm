import 'package:flutter/material.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';

class EmergencyStopButton extends StatelessWidget {
  final ControllerHub hub;

  const EmergencyStopButton({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    final isStopped = hub.isEmergencyStopped;

    return Container(
      margin: const EdgeInsets.all(12),
      child: Material(
        color: isStopped ? IndustrialTheme.statusAmber : IndustrialTheme.statusRed,
        borderRadius: BorderRadius.circular(32),
        elevation: 8,
        shadowColor: isStopped
            ? IndustrialTheme.statusAmber.withValues(alpha: 0.5)
            : IndustrialTheme.statusRed.withValues(alpha: 0.6),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            if (isStopped) {
              hub.resetEmergencyStop();
            } else {
              hub.triggerEmergencyStop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isStopped ? Icons.restart_alt : Icons.dangerous,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isStopped ? 'RESET E-STOP' : 'EMERGENCY STOP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
