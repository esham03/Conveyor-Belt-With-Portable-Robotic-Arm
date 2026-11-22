import 'device_connection.dart';

enum EventSeverity {
  info,
  success,
  warning,
  error,
}

class TelemetryEvent {
  final DateTime timestamp;
  final ControllerType source;
  final String message;
  final String? rawData;
  final EventSeverity severity;

  TelemetryEvent({
    required this.timestamp,
    required this.source,
    required this.message,
    this.rawData,
    this.severity = EventSeverity.info,
  });

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = (timestamp.millisecond ~/ 100).toString();
    return '$h:$m:$s.$ms';
  }
}
