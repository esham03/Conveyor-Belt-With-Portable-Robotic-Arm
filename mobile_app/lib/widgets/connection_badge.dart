import 'package:flutter/material.dart';
import '../models/device_connection.dart';
import '../theme/industrial_theme.dart';

class ConnectionBadge extends StatelessWidget {
  final ConnectionStatus status;
  final String label;

  const ConnectionBadge({
    super.key,
    required this.status,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case ConnectionStatus.connected:
        color = IndustrialTheme.statusGreen;
        icon = Icons.check_circle;
        text = 'ONLINE';
        break;
      case ConnectionStatus.connecting:
        color = IndustrialTheme.statusAmber;
        icon = Icons.sync;
        text = 'CONNECTING';
        break;
      case ConnectionStatus.error:
        color = IndustrialTheme.statusRed;
        icon = Icons.error;
        text = 'ERROR';
        break;
      case ConnectionStatus.disconnected:
        color = IndustrialTheme.textMuted;
        icon = Icons.portable_wifi_off;
        text = 'OFFLINE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: $text',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
