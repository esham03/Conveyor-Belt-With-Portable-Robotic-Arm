/**
 * @file robotic_arm.ino
 * @brief Subsystem 2: Portable Robotic Arm Firmware
 * @project Conveyor Belt with Portable Robotic Arm
 * @reference Government Polytechnic Panaji (Diploma Report 2024, Ch 4, pp. 45-47)
 * 
 * Hardware Architecture:
 * - Microcontroller: Arduino Uno R3 (ATmega328P)
 * - Motor Shield: Adafruit L293D Motor Driver Shield v1 (74HC595 + Dual L293D)
 * - Joint Actuators:
 *   - M1: 30 RPM 12V Centre Shaft DC Gear Motor (Turret Base Rotation - Left/Right)
 *   - M2: 10 RPM 12V High-Torque DC Gear Motor (Shoulder Joint - Up/Down)
 *   - M3: 10 RPM 12V High-Torque DC Gear Motor (Elbow/Wrist Joint - Top Up/Top Down)
 *   - M4: Gripper Actuator (Configurable: DC Motor on M4 or MG946R Servo on Servo1/Pin 10)
 * - Telemetry Link: HC-05 Bluetooth Classic Module (UART @ 9600-8-N-1 on Pins 0/1)
 * 
 * Engineered Resolutions:
 * 1. Resolved syntax bugs: invalid function names containing spaces ('top up', 'top down')
 *    corrected to standard identifiers ('armTopUp', 'armTopDown').
 * 2. Resolved protocol bug: multi-character character constant ('TU', 'TD') evaluated
 *    against single-byte Serial.read() corrected to dedicated single-byte ASCII tokens
 *    ('T' = Top Up, 't' = Top Down) with backward-compatible multi-character string parsing.
 * 3. Resolved M4 ambiguity: Configurable via ARM_GRIPPER_IS_SERVO flag.
 * 4. Safety Watchdog: Automatic joint de-energization if no keep-alive received within 3000ms.
 */

#include <Arduino.h>
#include <AFMotor.h>
#include <Servo.h>

// --- CONFIGURATION FLAGS ---
// Set to true if physical build uses MG946R servo on Servo 1 (Pin 10) per Chapter 2;
// Set to false if physical build uses DC geared motor on M4 per Chapter 4 code.
#define ARM_GRIPPER_IS_SERVO false

// --- PIN DEFINITIONS ---
const uint8_t PIN_SERVO_GRIPPER = 10; // Standard Servo 1 header on Adafruit L293D shield

// --- CONSTANTS ---
const uint32_t SERIAL_BAUD = 9600;
const uint32_t JOINT_TIMEOUT_MS = 3000; // Automatic motor cut-off watchdog
const uint8_t SERVO_GRIPPER_OPEN = 120;
const uint8_t SERVO_GRIPPER_CLOSE = 35;

// --- HARDWARE OBJECT INSTANTIATION ---
AF_DCMotor motorWaist(1, MOTOR12_1KHZ);     // M1: Base / Waist Rotation
AF_DCMotor motorShoulder(2, MOTOR12_1KHZ);  // M2: Shoulder Elevation
AF_DCMotor motorElbow(3, MOTOR34_1KHZ);     // M3: Elbow / Wrist Pitch
#if !ARM_GRIPPER_IS_SERVO
AF_DCMotor motorGripper(4, MOTOR34_1KHZ);   // M4: DC Motor Gripper
#else
Servo servoGripper;                         // MG946R Servo Gripper
#endif

// --- OPERATIONAL VARIABLES ---
uint8_t masterSpeed = 255;                  // Default maximum velocity (0-255)
char currentJointAction = 'S';
uint32_t actionStartTime = 0;
char cmdBuffer[16];
uint8_t cmdBufferIndex = 0;

// --- FORWARD DECLARATIONS ---
void armHaltAll();
void armShoulderUp();
void armShoulderDown();
void armWaistLeft();
void armWaistRight();
void armTopUp();
void armTopDown();
void armGripperOpen();
void armGripperClose();
void processCommandToken(char token);
void processStringCommand(const char* cmd);

void setup() {
  Serial.begin(SERIAL_BAUD);
  while (!Serial && millis() < 1000) {
    // Wait for serial ready
  }

  // Set motor speeds
  motorWaist.setSpeed(masterSpeed);
  motorShoulder.setSpeed(masterSpeed);
  motorElbow.setSpeed(masterSpeed);

#if !ARM_GRIPPER_IS_SERVO
  motorGripper.setSpeed(masterSpeed);
#else
  servoGripper.attach(PIN_SERVO_GRIPPER);
  servoGripper.write(SERVO_GRIPPER_OPEN);
#endif

  // Safe Boot: Ensure all H-bridge channels start de-energized
  armHaltAll();

  Serial.println(F("[ARM] FIRMWARE INITIALIZED: SAFE_BOOT_ACTIVE"));
  Serial.print(F("[ARM] GRIPPER_MODE: "));
#if ARM_GRIPPER_IS_SERVO
  Serial.println(F("SERVO_MG946R_PIN10"));
#else
  Serial.println(F("DC_MOTOR_PORT_M4"));
#endif
  Serial.println(F("[ARM] READY FOR BLUETOOTH COMMANDS"));
}

void loop() {
  // Read incoming serial bytes
  while (Serial.available() > 0) {
    char c = (char)Serial.read();

    if (c == '\r') {
      continue; // Skip carriage returns
    }

    if (c == '\n') {
      // Process buffered framed command
      if (cmdBufferIndex > 0) {
        cmdBuffer[cmdBufferIndex] = '\0';
        processStringCommand(cmdBuffer);
        cmdBufferIndex = 0;
      }
    } else {
      // Store in buffer for multi-char parsing
      if (cmdBufferIndex < sizeof(cmdBuffer) - 1) {
        cmdBuffer[cmdBufferIndex++] = c;
      }

      // Also process immediately as single-character token for zero latency
      processCommandToken(c);
    }
  }

  // Safety Watchdog: Auto-halt active joints after timeout to prevent motor burnout
  if (currentJointAction != 'S' && (millis() - actionStartTime > JOINT_TIMEOUT_MS)) {
    Serial.println(F("[ARM] WARN: MOTION_TIMEOUT -> AUTO_HALT"));
    armHaltAll();
    currentJointAction = 'S';
  }
}

/**
 * @brief Decode single-character command tokens
 */
void processCommandToken(char token) {
  switch (token) {
    case 'U': // Shoulder Elevation Up
    case 'u':
      armShoulderUp();
      currentJointAction = 'U';
      actionStartTime = millis();
      Serial.println(F("ACK:ARM_UP"));
      break;

    case 'D': // Shoulder Elevation Down
    case 'd':
      armShoulderDown();
      currentJointAction = 'D';
      actionStartTime = millis();
      Serial.println(F("ACK:ARM_DOWN"));
      break;

    case 'L': // Turret Base Rotate Left
    case 'l':
      armWaistLeft();
      currentJointAction = 'L';
      actionStartTime = millis();
      Serial.println(F("ACK:ARM_LEFT"));
      break;

    case 'R': // Turret Base Rotate Right
    case 'r':
      armWaistRight();
      currentJointAction = 'R';
      actionStartTime = millis();
      Serial.println(F("ACK:ARM_RIGHT"));
      break;

    case 'T': // Elbow / Wrist Top Up
      armTopUp();
      currentJointAction = 'T';
      actionStartTime = millis();
      Serial.println(F("ACK:ARM_TOP_UP"));
      break;

    case 't': // Elbow / Wrist Top Down
      armTopDown();
      currentJointAction = 't';
      actionStartTime = millis();
      Serial.println(F("ACK:ARM_TOP_DOWN"));
      break;

    case 'O': // Gripper Open
    case 'o':
      armGripperOpen();
      currentJointAction = 'O';
      actionStartTime = millis();
      Serial.println(F("ACK:GRIPPER_OPEN"));
      break;

    case 'C': // Gripper Close
    case 'c':
      armGripperClose();
      currentJointAction = 'C';
      actionStartTime = millis();
      Serial.println(F("ACK:GRIPPER_CLOSE"));
      break;

    case 'S': // Master Arm Halt
    case 's':
      armHaltAll();
      currentJointAction = 'S';
      Serial.println(F("ACK:ARM_STOP"));
      break;

    case '?': // Query status
      Serial.print(F("STA:ARM,ACTION:"));
      Serial.print(currentJointAction);
      Serial.print(F(",SPEED:"));
      Serial.println(masterSpeed);
      break;

    default:
      // Unknown single character; may be part of multi-byte string
      break;
  }
}

/**
 * @brief Parse multi-byte commands for backward compatibility with report strings
 */
void processStringCommand(const char* cmd) {
  if (strcmp(cmd, "TU") == 0) {
    armTopUp();
    currentJointAction = 'T';
    actionStartTime = millis();
    Serial.println(F("ACK:ARM_TOP_UP_STR"));
  } else if (strcmp(cmd, "TD") == 0) {
    armTopDown();
    currentJointAction = 't';
    actionStartTime = millis();
    Serial.println(F("ACK:ARM_TOP_DOWN_STR"));
  } else if (strncmp(cmd, "SPD:", 4) == 0) {
    int spd = atoi(cmd + 4);
    if (spd >= 0 && spd <= 255) {
      masterSpeed = (uint8_t)spd;
      motorWaist.setSpeed(masterSpeed);
      motorShoulder.setSpeed(masterSpeed);
      motorElbow.setSpeed(masterSpeed);
#if !ARM_GRIPPER_IS_SERVO
      motorGripper.setSpeed(masterSpeed);
#endif
      Serial.print(F("ACK:ARM_SPEED_SET:"));
      Serial.println(masterSpeed);
    }
  }
}

// --- JOINT CONTROL IMPLEMENTATIONS ---

void armShoulderUp() {
  motorShoulder.setSpeed(masterSpeed);
  motorShoulder.run(FORWARD);
}

void armShoulderDown() {
  motorShoulder.setSpeed(masterSpeed);
  motorShoulder.run(BACKWARD);
}

void armWaistLeft() {
  motorWaist.setSpeed(masterSpeed);
  motorWaist.run(BACKWARD);
}

void armWaistRight() {
  motorWaist.setSpeed(masterSpeed);
  motorWaist.run(FORWARD);
}

void armTopUp() {
  // Moderate speed for delicate wrist/elbow positioning (approx 30% duty cycle)
  motorElbow.setSpeed((uint8_t)(masterSpeed / 3.1f));
  motorElbow.run(FORWARD);
}

void armTopDown() {
  motorElbow.setSpeed(masterSpeed);
  motorElbow.run(BACKWARD);
}

void armGripperOpen() {
#if !ARM_GRIPPER_IS_SERVO
  motorGripper.setSpeed((uint8_t)(masterSpeed / 3.1f));
  motorGripper.run(FORWARD);
#else
  servoGripper.write(SERVO_GRIPPER_OPEN);
#endif
}

void armGripperClose() {
#if !ARM_GRIPPER_IS_SERVO
  motorGripper.setSpeed(masterSpeed);
  motorGripper.run(BACKWARD);
#else
  servoGripper.write(SERVO_GRIPPER_CLOSE);
#endif
}

void armHaltAll() {
  motorWaist.run(RELEASE);
  motorShoulder.run(RELEASE);
  motorElbow.run(RELEASE);
#if !ARM_GRIPPER_IS_SERVO
  motorGripper.run(RELEASE);
#endif
}
