import 'package:flutter/material.dart';
import '../models/telemetry_event.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class SystemMonitorScreen extends StatelessWidget {
  final ControllerHub hub;

  const SystemMonitorScreen({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SYSTEM TELEMETRY & LOG'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Log',
            onPressed: () {
              hub.eventLogs.clear();
              (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Telemetry Stats Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildStatPill('PACKETS LOGGED', '${hub.eventLogs.length}'),
                const SizedBox(width: 8),
                _buildStatPill('BASE LINK', hub.devices.values.first.status.name.toUpperCase()),
                const SizedBox(width: 8),
                _buildStatPill('E-STOP', hub.isEmergencyStopped ? 'ENGAGED' : 'CLEAR'),
              ],
            ),
          ),

          // Terminal Console Log
          Expanded(
            child: IndustrialCard(
              title: 'Serial Telemetry Console (9600-8-N-1)',
              icon: Icons.terminal,
              child: hub.eventLogs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No telemetry frames recorded yet. Transmit commands to observe serial traffic.',
                          style: TextStyle(color: IndustrialTheme.textMuted, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: hub.eventLogs.length,
                      itemBuilder: (ctx, idx) {
                        final event = hub.eventLogs[idx];
                        return _buildLogLine(event);
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: EmergencyStopButton(hub: hub),
    );
  }

  Widget _buildStatPill(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: IndustrialTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IndustrialTheme.border),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 9, color: IndustrialTheme.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: IndustrialTheme.cyanAccent)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLine(TelemetryEvent event) {
    Color col;
    switch (event.severity) {
      case EventSeverity.success:
        col = IndustrialTheme.statusGreen;
        break;
      case EventSeverity.warning:
        col = IndustrialTheme.statusAmber;
        break;
      case EventSeverity.error:
        col = IndustrialTheme.statusRed;
        break;
      case EventSeverity.info:
        col = IndustrialTheme.textPrimary;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[${event.timeFormatted}] ',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: IndustrialTheme.textMuted),
          ),
          Text(
            '<${event.source.name}> ',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: IndustrialTheme.cyanDim),
          ),
          Expanded(
            child: Text(
              event.message,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: col),
            ),
          ),
        ],
      ),
    );
  }
}
