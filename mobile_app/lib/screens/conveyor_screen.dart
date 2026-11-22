import 'package:flutter/material.dart';
import '../models/command_protocol.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class ConveyorScreen extends StatelessWidget {
  final ControllerHub hub;

  const ConveyorScreen({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONVEYOR SYSTEMS'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Subsystem 3: Colour-Sorting Conveyor
          IndustrialCard(
            title: 'Subsystem 3: Colour-Sorting Conveyor',
            icon: Icons.filter_vintage,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hub.sortingBeltRunning
                    ? IndustrialTheme.statusGreen.withValues(alpha: 0.2)
                    : IndustrialTheme.statusRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hub.sortingBeltRunning ? 'BELT ACTIVE' : 'BELT HALTED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: hub.sortingBeltRunning ? IndustrialTheme.statusGreen : IndustrialTheme.statusRed,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Belt Controls
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('START BELT'),
                      onPressed: () => hub.sendConveyorCommand(CommandProtocol.convResume),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.pause, size: 16),
                      label: const Text('PAUSE BELT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IndustrialTheme.statusAmber.withValues(alpha: 0.2),
                        foregroundColor: IndustrialTheme.statusAmber,
                      ),
                      onPressed: () => hub.sendConveyorCommand(CommandProtocol.convStop),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('CALIBRATE'),
                      onPressed: () => hub.sendConveyorCommand(CommandProtocol.convCalibrate),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // IR & Color Telemetry
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: IndustrialTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: IndustrialTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('IR Proximity Sensor (Pin 7):', style: TextStyle(fontSize: 12)),
                          Text(
                            hub.sortingIrTriggered ? 'OBJECT PRESENT' : 'CLEAR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: hub.sortingIrTriggered ? IndustrialTheme.statusGreen : IndustrialTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TCS3200 Optical Classification:', style: TextStyle(fontSize: 12)),
                          _buildColorBadge(hub.detectedColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('MG946R Diverter Servo (Pin 10):', style: TextStyle(fontSize: 12)),
                          Text(
                            '${hub.diverterAngle}° (${_diverterBinName(hub.diverterAngle)})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: IndustrialTheme.cyanAccent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Subsystem 4: 3-Stage Transfer Conveyor
          IndustrialCard(
            title: 'Subsystem 4: 3-Stage Transfer Conveyor',
            icon: Icons.sync_alt,
            trailing: const Text('NON-BLOCKING FSM', style: TextStyle(fontSize: 11, color: IndustrialTheme.statusGreen)),
            child: Column(
              children: [
                _buildConveyorStageTile(1, 'Stage 1: Infeed Belt', hub.conv1Running, () => hub.sendConveyorCommand('1')),
                const Divider(),
                _buildConveyorStageTile(2, 'Stage 2: Mid-Transfer Belt', hub.conv2Running, () => hub.sendConveyorCommand('2')),
                const Divider(),
                _buildConveyorStageTile(3, 'Stage 3: Outfeed Belt', hub.conv3Running, () => hub.sendConveyorCommand('3')),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: IndustrialTheme.textMuted),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Each conveyor activates for 5.0 seconds upon IR sensor trigger. Timers run concurrently in firmware without blocking.',
                        style: TextStyle(fontSize: 11, color: IndustrialTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: EmergencyStopButton(hub: hub),
    );
  }

  Widget _buildConveyorStageTile(int stage, String title, bool isRunning, VoidCallback onTrigger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isRunning ? Icons.circle : Icons.circle_outlined,
                color: isRunning ? IndustrialTheme.statusGreen : IndustrialTheme.textMuted,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Row(
            children: [
              Text(
                isRunning ? 'RUNNING (5s)' : 'IDLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isRunning ? IndustrialTheme.statusGreen : IndustrialTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.bolt, size: 18),
                tooltip: 'Simulate IR Trigger',
                color: IndustrialTheme.cyanAccent,
                onPressed: onTrigger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorBadge(String colorName) {
    Color col = IndustrialTheme.textMuted;
    if (colorName == 'RED') col = IndustrialTheme.statusRed;
    if (colorName == 'GREEN') col = IndustrialTheme.statusGreen;
    if (colorName == 'BLUE') col = IndustrialTheme.cyanAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.2),
        border: Border.all(color: col),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        colorName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col),
      ),
    );
  }

  String _diverterBinName(int angle) {
    if (angle == 45) return 'Red Chute';
    if (angle == 90) return 'Green Chute';
    if (angle == 135) return 'Blue Chute';
    return 'Neutral Bypass';
  }
}
