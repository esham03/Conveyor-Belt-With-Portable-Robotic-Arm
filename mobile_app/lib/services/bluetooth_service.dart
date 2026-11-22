import 'dart:async';
import '../models/device_connection.dart';
import '../models/telemetry_event.dart';

abstract class BluetoothService {
  Stream<TelemetryEvent> get eventStream;
  Future<bool> connect(ControllerType type, String address);
  Future<void> disconnect(ControllerType type);
  Future<bool> sendCommand(ControllerType type, String command);
  bool isConnected(ControllerType type);
}

class SimulatedBluetoothService implements BluetoothService {
  final _eventController = StreamController<TelemetryEvent>.broadcast();
  final Map<ControllerType, bool> _connectionStates = {
    ControllerType.robotBase: false,
    ControllerType.robotArm: false,
    ControllerType.conveyorSorting: false,
    ControllerType.conveyorThreeStage: false,
  };

  @override
  Stream<TelemetryEvent> get eventStream => _eventController.stream;

  @override
  bool isConnected(ControllerType type) => _connectionStates[type] ?? false;

  @override
  Future<bool> connect(ControllerType type, String address) async {
    // Simulate brief handshake
    await Future.delayed(const Duration(milliseconds: 600));
    _connectionStates[type] = true;

    _eventController.add(
      TelemetryEvent(
        timestamp: DateTime.now(),
        source: type,
        message: 'Connected to ${type.name} at $address (Mock Bridge)',
        severity: EventSeverity.success,
      ),
    );
    return true;
  }

  @override
  Future<void> disconnect(ControllerType type) async {
    _connectionStates[type] = false;
    _eventController.add(
      TelemetryEvent(
        timestamp: DateTime.now(),
        source: type,
        message: 'Disconnected from ${type.name}',
        severity: EventSeverity.warning,
      ),
    );
  }

  @override
  Future<bool> sendCommand(ControllerType type, String command) async {
    if (!isConnected(type)) {
      _eventController.add(
        TelemetryEvent(
          timestamp: DateTime.now(),
          source: type,
          message: 'Failed to send "$command": Controller not connected',
          severity: EventSeverity.error,
        ),
      );
      return false;
    }

    _eventController.add(
      TelemetryEvent(
        timestamp: DateTime.now(),
        source: type,
        message: 'TX -> $command',
        rawData: command,
        severity: EventSeverity.info,
      ),
    );

    // Simulate controller acknowledgement
    Future.delayed(const Duration(milliseconds: 40), () {
      String ack = 'ACK:$command';
      if (type == ControllerType.robotBase) {
        if (command == 'F') ack = 'ACK:FORWARD';
        if (command == 'B') ack = 'ACK:BACKWARD';
        if (command == 'L') ack = 'ACK:LEFT';
        if (command == 'R') ack = 'ACK:RIGHT';
        if (command == 'S') ack = 'ACK:STOP,BRAKE:ON';
      } else if (type == ControllerType.robotArm) {
        if (command == 'U') ack = 'ACK:ARM_UP';
        if (command == 'D') ack = 'ACK:ARM_DOWN';
        if (command == 'L') ack = 'ACK:ARM_LEFT';
        if (command == 'R') ack = 'ACK:ARM_RIGHT';
        if (command == 'T') ack = 'ACK:ARM_TOP_UP';
        if (command == 't') ack = 'ACK:ARM_TOP_DOWN';
        if (command == 'O') ack = 'ACK:GRIPPER_OPEN';
        if (command == 'C') ack = 'ACK:GRIPPER_CLOSE';
        if (command == 'S') ack = 'ACK:ARM_STOP';
      }

      _eventController.add(
        TelemetryEvent(
          timestamp: DateTime.now(),
          source: type,
          message: 'RX <- $ack',
          rawData: ack,
          severity: EventSeverity.success,
        ),
      );
    });

    return true;
  }

  void dispose() {
    _eventController.close();
  }
}
