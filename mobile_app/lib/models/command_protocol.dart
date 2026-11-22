/// Canonical Command Protocol Tokens and Helpers
class CommandProtocol {
  // --- BASE COMMAND TOKENS ---
  static const String baseForward = 'F';
  static const String baseBackward = 'B';
  static const String baseLeft = 'L';
  static const String baseRight = 'R';
  static const String baseForwardLeft = 'G';
  static const String baseForwardRight = 'I';
  static const String baseBackLeft = 'H';
  static const String baseBackRight = 'J';
  static const String baseStop = 'S';
  static const String baseBrakeToggle = 'E';

  // --- ARM COMMAND TOKENS ---
  static const String armShoulderUp = 'U';
  static const String armShoulderDown = 'D';
  static const String armWaistLeft = 'L';
  static const String armWaistRight = 'R';
  static const String armTopUp = 'T';
  static const String armTopDown = 't';
  static const String armGripperOpen = 'O';
  static const String armGripperClose = 'C';
  static const String armStop = 'S';

  // --- CONVEYOR COMMAND TOKENS ---
  static const String convResume = 'R';
  static const String convStop = 'S';
  static const String convCalibrate = 'C';
  static const String convQueryStatus = '?';

  // Helper to map 0-255 speed to single-byte token '0'-'9'
  static String speedToToken(int speed) {
    int clamped = speed.clamp(0, 255);
    int step = ((clamped / 255) * 9).round();
    return step.toString();
  }
}
