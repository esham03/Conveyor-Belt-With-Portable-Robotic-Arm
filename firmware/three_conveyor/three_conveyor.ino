/**
 * @file three_conveyor.ino
 * @brief Subsystem 4: 3-Stage Transfer Conveyor Firmware
 * @project Conveyor Belt with Portable Robotic Arm
 * @reference Government Polytechnic Panaji (Diploma Report 2024, Ch 4, pp. 50-51)
 * 
 * Hardware Architecture:
 * - Microcontroller: Arduino Uno R3 (ATmega328P)
 * - Motor Shield: Adafruit L293D Motor Shield v1
 * - Actuators:
 *   - M1: 100 RPM BO DC Motor (Conveyor Belt 1)
 *   - M2: 100 RPM BO DC Motor (Conveyor Belt 2)
 *   - M3: 100 RPM BO DC Motor (Conveyor Belt 3)
 * - Object Sensors: 3x IR Proximity Sensors
 * 
 * Engineered Resolutions:
 * 1. Resolved Pin Collisions with L293D Shield:
 *    Original report connected IR2 to Pin 6 (which is M4 PWM on L293D shield) and
 *    IR3 to Pin 10 (which is Servo 1 line). Rerouted IR sensors to Arduino Uno
 *    Analog pins A0, A1, A2 configured as digital INPUT_PULLUP.
 * 2. Non-Blocking Event-Driven FSM:
 *    Replaced the blocking delay(5000) cascade with non-blocking millis() state tracking.
 *    Each conveyor belt now activates and transports parcels concurrently and independently.
 * 3. Serial Telemetry & Emergency Stop:
 *    Full event reporting and safety halt capabilities.
 */

#include <Arduino.h>
#include <AFMotor.h>

// --- PIN DEFINITIONS ---
// Routed to dedicated Analog pins (addressed as digital inputs)
const uint8_t PIN_IR_CONV1 = A0;  // Conveyor 1 Infeed IR Sensor
const uint8_t PIN_IR_CONV2 = A1;  // Conveyor 2 Mid-Transfer IR Sensor
const uint8_t PIN_IR_CONV3 = A2;  // Conveyor 3 Outfeed IR Sensor

// --- CONFIGURATION CONSTANTS ---
const uint32_t SERIAL_BAUD = 9600;
const uint8_t MOTOR_SPEED_DEFAULT = 250;
const uint32_t CONVEYOR_RUN_DURATION_MS = 5000; // 5.0 seconds transfer cycle per report

// --- MOTOR INSTANTIATION ---
AF_DCMotor motorBelt1(1);  // M1 Terminal
AF_DCMotor motorBelt2(2);  // M2 Terminal
AF_DCMotor motorBelt3(3);  // M3 Terminal

// --- INDEPENDENT CONVEYOR STATE STRUCT ---
struct ConveyorBelt {
  uint8_t id;
  uint8_t sensorPin;
  AF_DCMotor* motor;
  bool isRunning;
  uint32_t startTime;
  bool lastSensorState;
};

ConveyorBelt belts[3] = {
  { 1, PIN_IR_CONV1, &motorBelt1, false, 0, HIGH },
  { 2, PIN_IR_CONV2, &motorBelt2, false, 0, HIGH },
  { 3, PIN_IR_CONV3, &motorBelt3, false, 0, HIGH }
};

// --- FORWARD DECLARATIONS ---
void startBelt(ConveyorBelt &belt);
void stopBelt(ConveyorBelt &belt);
void emergencyStopAll();

void setup() {
  Serial.begin(SERIAL_BAUD);
  while (!Serial && millis() < 1000) {}

  // Initialize IR sensor pins with internal pullups
  pinMode(PIN_IR_CONV1, INPUT_PULLUP);
  pinMode(PIN_IR_CONV2, INPUT_PULLUP);
  pinMode(PIN_IR_CONV3, INPUT_PULLUP);

  // Set initial motor speeds
  motorBelt1.setSpeed(MOTOR_SPEED_DEFAULT);
  motorBelt2.setSpeed(MOTOR_SPEED_DEFAULT);
  motorBelt3.setSpeed(MOTOR_SPEED_DEFAULT);

  // Safe Boot: Ensure all motors start in RELEASE state
  emergencyStopAll();

  Serial.println(F("[3_CONV] FIRMWARE INITIALIZED: NON-BLOCKING FSM ACTIVE"));
  Serial.println(F("[3_CONV] IR SENSORS ON A0, A1, A2 (SHIELD CONFLICTS RESOLVED)"));
  Serial.println(F("[3_CONV] READY FOR OPERATION"));
}

void loop() {
  uint32_t now = millis();

  // Process any incoming serial commands
  if (Serial.available() > 0) {
    char cmd = (char)Serial.read();
    if (cmd == 'S' || cmd == 's') {
      emergencyStopAll();
      Serial.println(F("ACK:3CONV_EMERGENCY_STOP"));
    } else if (cmd == '1') {
      startBelt(belts[0]);
    } else if (cmd == '2') {
      startBelt(belts[1]);
    } else if (cmd == '3') {
      startBelt(belts[2]);
    } else if (cmd == '?') {
      Serial.print(F("STA:CONV1:")); Serial.print(belts[0].isRunning ? "RUN" : "IDLE");
      Serial.print(F(",CONV2:")); Serial.print(belts[1].isRunning ? "RUN" : "IDLE");
      Serial.print(F(",CONV3:")); Serial.println(belts[2].isRunning ? "RUN" : "IDLE");
    }
  }

  // Iterate through all 3 conveyors independently
  for (uint8_t i = 0; i < 3; i++) {
    int sensorVal = digitalRead(belts[i].sensorPin);

    // Active LOW sensor triggered on newly detected parcel
    if (sensorVal == LOW && belts[i].lastSensorState == HIGH) {
      Serial.print(F("EVT:OBJECT_DETECTED_CONV_"));
      Serial.println(belts[i].id);
      startBelt(belts[i]);
    }
    belts[i].lastSensorState = sensorVal;

    // Check non-blocking runtime duration timer
    if (belts[i].isRunning) {
      if (now - belts[i].startTime >= CONVEYOR_RUN_DURATION_MS) {
        stopBelt(belts[i]);
        Serial.print(F("EVT:TRANSIT_COMPLETE_CONV_"));
        Serial.println(belts[i].id);
      }
    }
  }
}

/**
 * @brief Activate conveyor motor and reset independent run timer
 */
void startBelt(ConveyorBelt &belt) {
  belt.motor->setSpeed(MOTOR_SPEED_DEFAULT);
  belt.motor->run(FORWARD);
  belt.isRunning = true;
  belt.startTime = millis();
}

/**
 * @brief Stop conveyor motor
 */
void stopBelt(ConveyorBelt &belt) {
  belt.motor->run(RELEASE);
  belt.isRunning = false;
}

/**
 * @brief Immediate master safety stop for all 3 belts
 */
void emergencyStopAll() {
  for (uint8_t i = 0; i < 3; i++) {
    stopBelt(belts[i]);
  }
}
