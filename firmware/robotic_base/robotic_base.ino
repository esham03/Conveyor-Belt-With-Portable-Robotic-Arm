/**
 * @file robotic_base.ino
 * @brief Subsystem 1: Portable Robotic Base Firmware
 * @project Conveyor Belt with Portable Robotic Arm
 * @reference Government Polytechnic Panaji (Diploma Report 2024, Ch 4, pp. 41-44)
 * 
 * Hardware Architecture:
 * - Microcontroller: Arduino Uno R3 (ATmega328P)
 * - Motor Driver: L298N Dual H-Bridge Module
 * - Actuators: 4x 100 RPM BO DC Geared Motors (Left pair ganged, Right pair ganged)
 * - Telemetry Link: HC-05 Bluetooth Classic Module (UART @ 9600-8-N-1 on Pins 0/1)
 * 
 * Safety & Interlocks:
 * - Safe Boot: All driver pins driven LOW immediately upon power-up/reset.
 * - Dynamic Electronic Braking: Drives both H-bridge terminals HIGH momentarily (45ms)
 *   to short-circuit the motor back-EMF, providing rapid deceleration.
 * - Non-conflicting pin assignments with PWM velocity modulation.
 */

#include <Arduino.h>

// --- PIN DEFINITIONS ---
// Resolved from report Chapter 2 (p. 24) and Chapter 4 (p. 41)
const uint8_t PIN_BASE_IN1 = 5;   // PWM Output - Motor A Direction 1 (Left Forward)
const uint8_t PIN_BASE_IN2 = 6;   // PWM Output - Motor A Direction 2 (Left Reverse)
const uint8_t PIN_BASE_IN3 = 10;  // PWM Output - Motor B Direction 1 (Right Forward)
const uint8_t PIN_BASE_IN4 = 11;  // PWM Output - Motor B Direction 2 (Right Reverse)

// --- CONFIGURATION PARAMETERS ---
const uint32_t SERIAL_BAUD = 9600;
const uint16_t BRAKE_TIME_MS = 45;
const uint32_t COMMAND_TIMEOUT_MS = 2500; // Auto-stop if no command received (watchdog)

// --- OPERATIONAL VARIABLES ---
uint8_t currentSpeed = 204;       // Default speed (0 - 255, approx 80% duty cycle)
uint8_t turnRadiusSpeed = 70;     // Inner wheel speed for sweeping turns
bool electronicBrakingEnabled = true;
char lastCommand = 'S';
uint32_t lastCommandTimestamp = 0;

// --- FORWARD DECLARATIONS ---
void haltMotors();
void applyElectronicBrake();
void driveForward();
void driveBackward();
void pivotLeft();
void pivotRight();
void steerForwardLeft();
void steerForwardRight();
void steerBackwardLeft();
void steerBackwardRight();
void processCommand(char cmd);

void setup() {
  // 1. Initialize motor driver pins as OUTPUT
  pinMode(PIN_BASE_IN1, OUTPUT);
  pinMode(PIN_BASE_IN2, OUTPUT);
  pinMode(PIN_BASE_IN3, OUTPUT);
  pinMode(PIN_BASE_IN4, OUTPUT);

  // 2. Safe Boot State: Ensure all motor lines are fully de-energized
  haltMotors();

  // 3. Initialize Serial Communication for HC-05 Bluetooth Link
  Serial.begin(SERIAL_BAUD);
  while (!Serial && millis() < 1000) {
    // Brief wait for USB CDC if connected
  }

  // 4. Announce boot status
  Serial.println(F("[BASE] FIRMWARE INITIALIZED: SAFE_BOOT_ACTIVE"));
  Serial.print(F("[BASE] DEFAULT_SPEED: "));
  Serial.println(currentSpeed);
  Serial.println(F("[BASE] READY FOR BLUETOOTH COMMANDS"));
}

void loop() {
  // Check for incoming Bluetooth serial data
  if (Serial.available() > 0) {
    char cmd = Serial.read();

    // Ignore carriage return or newline formatting characters
    if (cmd == '\r' || cmd == '\n' || cmd == ' ') {
      return;
    }

    processCommand(cmd);
    lastCommandTimestamp = millis();
  }

  // Safety Watchdog: If vehicle is moving and no keep-alive/command received in 2500ms, halt
  if (lastCommand != 'S' && (millis() - lastCommandTimestamp > COMMAND_TIMEOUT_MS)) {
    Serial.println(F("[BASE] WARN: WATCHDOG_TIMEOUT -> AUTO_HALT"));
    haltMotors();
    lastCommand = 'S';
  }
}

/**
 * @brief Decode and execute single-character command tokens
 */
void processCommand(char cmd) {
  // Speed Adjustment Tokens ('0' through '9')
  if (cmd >= '0' && cmd <= '9') {
    currentSpeed = map(cmd - '0', 0, 9, 0, 255);
    turnRadiusSpeed = currentSpeed / 3;
    Serial.print(F("ACK:SPEED,VAL:"));
    Serial.println(currentSpeed);
    return;
  }

  switch (cmd) {
    case 'F':
    case 'f':
      driveForward();
      lastCommand = 'F';
      Serial.println(F("ACK:FORWARD"));
      break;

    case 'B':
    case 'b':
      driveBackward();
      lastCommand = 'B';
      Serial.println(F("ACK:BACKWARD"));
      break;

    case 'L':
    case 'l':
      pivotLeft();
      lastCommand = 'L';
      Serial.println(F("ACK:LEFT"));
      break;

    case 'R':
    case 'r':
      pivotRight();
      lastCommand = 'R';
      Serial.println(F("ACK:RIGHT"));
      break;

    case 'G':
    case 'g':
      steerForwardLeft();
      lastCommand = 'G';
      Serial.println(F("ACK:FWD_LEFT"));
      break;

    case 'I':
    case 'i':
      steerForwardRight();
      lastCommand = 'I';
      Serial.println(F("ACK:FWD_RIGHT"));
      break;

    case 'H':
    case 'h':
      steerBackwardLeft();
      lastCommand = 'H';
      Serial.println(F("ACK:BACK_LEFT"));
      break;

    case 'J':
    case 'j':
      steerBackwardRight();
      lastCommand = 'J';
      Serial.println(F("ACK:BACK_RIGHT"));
      break;

    case 'S':
    case 's':
      if (electronicBrakingEnabled && lastCommand != 'S') {
        applyElectronicBrake();
      } else {
        haltMotors();
      }
      lastCommand = 'S';
      Serial.println(F("ACK:STOP"));
      break;

    case 'E': // Toggle Electronic Brake
      electronicBrakingEnabled = !electronicBrakingEnabled;
      Serial.print(F("ACK:BRAKE_SYS,ENABLED:"));
      Serial.println(electronicBrakingEnabled ? 1 : 0);
      break;

    case '?': // Query status
      Serial.print(F("STA:BASE,CMD:"));
      Serial.print(lastCommand);
      Serial.print(F(",SPD:"));
      Serial.println(currentSpeed);
      break;

    default:
      Serial.print(F("ERR:UNKNOWN_CMD,VAL:"));
      Serial.println(cmd);
      break;
  }
}

// --- LOW-LEVEL MOTOR CONTROL PRIMITIVES ---

void driveForward() {
  analogWrite(PIN_BASE_IN1, currentSpeed);
  analogWrite(PIN_BASE_IN2, 0);
  analogWrite(PIN_BASE_IN3, currentSpeed);
  analogWrite(PIN_BASE_IN4, 0);
}

void driveBackward() {
  analogWrite(PIN_BASE_IN1, 0);
  analogWrite(PIN_BASE_IN2, currentSpeed);
  analogWrite(PIN_BASE_IN3, 0);
  analogWrite(PIN_BASE_IN4, currentSpeed);
}

void pivotLeft() {
  analogWrite(PIN_BASE_IN1, 0);
  analogWrite(PIN_BASE_IN2, currentSpeed);
  analogWrite(PIN_BASE_IN3, currentSpeed);
  analogWrite(PIN_BASE_IN4, 0);
}

void pivotRight() {
  analogWrite(PIN_BASE_IN1, currentSpeed);
  analogWrite(PIN_BASE_IN2, 0);
  analogWrite(PIN_BASE_IN3, 0);
  analogWrite(PIN_BASE_IN4, currentSpeed);
}

void steerForwardLeft() {
  analogWrite(PIN_BASE_IN1, turnRadiusSpeed);
  analogWrite(PIN_BASE_IN2, 0);
  analogWrite(PIN_BASE_IN3, currentSpeed);
  analogWrite(PIN_BASE_IN4, 0);
}

void steerForwardRight() {
  analogWrite(PIN_BASE_IN1, currentSpeed);
  analogWrite(PIN_BASE_IN2, 0);
  analogWrite(PIN_BASE_IN3, turnRadiusSpeed);
  analogWrite(PIN_BASE_IN4, 0);
}

void steerBackwardLeft() {
  analogWrite(PIN_BASE_IN1, 0);
  analogWrite(PIN_BASE_IN2, turnRadiusSpeed);
  analogWrite(PIN_BASE_IN3, 0);
  analogWrite(PIN_BASE_IN4, currentSpeed);
}

void steerBackwardRight() {
  analogWrite(PIN_BASE_IN1, 0);
  analogWrite(PIN_BASE_IN2, currentSpeed);
  analogWrite(PIN_BASE_IN3, 0);
  analogWrite(PIN_BASE_IN4, turnRadiusSpeed);
}

void haltMotors() {
  analogWrite(PIN_BASE_IN1, 0);
  analogWrite(PIN_BASE_IN2, 0);
  analogWrite(PIN_BASE_IN3, 0);
  analogWrite(PIN_BASE_IN4, 0);
}

void applyElectronicBrake() {
  // Drive both terminals of each H-bridge HIGH simultaneously.
  // This dead-shorts the spinning motor windings through the low-side diodes/MOSFETs,
  // generating immediate electromagnetic braking torque.
  digitalWrite(PIN_BASE_IN1, HIGH);
  digitalWrite(PIN_BASE_IN2, HIGH);
  digitalWrite(PIN_BASE_IN3, HIGH);
  digitalWrite(PIN_BASE_IN4, HIGH);
  delay(BRAKE_TIME_MS);
  haltMotors();
}
