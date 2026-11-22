import 'package:flutter/material.dart';
import '../services/controller_hub.dart';
import '../theme/industrial_theme.dart';
import '../widgets/emergency_stop_button.dart';
import '../widgets/industrial_card.dart';

class CameraScreen extends StatefulWidget {
  final ControllerHub hub;

  const CameraScreen({super.key, required this.hub});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late TextEditingController _urlController;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.hub.cameraService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _probeCamera() async {
    setState(() => _isChecking = true);
    widget.hub.cameraService.baseUrl = _urlController.text.trim();
    await widget.hub.cameraService.probeCamera();
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.hub.cameraService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32-CAM SURVEILLANCE'),
        actions: [
          IconButton(
            icon: Icon(camera.isFlashOn ? Icons.flash_on : Icons.flash_off),
            color: camera.isFlashOn ? IndustrialTheme.statusAmber : IndustrialTheme.textMuted,
            tooltip: 'Toggle Flash Illuminator',
            onPressed: () async {
              await camera.toggleFlash();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reconnect Stream',
            onPressed: _probeCamera,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Stream Viewport Card
          IndustrialCard(
            title: 'Optical Surveillance Viewport',
            icon: Icons.videocam,
            trailing: Text(
              camera.isConnected ? 'STREAM ONLINE' : (widget.hub.isDemoMode ? 'SIMULATED FEED' : 'OFFLINE'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: (camera.isConnected || widget.hub.isDemoMode)
                    ? IndustrialTheme.statusGreen
                    : IndustrialTheme.statusRed,
              ),
            ),
            child: Column(
              children: [
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: IndustrialTheme.border),
                  ),
                  child: Stack(
                    children: [
                      // Viewport Canvas Background
                      Center(
                        child: widget.hub.isDemoMode
                            ? _buildSimulatedCameraFeed()
                            : (camera.isConnected
                                ? Image.network(
                                    camera.snapshotUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) => _buildErrorPlaceholder(),
                                  )
                                : _buildErrorPlaceholder()),
                      ),

                      // HUD Overlay
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: Colors.black.withValues(alpha: 0.6),
                          child: const Text(
                            'REC [LIVE] • 25 FPS • QVGA',
                            style: TextStyle(color: IndustrialTheme.statusRed, fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: Colors.black.withValues(alpha: 0.6),
                          child: Text(
                            'OV2640 • ${DateTime.now().toIso8601String().substring(11, 19)}',
                            style: const TextStyle(color: IndustrialTheme.cyanAccent, fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Camera URL Config
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          labelText: 'ESP32-CAM Base URL',
                          labelStyle: TextStyle(fontSize: 12),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isChecking ? null : _probeCamera,
                      child: _isChecking
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('CONNECT'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stream Health and Network Diagnostics
          const IndustrialCard(
            title: 'Wireless Camera Diagnostics',
            icon: Icons.network_check,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Default AP Network:', style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary)),
                    Text('ESP32-CAM-ROBOT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Default AP Static IP:', style: TextStyle(fontSize: 12, color: IndustrialTheme.textSecondary)),
                    Text('192.168.4.1 (Port 81 Stream)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Power Stability Warning: Ensure ESP32-CAM receives 5V >= 2A from an independent buck converter to avoid radio brownouts.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: IndustrialTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: EmergencyStopButton(hub: widget.hub),
    );
  }

  Widget _buildSimulatedCameraFeed() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt, color: IndustrialTheme.cyanAccent, size: 48),
        const SizedBox(height: 8),
        const Text(
          '[CONVEYOR INSPECTION CHAMBER]',
          style: TextStyle(color: IndustrialTheme.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Target Object In Frame: ${widget.hub.detectedColor}',
          style: const TextStyle(color: IndustrialTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildErrorPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam_off, color: IndustrialTheme.statusRed, size: 40),
        const SizedBox(height: 8),
        const Text('CAMERA STREAM DISCONNECTED', style: TextStyle(color: IndustrialTheme.statusRed, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          'Verify ESP32-CAM is powered at ${widget.hub.cameraService.baseUrl}',
          style: const TextStyle(color: IndustrialTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
