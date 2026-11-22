import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/command_protocol.dart';
import '../models/device_connection.dart';
import '../models/telemetry_event.dart';
import 'bluetooth_service.dart';
import 'camera_service.dart';

class ControllerHub extends ChangeNotifier {
  final BluetoothService bluetoothService;
  final CameraService cameraService = CameraService();

  bool isDemoMode = true; // Enabled by default for flawless testing/review
  bool isEmergencyStopped = false;

  // Connection registry
  final Map<ControllerType, DeviceConnection> devices = {
    ControllerType.robotBase: DeviceConnection(
      type: ControllerType.robotBase,
      name: 'Robotic Base (HC-05 #1)',
      defaultMacAddress: '98:D3:31:F4:12:01',
    ),
    ControllerType.robotArm: DeviceConnection(
      type: ControllerType.robotArm,
      name: 'Robotic Arm (HC-05 #2)',
      defaultMacAddress: '98:D3:31:F4:12:02',
    ),
    ControllerType.conveyorSorting: DeviceConnection(
      type: ControllerType.conveyorSorting,
      name: 'Colour Conveyor',
      defaultMacAddress: 'DIRECT_WIRED',
    ),
    ControllerType.conveyorThreeStage: DeviceConnection(
      type: ControllerType.conveyorThreeStage,
      name: '3-Conveyor System',
      defaultMacAddress: 'DIRECT_WIRED',
    ),
  };

  // Base Subsystem State
  int baseSpeed = 204;
  bool electronicBraking = true;
  String lastBaseCommand = 'S';

  // Arm Subsystem State
  String lastArmCommand = 'S';
  bool gripperClosed = false;

  // Sorting Conveyor State
  bool sortingBeltRunning = true;
  bool sortingIrTriggered = false;
  String detectedColor = 'AWAITING_OBJECT';
  int diverterAngle = 0;

  // 3-Stage Conveyor State
  bool conv1Running = false;
  bool conv2Running = false;
  bool conv3Running = false;

  // Event Logs
  final List<TelemetryEvent> eventLogs = [];
  StreamSubscription? _sub;

  ControllerHub({required this.bluetoothService}) {
    _sub = bluetoothService.eventStream.listen((event) {
      eventLogs.insert(0, event);
      if (eventLogs.length > 200) {
        eventLogs.removeLast();
      }
      notifyListeners();
    });

    // Auto-connect mock devices if in demo mode
    if (isDemoMode) {
      connectDevice(ControllerType.robotBase);
      connectDevice(ControllerType.robotArm);
      connectDevice(ControllerType.conveyorSorting);
      connectDevice(ControllerType.conveyorThreeStage);
    }
  }

  Future<void> connectDevice(ControllerType type) async {
    final dev = devices[type];
    if (dev == null) return;

    dev.status = ConnectionStatus.connecting;
    notifyListeners();

    final success = await bluetoothService.connect(type, dev.defaultMacAddress);
    if (success) {
      dev.status = ConnectionStatus.connected;
      dev.connectedMacAddress = dev.defaultMacAddress;
      dev.lastActive = DateTime.now();
    } else {
      dev.status = ConnectionStatus.error;
      dev.errorMessage = 'Failed to connect to ${dev.name}';
    }
    notifyListeners();
  }

  Future<void> disconnectDevice(ControllerType type) async {
    final dev = devices[type];
    if (dev == null) return;
    await bluetoothService.disconnect(type);
    dev.status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  // --- BASE CONTROL ---
  Future<void> sendBaseCommand(String cmd) async {
    if (isEmergencyStopped && cmd != CommandProtocol.baseStop) {
      return;
    }
    lastBaseCommand = cmd;
    await bluetoothService.sendCommand(ControllerType.robotBase, cmd);
    notifyListeners();
  }

  Future<void> setBaseSpeed(int speed) async {
    baseSpeed = speed.clamp(0, 255);
    final token = CommandProtocol.speedToToken(baseSpeed);
    await bluetoothService.sendCommand(ControllerType.robotBase, token);
    notifyListeners();
  }

  Future<void> toggleElectronicBraking() async {
    electronicBraking = !electronicBraking;
    await bluetoothService.sendCommand(ControllerType.robotBase, CommandProtocol.baseBrakeToggle);
    notifyListeners();
  }

  // --- ARM CONTROL ---
  Future<void> sendArmCommand(String cmd) async {
    if (isEmergencyStopped && cmd != CommandProtocol.armStop) {
      return;
    }
    lastArmCommand = cmd;
    if (cmd == CommandProtocol.armGripperClose) {
      gripperClosed = true;
    } else if (cmd == CommandProtocol.armGripperOpen) {
      gripperClosed = false;
    }
    await bluetoothService.sendCommand(ControllerType.robotArm, cmd);
    notifyListeners();
  }

  // --- CONVEYOR CONTROL ---
  Future<void> sendConveyorCommand(String cmd) async {
    await bluetoothService.sendCommand(ControllerType.conveyorSorting, cmd);
    if (cmd == CommandProtocol.convStop) {
      sortingBeltRunning = false;
    } else if (cmd == CommandProtocol.convResume) {
      sortingBeltRunning = true;
    }
    notifyListeners();
  }

  // --- MASTER EMERGENCY STOP ---
  Future<void> triggerEmergencyStop() async {
    isEmergencyStopped = true;
    lastBaseCommand = CommandProtocol.baseStop;
    lastArmCommand = CommandProtocol.armStop;
    sortingBeltRunning = false;
    conv1Running = false;
    conv2Running = false;
    conv3Running = false;

    // Dispatch STOP across all controllers
    await bluetoothService.sendCommand(ControllerType.robotBase, CommandProtocol.baseStop);
    await bluetoothService.sendCommand(ControllerType.robotArm, CommandProtocol.armStop);
    await bluetoothService.sendCommand(ControllerType.conveyorSorting, CommandProtocol.convStop);

    eventLogs.insert(
      0,
      TelemetryEvent(
        timestamp: DateTime.now(),
        source: ControllerType.robotBase,
        message: '!!! MASTER EMERGENCY STOP ENGAGED - ALL MOTORS HALTED !!!',
        severity: EventSeverity.error,
      ),
    );
    notifyListeners();
  }

  void resetEmergencyStop() {
    isEmergencyStopped = false;
    eventLogs.insert(
      0,
      TelemetryEvent(
        timestamp: DateTime.now(),
        source: ControllerType.robotBase,
        message: 'Emergency Stop Reset: Ready for Resume',
        severity: EventSeverity.warning,
      ),
    );
    notifyListeners();
  }

  void toggleDemoMode(bool value) {
    isDemoMode = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
