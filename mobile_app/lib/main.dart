import 'package:flutter/material.dart';
import 'services/bluetooth_service.dart';
import 'services/controller_hub.dart';
import 'theme/industrial_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/robot_base_screen.dart';
import 'screens/robot_arm_screen.dart';
import 'screens/conveyor_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/system_monitor_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bluetoothService = SimulatedBluetoothService();
  final controllerHub = ControllerHub(bluetoothService: bluetoothService);

  runApp(IndustrialAutomationApp(hub: controllerHub));
}

class IndustrialAutomationApp extends StatelessWidget {
  final ControllerHub hub;

  const IndustrialAutomationApp({super.key, required this.hub});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conveyor & Arm Controller',
      debugShowCheckedModeBanner: false,
      theme: IndustrialTheme.themeData,
      home: MainNavigationContainer(hub: hub),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  final ControllerHub hub;

  const MainNavigationContainer({super.key, required this.hub});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) {
        final screens = [
          DashboardScreen(
            hub: widget.hub,
            onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
          ),
          RobotBaseScreen(hub: widget.hub),
          RobotArmScreen(hub: widget.hub),
          ConveyorScreen(hub: widget.hub),
          CameraScreen(hub: widget.hub),
          SystemMonitorScreen(hub: widget.hub),
          SettingsScreen(hub: widget.hub),
        ];

        return Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: IndustrialTheme.surface,
            indicatorColor: IndustrialTheme.cyanAccent.withValues(alpha: 0.2),
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: IndustrialTheme.cyanAccent),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car, color: IndustrialTheme.cyanAccent),
                label: 'Base',
              ),
              NavigationDestination(
                icon: Icon(Icons.precision_manufacturing_outlined),
                selectedIcon: Icon(Icons.precision_manufacturing, color: IndustrialTheme.cyanAccent),
                label: 'Arm',
              ),
              NavigationDestination(
                icon: Icon(Icons.conveyor_belt),
                selectedIcon: Icon(Icons.conveyor_belt, color: IndustrialTheme.cyanAccent),
                label: 'Conveyor',
              ),
              NavigationDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam, color: IndustrialTheme.cyanAccent),
                label: 'Camera',
              ),
              NavigationDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal, color: IndustrialTheme.cyanAccent),
                label: 'Telemetry',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: IndustrialTheme.cyanAccent),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
