enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

enum ControllerType {
  robotBase,
  robotArm,
  conveyorSorting,
  conveyorThreeStage,
}

class DeviceConnection {
  final ControllerType type;
  final String name;
  final String defaultMacAddress;
  ConnectionStatus status;
  String? connectedMacAddress;
  String? errorMessage;
  DateTime? lastActive;

  DeviceConnection({
    required this.type,
    required this.name,
    required this.defaultMacAddress,
    this.status = ConnectionStatus.disconnected,
    this.connectedMacAddress,
    this.errorMessage,
    this.lastActive,
  });

  bool get isConnected => status == ConnectionStatus.connected;
}
