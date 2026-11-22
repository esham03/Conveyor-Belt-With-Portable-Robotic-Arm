import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/bluetooth_service.dart';
import 'package:mobile_app/services/controller_hub.dart';

void main() {
  testWidgets('Industrial Automation App renders and navigates', (WidgetTester tester) async {
    final bluetoothService = SimulatedBluetoothService();
    final hub = ControllerHub(bluetoothService: bluetoothService);

    await tester.pumpWidget(IndustrialAutomationApp(hub: hub));
    await tester.pumpAndSettle();

    // Verify main overview header
    expect(find.text('AUTOMATION CELL OVERVIEW'), findsOneWidget);

    // Verify Emergency Stop button is rendered
    expect(find.text('EMERGENCY STOP'), findsOneWidget);

    // Tap Emergency Stop
    await tester.tap(find.text('EMERGENCY STOP'));
    await tester.pumpAndSettle();

    expect(hub.isEmergencyStopped, isTrue);
    expect(find.text('RESET E-STOP'), findsOneWidget);

    // Reset Emergency Stop
    await tester.tap(find.text('RESET E-STOP'));
    await tester.pumpAndSettle();

    expect(hub.isEmergencyStopped, isFalse);
  });
}
