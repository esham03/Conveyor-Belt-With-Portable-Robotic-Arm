/**
 * @file colour_sorting_conveyor.ino
 * @brief Subsystem 3: Colour-Sorting Conveyor Firmware
 * @project Conveyor Belt with Portable Robotic Arm
 * @reference Government Polytechnic Panaji (Diploma Report 2024, Ch 4, pp. 48-49)
 * 
 * Hardware Architecture:
 * - Microcontroller: Arduino Uno R3 (ATmega328P)
 * - Belt Motor Driver: L298N H-Bridge (Pins 2, 3, 9)
 * - Object Detection: IR Optical Proximity Obstacle Sensor (Pin 7)
 * - Optical Sensing: TCS3200 Programmable Color Sensor (S0-S3, OUT)
 * - Sorting Actuator: MG946R High-Torque Diverter Servo (Pin 10)
 * 
 * Engineered Resolutions:
 * 1. Resolved Pin 9 Conflict:
 *    Original report assigned Pin 9 to both L298N ENA (motor speed PWM) and the
 *    servo signal (servo1.attach(9)). Motor PWM remains on Pin 9 (ENA); the servo
 *    diverter signal is relocated to Pin 10.
 * 2. Implemented Missing Function:
 *    Original report called motorControl(...) without defining it. Full helper implemented.
 * 3. Genuine TCS3200 Optical Sensing Engine:
 *    Replaced faulty analogRead() summing logic with true optical frequency acquisition
 *    via pulseIn() on the TCS3200 OUT pin with S0-S3 photodiode filter sequencing.
 * 4. Non-Blocking Event-Driven State Machine:
 *    Eliminated rigid delays, providing smooth parcel transport, stable colour sampling,
 *    and automatic chute return.
 */

#include <Arduino.h>
#include <Servo.h>

// --- PIN DEFINITIONS ---
const uint8_t PIN_CONV_IN1       = 2;   // L298N Direction 1
const uint8_t PIN_CONV_IN2       = 3;   // L298N Direction 2
const uint8_t PIN_CONV_ENA       = 9;   // L298N Speed PWM
const uint8_t PIN_SERVO_DIVERTER = 10;  // MG946R Diverter Servo (Relocated from Pin 9)
const uint8_t PIN_IR_SENSOR      = 7;   // IR Obstacle Proximity Sensor (Active LOW)

// TCS3200 Colour Sensor Pins
const uint8_t PIN_TCS_S0         = 6;   // Frequency scaling S0
const uint8_t PIN_TCS_S1         = 8;   // Frequency scaling S1
const uint8_t PIN_TCS_S2         = 4;   // Photodiode filter select S2
const uint8_t PIN_TCS_S3         = 5;   // Photodiode filter select S3
const uint8_t PIN_TCS_OUT        = 12;  // Frequency pulse train output

// --- CALIBRATED DIVERTER ANGLES ---
const uint8_t ANGLE_NEUTRAL = 0;    // Belt bypass / home position
const uint8_t ANGLE_RED     = 45;   // Divert chute to Red Bin
const uint8_t ANGLE_GREEN   = 90;   // Divert chute to Green Bin
const uint8_t ANGLE_BLUE    = 135;  // Divert chute to Blue Bin

// --- OPERATIONAL CONSTANTS ---
const uint32_t SERIAL_BAUD = 9600;
const uint8_t BELT_CRUISE_SPEED = 220;
const uint8_t BELT_EJECT_SPEED  = 255;
const uint32_t OPTICAL_SETTLE_MS = 600;
const uint32_t EJECT_PULSE_MS    = 1800;

// --- STATE MACHINE STATES ---
enum ConveyorState {
  STATE_CRUISING,         // Belt running, awaiting parcel arrival at IR gate
  STATE_OBJECT_STOPPED,   // Belt halted, waiting for object vibration to settle
  STATE_MEASURING_COLOR,  // TCS3200 measuring Red, Green, Blue pulse periods
  STATE_DIVERTING,        // Servo rotating to sorted angle
  STATE_EJECTING,         // Belt pulsing to propel parcel down sorted chute
  STATE_RETURNING         // Servo returning to neutral
};

ConveyorState currentState = STATE_CRUISING;
uint32_t stateTimer = 0;
Servo diverterServo;

// Color classification results
enum DetectedColor {
  COLOR_UNKNOWN,
  COLOR_RED,
  COLOR_GREEN,
  COLOR_BLUE
};

DetectedColor classifiedColor = COLOR_UNKNOWN;
uint32_t pulseRed = 0;
uint32_t pulseGreen = 0;
uint32_t pulseBlue = 0;

// --- FORWARD DECLARATIONS ---
void motorControl(uint8_t enablePin, uint8_t speed, uint8_t in1, uint8_t in2);
void readColorSensors(uint32_t &r, uint32_t &g, uint32_t &b);
DetectedColor classifyColor(uint32_t r, uint32_t g, uint32_t b);
void setDiverterForColor(DetectedColor col);

void setup() {
  Serial.begin(SERIAL_BAUD);
  while (!Serial && millis() < 1000) {}

  // Motor pin configuration
  pinMode(PIN_CONV_IN1, OUTPUT);
  pinMode(PIN_CONV_IN2, OUTPUT);
  pinMode(PIN_CONV_ENA, OUTPUT);

  // IR sensor configuration
  pinMode(PIN_IR_SENSOR, INPUT);

  // TCS3200 pin configuration
  pinMode(PIN_TCS_S0, OUTPUT);
  pinMode(PIN_TCS_S1, OUTPUT);
  pinMode(PIN_TCS_S2, OUTPUT);
  pinMode(PIN_TCS_S3, OUTPUT);
  pinMode(PIN_TCS_OUT, INPUT);

  // Configure TCS3200 for 20% frequency scaling (S0=HIGH, S1=LOW or S0=HIGH, S1=HIGH)
  digitalWrite(PIN_TCS_S0, HIGH);
  digitalWrite(PIN_TCS_S1, LOW);

  // Initialize diverter servo
  diverterServo.attach(PIN_SERVO_DIVERTER);
  diverterServo.write(ANGLE_NEUTRAL);

  // Safe boot: Initial belt stop
  motorControl(PIN_CONV_ENA, 0, LOW, LOW);

  Serial.println(F("[SORT_CONV] FIRMWARE INITIALIZED"));
  Serial.println(F("[SORT_CONV] RESOLVED PIN 9 CONFLICT -> SERVO ON PIN 10"));
  Serial.println(F("[SORT_CONV] TCS3200 PULSE-FREQUENCY ENGINE READY"));

  // Start continuous intake
  motorControl(PIN_CONV_ENA, BELT_CRUISE_SPEED, HIGH, LOW);
  currentState = STATE_CRUISING;
}

void loop() {
  // Check for serial calibration commands
  if (Serial.available() > 0) {
    char cmd = (char)Serial.read();
    if (cmd == 'C' || cmd == 'c') {
      Serial.println(F("[CAL] RUNNING SAMPLE..."));
      readColorSensors(pulseRed, pulseGreen, pulseBlue);
      Serial.print(F("R: ")); Serial.print(pulseRed);
      Serial.print(F(" | G: ")); Serial.print(pulseGreen);
      Serial.print(F(" | B: ")); Serial.println(pulseBlue);
    } else if (cmd == 'S' || cmd == 's') {
      // Emergency Belt Halt
      motorControl(PIN_CONV_ENA, 0, LOW, LOW);
      diverterServo.write(ANGLE_NEUTRAL);
      currentState = STATE_CRUISING;
      Serial.println(F("ACK:CONV_STOP"));
    } else if (cmd == 'R' || cmd == 'r') {
      // Resume Belt
      motorControl(PIN_CONV_ENA, BELT_CRUISE_SPEED, HIGH, LOW);
      currentState = STATE_CRUISING;
      Serial.println(F("ACK:CONV_RESUME"));
    }
  }

  // Non-blocking sorting state machine
  switch (currentState) {
    case STATE_CRUISING: {
      // IR sensor is active LOW
      int irVal = digitalRead(PIN_IR_SENSOR);
      if (irVal == LOW) {
        // Parcel detected at optical gate
        motorControl(PIN_CONV_ENA, 0, LOW, LOW); // Belt stop
        Serial.println(F("EVT:BOX_DETECTED"));
        stateTimer = millis();
        currentState = STATE_OBJECT_STOPPED;
      }
      break;
    }

    case STATE_OBJECT_STOPPED: {
      // Allow parcel mechanical bounce to settle before taking optical reading
      if (millis() - stateTimer >= OPTICAL_SETTLE_MS) {
        currentState = STATE_MEASURING_COLOR;
      }
      break;
    }

    case STATE_MEASURING_COLOR: {
      readColorSensors(pulseRed, pulseGreen, pulseBlue);
      classifiedColor = classifyColor(pulseRed, pulseGreen, pulseBlue);

      Serial.print(F("EVT:COLOR_SAMPLED,R:"));
      Serial.print(pulseRed);
      Serial.print(F(",G:"));
      Serial.print(pulseGreen);
      Serial.print(F(",B:"));
      Serial.print(pulseBlue);
      Serial.print(F(",RESULT:"));

      switch (classifiedColor) {
        case COLOR_RED:   Serial.println(F("RED")); break;
        case COLOR_GREEN: Serial.println(F("GREEN")); break;
        case COLOR_BLUE:  Serial.println(F("BLUE")); break;
        default:          Serial.println(F("UNKNOWN")); break;
      }

      setDiverterForColor(classifiedColor);
      stateTimer = millis();
      currentState = STATE_DIVERTING;
      break;
    }

    case STATE_DIVERTING: {
      // Wait for MG946R servo to reach physical diverter angle (400ms)
      if (millis() - stateTimer >= 400) {
        // Eject parcel down chute
        motorControl(PIN_CONV_ENA, BELT_EJECT_SPEED, HIGH, LOW);
        stateTimer = millis();
        currentState = STATE_EJECTING;
      }
      break;
    }

    case STATE_EJECTING: {
      // Pulse belt until parcel is cleanly swept off the sorting diverter
      if (millis() - stateTimer >= EJECT_PULSE_MS) {
        motorControl(PIN_CONV_ENA, 0, LOW, LOW);
        diverterServo.write(ANGLE_NEUTRAL);
        stateTimer = millis();
        currentState = STATE_RETURNING;
      }
      break;
    }

    case STATE_RETURNING: {
      // Wait for diverter arm to return to neutral position (400ms)
      if (millis() - stateTimer >= 400) {
        // Resume normal cruising belt motion
        motorControl(PIN_CONV_ENA, BELT_CRUISE_SPEED, HIGH, LOW);
        currentState = STATE_CRUISING;
        Serial.println(F("EVT:SORT_CYCLE_COMPLETE"));
      }
      break;
    }
  }
}

/**
 * @brief Unified L298N motor drive helper
 */
void motorControl(uint8_t enablePin, uint8_t speed, uint8_t in1State, uint8_t in2State) {
  digitalWrite(PIN_CONV_IN1, in1State);
  digitalWrite(PIN_CONV_IN2, in2State);
  analogWrite(enablePin, speed);
}

/**
 * @brief TCS3200 spectral reading via photodiode filter selection and pulse timing
 */
void readColorSensors(uint32_t &r, uint32_t &g, uint32_t &b) {
  // 1. Select RED filter (S2 = LOW, S3 = LOW)
  digitalWrite(PIN_TCS_S2, LOW);
  digitalWrite(PIN_TCS_S3, LOW);
  delay(15);
  r = pulseIn(PIN_TCS_OUT, LOW, 35000);

  // 2. Select BLUE filter (S2 = LOW, S3 = HIGH)
  digitalWrite(PIN_TCS_S2, LOW);
  digitalWrite(PIN_TCS_S3, HIGH);
  delay(15);
  b = pulseIn(PIN_TCS_OUT, LOW, 35000);

  // 3. Select GREEN filter (S2 = HIGH, S3 = HIGH)
  digitalWrite(PIN_TCS_S2, HIGH);
  digitalWrite(PIN_TCS_S3, HIGH);
  delay(15);
  g = pulseIn(PIN_TCS_OUT, LOW, 35000);
}

/**
 * @brief Classify color based on shortest pulse duration (highest optical frequency)
 */
DetectedColor classifyColor(uint32_t r, uint32_t g, uint32_t b) {
  // If sensor timed out on all channels
  if (r == 0 && g == 0 && b == 0) {
    return COLOR_UNKNOWN;
  }

  // With TCS3200 frequency output, a SHORTER pulse duration represents HIGHER light intensity.
  if (r > 0 && (r < g) && (r < b)) {
    return COLOR_RED;
  } else if (g > 0 && (g < r) && (g < b)) {
    return COLOR_GREEN;
  } else if (b > 0 && (b < r) && (b < g)) {
    return COLOR_BLUE;
  }

  return COLOR_UNKNOWN;
}

/**
 * @brief Actuate MG946R servo diverter based on sorted color
 */
void setDiverterForColor(DetectedColor col) {
  switch (col) {
    case COLOR_RED:
      diverterServo.write(ANGLE_RED);
      break;
    case COLOR_GREEN:
      diverterServo.write(ANGLE_GREEN);
      break;
    case COLOR_BLUE:
      diverterServo.write(ANGLE_BLUE);
      break;
    default:
      diverterServo.write(ANGLE_NEUTRAL); // Neutral bypass chute
      break;
  }
}
