# Known Issues, Discrepancies, and Engineering Assumptions

This document catalogs every discrepancy, syntax error, electrical hazard, pin conflict, and missing implementation identified in the diploma project report *"Conveyor Belt with Portable Robotic Arm"* (Government Polytechnic Panaji, 2024), along with the engineered resolution implemented in this repository.

---

## 1. Syntax and Compilation Errors in Source Code

### Issue 1.1: Invalid C Preprocessor Syntax in Base Firmware
* **Location in Report:** Chapter 4, Page 46 (Printed p. 41), lines 1–4:
  ```cpp
  #define in1 to pin 5 
  #define in2 to pin 6
  #define in3 to pin 10
  #define in4 to pin 11
  ```
* **Defect:** In standard C/C++, `#define <identifier> <replacement>` treats `to pin 5` as the replacement token stream. Any reference to `in1` expands to `to pin 5`, resulting in immediate compiler syntax errors such as `error: expected primary-expression before 'to'`.
* **Resolution:** Replaced with correct integer constants or standard macros:
  ```cpp
  const uint8_t PIN_BASE_IN1 = 5;
  const uint8_t PIN_BASE_IN2 = 6;
  const uint8_t PIN_BASE_IN3 = 10;
  const uint8_t PIN_BASE_IN4 = 11;
  ```

### Issue 1.2: Misspelled Keyword in Base Initialization
* **Location in Report:** Chapter 4, Page 46 (Printed p. 41):
  ```cpp
  Pin Mode(in4, OUTPUT);
  ```
* **Defect:** A space is inserted into the Arduino core function identifier `pinMode()`. C++ is case-sensitive and does not allow spaces inside tokens.
* **Resolution:** Corrected to `pinMode(PIN_BASE_IN4, OUTPUT);`.

### Issue 1.3: Multi-Character Literal in Single-Byte Evaluation (Robotic Arm)
* **Location in Report:** Chapter 4, Page 50–51 (Printed p. 45–46):
  ```cpp
  Val = Serial.read();
  ...
  if (Val == 'TU'){
    top up();
  }
  if (Val == 'TD'){
    top down();
  }
  ```
* **Defect:** `Serial.read()` returns an `int` containing one byte (0–255, or -1 if empty). In C++, `'TU'` is an implementation-defined multi-character character constant evaluated as `(0x54 << 8) | 0x55 = 21589`. A single read byte can never equal `21589`, meaning the "top up" and "top down" arm joints can never be actuated.
* **Resolution:** Standardized command protocol to unique single-byte ASCII characters:
  * `'T'` -> Top / Wrist Up
  * `'t'` -> Top / Wrist Down
  * Forward-compatible parser accepting both single-character tokens and multi-byte framed strings (`"TU\n"`, `"TD\n"`).

### Issue 1.4: Function Identifiers Containing Spaces
* **Location in Report:** Chapter 4, Page 50–52 (Printed p. 45–47):
  ```cpp
  top up();
  ...
  void top up() { ... }
  void top down() { ... }
  ```
* **Defect:** C++ function names cannot contain spaces. This causes immediate compilation failure: `error: expected initializer before 'up'`.
* **Resolution:** Renamed functions to standard snake_case / camelCase:
  * `armTopUp()` / `arm_top_up()`
  * `armTopDown()` / `arm_top_down()`

### Issue 1.5: Missing Function Declaration in Colour Conveyor
* **Location in Report:** Chapter 4, Page 53 (Printed p. 48):
  ```cpp
  motorControl(motor1EnablePin, 255, HIGH, LOW);
  ...
  motorControl(motor1EnablePin, 0, LOW, LOW);
  ```
* **Defect:** The function `motorControl` is called repeatedly in `loop()`, but its implementation is completely missing from the sketch. Arduino IDE fails with `'motorControl' was not declared in this scope`.
* **Resolution:** Implemented the full helper function:
  ```cpp
  void motorControl(uint8_t enablePin, uint8_t speed, uint8_t in1State, uint8_t in2State) {
    digitalWrite(PIN_CONV_IN1, in1State);
    digitalWrite(PIN_CONV_IN2, in2State);
    analogWrite(enablePin, speed);
  }
  ```

---

## 2. Pin Conflicts and Shield Architecture

### Issue 2.1: Critical Pin 9 Conflict on 1st Conveyor Arduino
* **Location in Report:** Chapter 2, Page 27 (Printed p. 22) and Chapter 4, Page 53 (Printed p. 48):
  ```cpp
  const int motor1EnablePin = 9; // PWM pin for motor 1 speed control
  ...
  servo1.attach(9);
  ```
* **Defect:**
  1. Pin 9 is wired simultaneously to the L298N `ENA` terminal (speed control) and to the signal pin of the MG946R servo motor.
  2. The Arduino standard `Servo` library uses Timer1 on ATmega328P. When `servo1.attach(9)` is called, the library takes over Timer1 to generate precision PPM pulses (1–2 ms), which **permanently disables hardware PWM (`analogWrite`) on Pins 9 and 10**.
  3. Consequently, calling `analogWrite(motor1EnablePin, 255)` either corrupts the servo angle or gets overridden, while the servo receives motor PWM noise.
* **Resolution:**
  * Dedicated Motor PWM Enable: Kept on **Pin 9** (or Pin 5).
  * Relocated Servo Signal: Moved to **Pin 10** or a dedicated digital pin such as **Pin 4**, or if using Pin 10, run the motor without timer conflict.
  * Verified Pin Mapping:
    * `PIN_CONV_IN1` = 2
    * `PIN_CONV_IN2` = 3
    * `PIN_SERVO_DIVERTER` = 4 (or Pin 10 with soft-servo if PWM needed)
    * `PIN_IR_PROXIMITY` = 7
    * `PIN_CONV_ENA` = 9 (hardware PWM)

### Issue 2.2: L293D Shield Pin Contention in 3-Conveyor Sketch
* **Location in Report:** Chapter 2, Page 29 (Printed p. 24) and Chapter 4, Page 55 (Printed p. 50):
  * Arduino Pin 2 -> IR Sensor 1
  * Arduino Pin 6 -> IR Sensor 2
  * Arduino Pin 10 -> IR Sensor 3
* **Defect:**
  * The Adafruit L293D Motor Shield v1 permanently hardwires the following pins on Arduino Uno:
    * Pins 4, 7, 8, 12: 74HC595 shift register (direction control)
    * Pin 3: PWM for DC Motor 2
    * Pin 5: PWM for DC Motor 3
    * Pin 6: PWM for DC Motor 4
    * Pin 11: PWM for DC Motor 1
    * Pin 9: Servo 2 connector
    * Pin 10: Servo 1 connector
  * Connecting IR Sensor 2 to Pin 6 connects the sensor output directly to the PWM drive line for Motor 4. If M4 is energized or if high-frequency PWM is emitted, the sensor line is clamped or damaged.
  * Connecting IR Sensor 3 to Pin 10 ties the sensor to the Servo 1 output header.
* **Resolution:**
  * Rerouted IR sensors to the completely free Arduino Uno Analog pins:
    * `PIN_IR_1` = A0 (Digital Pin 14)
    * `PIN_IR_2` = A1 (Digital Pin 15)
    * `PIN_IR_3` = A2 (Digital Pin 16)
  * Analog pins on ATmega328P can be addressed as digital general-purpose I/O (`pinMode(A0, INPUT_PULLUP)`), leaving all L293D motor drivers free from electrical conflict.

### Issue 2.3: Robotic Arm Motor 4 vs Servo Discrepancy
* **Location in Report:**
  * Chapter 2, Page 25 (Printed p. 20): *"M4 pin is connected to Servo motor"*
  * Chapter 4, Page 50 (Printed p. 45): `AF_DCMotor motor4(4, MOTOR34_1KHZ);` with `motor4.run(FORWARD)` and `motor4.run(BACKWARD)` for gripper control.
* **Defect:** An L293D terminal (M4) is a reversible DC H-bridge port (delivers full DC voltage with reversing polarity). Connecting a 3-wire hobby servo (MG946R: Signal, VCC, GND) to M4 will destroy the servo logic board when polarity reverses. Conversely, if a DC gear motor is used for the gripper, calling servo routines will fail.
* **Resolution:**
  * Implemented dual-mode abstraction in firmware:
    * Mode A (Default - matches Chapter 4 code): DC motor on M4 terminal controlled via AFMotor (`armGripperOpen()`, `armGripperClose()`).
    * Mode B (Matches Chapter 2 text / MG946R bill of materials): Servo motor on Shield Servo Header 1 (Pin 10), sweeping from 30° (closed) to 120° (open).
    * Switchable with a simple compile-time preprocessor definition `#define USE_SERVO_GRIPPER false`.

---

## 3. Sensor Mechanics and Calibration

### Issue 3.1: Physically Nonsensical TCS3200 Reading Logic
* **Location in Report:** Chapter 2, Page 28 (Printed p. 23) and Chapter 4, Page 53 (Printed p. 48):
  ```cpp
  col=(analogRead(A0)+analogRead(A1)+analogRead(A2)+analogRead(A3)/4);
  ...
  if((col>1820 )&&(col< 2000 )) { /* red */ }
  if((col> 2020 )&&(col< 3000 )) { /* green */ }
  if((col> 1600 )&&(col< 1800 )) { /* blue */ }
  ```
* **Defect:**
  1. The TCS3200 is an optical light-to-frequency converter. Its pinout is:
     * `VDD` (5V), `GND`
     * `S0`, `S1`: Frequency scaling selection (digital logic inputs)
     * `S2`, `S3`: Photodiode colour filter selection (digital logic inputs)
     * `OE`: Output Enable (active low)
     * `OUT`: Digital square-wave pulse train output whose frequency is proportional to light intensity.
  2. The TCS3200 **does not have 4 analog output channels**. The report connects P1–P4 (which in hardware are control inputs S0, S1, S2, S3 or similar) to Arduino analog inputs A0–A3 and performs an `analogRead()`.
  3. Reading floating digital input pins with an ADC yields fluctuating random electrical noise.
  4. The operator precedence error `analogRead(A0)+...+analogRead(A3)/4` divides only A3 by 4.
  5. The hardcoded thresholds (`1820..2000`, etc.) were either arbitrarily invented or recorded under specific room lighting with an uncalibrated photodiode clone.
* **Resolution:**
  * Implemented genuine TCS3200 frequency acquisition engine:
    * Configure S0/S1 for 20% frequency scaling.
    * Dynamically toggle S2/S3 to sequentially select Red, Green, and Blue optical filters.
    * Read pulse duration using `pulseIn(PIN_TCS_OUT, LOW, 25000)`.
    * Implemented runtime interactive calibration mode (`CALIBRATE` command over serial) to determine baseline White, Black, Red, Green, and Blue pulse durations under actual operating lighting.
    * Provided a fallback simulation/normalized filter algorithm for testing without physical TCS3200 hardware.

---

## 4. Concurrency and Timing Deficiencies

### Issue 4.1: Blocking `delay(5000)` Cascades in 3-Conveyor Subsystem
* **Location in Report:** Chapter 4, Page 55–56 (Printed p. 50–51):
  ```cpp
  if (irsensor1==LOW) {
    motor1.run(FORWARD);
    Serial.println("object detected");
    delay(5000);
  }
  ...
  if (irsensor2==LOW) {
    motor2.run(FORWARD);
    delay(5000);
  }
  ...
  if (irsensor3==LOW) {
    motor3.run(FORWARD);
    delay(5000);
  }
  ```
* **Defect:** If Sensor 1 detects a parcel, the microcontroller enters a 5000 ms hardware spin loop. If a parcel arrives at Sensor 2 or 3 during this window, the controller is completely deaf, failing to trigger the corresponding conveyor belts. In the worst case, the loop blocks for 15 full seconds.
* **Resolution:** Re-architected with a fully non-blocking, event-driven state machine using `millis()` timestamps. Each conveyor belt transitions independently between `CONVEYOR_IDLE`, `CONVEYOR_RUNNING`, and `CONVEYOR_COOLDOWN` states.

---

## 5. Electrical, Thermal, and Battery Safety Hazards

### Issue 5.1: 78M05 Voltage Regulator Overload on L298N
* **Report Assumption:** Page 25 states that the 5V output of the L298N supplies Arduino 1, Arduino 2, Bluetooth modules 1 & 2, and the ESP32-CAM.
* **Hazard:**
  * The L298N on-board regulator is a 78M05 linear regulator rated for 500mA maximum under optimal heatsinking.
  * Input voltage from 3S LiPo is 11.1V–12.6V. Voltage drop across the regulator is $\Delta V = 12.6V - 5.0V = 7.6V$.
  * Current consumption:
    * Arduino Uno #1: ~50mA
    * Arduino Uno #2: ~50mA
    * HC-05 #1 & #2: ~80mA total
    * ESP32-CAM: ~180mA idle, spikes to >350–500mA during Wi-Fi transmission.
    * Total 5V load: >550–700mA.
  * Power dissipated as heat: $P_D = I \times \Delta V \approx 0.6A \times 7.6V = 4.56W$!
  * The unheatsinked 78M05 will enter thermal shutdown within seconds, causing repetitive micro-resets, Bluetooth dropouts, and brownout loops on the ESP32-CAM.
* **Resolution:**
  * Remove the 5V jumper on L298N.
  * Supply the 5V logic bus via a dedicated high-efficiency step-down switching DC-DC buck converter (LM2596 or MP1584 rated for 5V 3A continuous).

### Issue 5.2: 3S LiPo High-Discharge Battery Safety (11.1V 2200mAh 30C)
* **Hazard:** LiPo batteries have near-zero internal resistance. A dead short can deliver >66A continuous and 132A burst, instantly melting jumper wires and causing fire.
* **Resolution:**
  * Mandatory 10A inline automotive blade fuse on the battery positive lead.
  * Master heavy-duty toggle switch for physical electrical isolation.
  * Battery low-voltage cutoff monitor set to trigger at 9.9V (3.3V/cell) to prevent destructive cell over-discharge.

---

## 6. Wireless Connectivity and Security

### Issue 6.1: Hardcoded Personal Hotspot Credentials
* **Location in Report:** Chapter 4, Page 57 (Printed p. 52):
  ```cpp
  const char* ssid = "Esham 3503";
  const char* password = "12345678";
  ```
* **Defect:** Hardcoding personal wireless credentials into version-controlled firmware violates security standards and causes firmware compilation lock-in.
* **Resolution:**
  * Extracted Wi-Fi configuration into `firmware/esp32_cam/secrets.h` (git-ignored) with a sanitized template `firmware/esp32_cam/secrets.example.h`.
  * Implemented an automatic Wi-Fi Access Point fallback (`ESP32-CAM-ROBOT`, WPA2 pass: `conveyor123`) so the camera stream is accessible anywhere without editing code.

### Issue 6.2: HC-05 Bluetooth Classic vs Bluetooth Low Energy (BLE)
* **Report Assumption:** Report refers to Bluetooth communication from mobile devices.
* **Technical Reality:** The HC-05 module implements Bluetooth v2.0+EDR with the Serial Port Profile (SPP / RFCOMM). It is **not** Bluetooth Low Energy (BLE).
* **Impact on Android & Mobile App:**
  * Modern Android versions (Android 12+) require explicit `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` runtime permissions.
  * HC-05 requires standard RFCOMM socket binding (UUID `00001101-0000-1000-8000-00805F9B34FB`).
  * Web browsers cannot connect directly to HC-05 SPP devices via Web Bluetooth API (Web Bluetooth strictly supports BLE GATT services).
* **Resolution:**
  * Implemented native Bluetooth Classic SPP communications in the Flutter Android app.
  * Added a Mock/Demo Mode engine in the mobile app and Web Console, allowing full UI demonstration and test execution on desktop, web, or emulators without requiring a physical HC-05 link.

---

## 7. Verification Status Matrix

| Subsystem Component | Firmware Implementation | Hardware Simulation Engine | Physical Bench Verification |
| :--- | :--- | :--- | :--- |
| **Robotic Base (L298N + 4 BO Motors)** | Production Ready (`firmware/robotic_base`) | Verified in Web Demo & App Mock Engine | `UNVERIFIED_ON_PHYSICAL_HARDWARE` |
| **Robotic Arm (L293D + 3 DC + 1 Servo/DC)**| Production Ready (`firmware/robotic_arm`) | Verified in Web Demo & App Mock Engine | `UNVERIFIED_ON_PHYSICAL_HARDWARE` |
| **Colour Conveyor (L298N + IR + TCS3200)** | Production Ready (`firmware/colour_sorting_conveyor`) | Full optical sorting simulation | `UNVERIFIED_ON_PHYSICAL_HARDWARE` |
| **3-Stage Conveyor (Non-blocking FSM)** | Production Ready (`firmware/three_conveyor`) | Multi-station transit simulation | `UNVERIFIED_ON_PHYSICAL_HARDWARE` |
| **ESP32-CAM MJPEG Video Streamer** | Production Ready (`firmware/esp32_cam`) | Simulated test-card feed + Live HTTP client | `UNVERIFIED_ON_PHYSICAL_HARDWARE` |
| **Android Industrial Control Application**| Complete Flutter App (`mobile_app/`) | Full Mock Controller bridge | Tested on Android runtime |
| **Interactive Web Demonstration Console** | Complete HTML5/Canvas App (`web_demo/`) | Interactive physical automation cell | Tested on modern web browsers |
