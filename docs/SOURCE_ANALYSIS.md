# Source Document Analysis: "Conveyor Belt with Portable Robotic Arm"

## 1. Document Provenance and Bibliographic Metadata
* **Document Title:** Conveyor Belt with Portable Robotic Arm
* **Authors:** Esham U. Chari (210105002), Kaushal A. Parab (210105005), Chetan S. Korgaonkar (210105006), Vishwanath P. Vaghmode (210105015)
* **Academic Award:** Diploma in Electronics Engineering
* **Institution:** Government Polytechnic Panaji (Department of Electronics Engineering)
* **Project Guide:** Mrs. Shruti Gosavi
* **Head of Department:** Mrs. Manisha Sajane
* **Principal:** Mrs. Pramodini Naik
* **Date:** April 2024 (Academic Year 2023–24)
* **Document Extent:** 60 pages (Cover to Bibliography)

---

## 2. Executive Architectural Decomposition

The report presents an integrated multi-subsystem physical automation platform combining mobile robotics, robotic manipulation, material handling with automated optical sorting, multi-stage conveyor transfer, and remote optical inspection.

The overall system is architecturally partitioned into five physical hardware subsystems:

```
+-----------------------------------------------------------------------------------------+
|                                    OPERATOR INTERFACE                                   |
|   +---------------------------------------+   +-------------------------------------+   |
|   | Android Application (Bluetooth Classic)|   | Web / Local Browser (Wi-Fi HTTP)    |   |
|   +---------------------------------------+   +-------------------------------------+   |
+-----------------------------------------------------------------------------------------+
                    | UART Serial over RFCOMM                        | HTTP Stream (MJPEG)
                    v                                                v
+---------------------------------------+       +-----------------------------------------+
|         WIRELESS CONTROL LINK         |       |            VISION SUBSYSTEM             |
|   +-------------------------------+   |       |   +---------------------------------+   |
|   | HC-05 Bluetooth Module (x2)   |   |       |   | ESP32-CAM AI-Thinker (OV2640)   |   |
|   +-------------------------------+   |       |   +---------------------------------+   |
+---------------------------------------+       +-----------------------------------------+
        | Pin 0/1 UART          | Pin 0/1 UART                           ^ 5V DC Supply
        v                       v                                        |
+------------------+    +-------------------+           +---------------------------------+
|   SUBSYSTEM 1    |    |    SUBSYSTEM 2    |           |          POWER SYSTEM           |
|  Robotic Base    |    |   Robotic Arm     |           | 11.1V 3S LiPo 2200mAh 30C       |
|  Arduino Uno #1  |    |  Arduino Uno #2   |           | Common Ground Distribution Bus  |
|  L298N H-Bridge  |    |  L293D Shield     |           +---------------------------------+
|  4x BO Motors    |    |  3x DC Gear + Srv |
+------------------+    +-------------------+
                                                                |
+---------------------------------------------------------------+
|
|---> +---------------------------------------------------------+
      |                       CONVEYOR SYSTEM                   |
      |   +---------------------------+   +-----------------+   |
      |   |        SUBSYSTEM 3        |   |   SUBSYSTEM 4   |   |
      |   |  Colour-Sorting Conveyor  |   | 3-Stage Transfer|   |
      |   |  Arduino Uno #3           |   | Arduino Uno #4  |   |
      |   |  L298N Driver             |   | L293D Shield    |   |
      |   |  TCS3200 Colour Sensor    |   | 3x IR Sensors   |   |
      |   |  IR Proximity Sensor      |   | 3x BO DC Motors |   |
      |   |  MG946R Diverter Servo    |   +-----------------+   |
      |   |  100 RPM BO Belt Drive    |                         |
      |   +---------------------------+                         |
      +---------------------------------------------------------+
```

---

## 3. Chapter-by-Chapter Technical Analysis

### 3.1 Chapter 1: Component Catalogue & Specifications (Printed Pages 1–16)

| Component | Reported Specifications (Chapter 1) | Functional Role in System | Critical Operational Notes |
| :--- | :--- | :--- | :--- |
| **Arduino UNO R3** (p. 6–7) | ATmega328P, 16 MHz, 14 Digital I/O (6 PWM), 6 Analog In, Operating 5V, Input 7–20V. | Master embedded compute node for each subsystem (4 physical Uno units deployed). | Must maintain a common DC ground reference across all shields, drivers, and sensors. |
| **10 RPM 12V DC Gear Motor** (p. 7) | 12V DC, 10 RPM, 7 kg-cm torque, plastic gearbox, 6mm shaft, No-load: 60mA, Load: 300mA. | Primary articulation for heavy joints of robotic arm (shoulder / elbow). | High reduction ratio prevents back-driving under static payload. |
| **30 RPM Centre Shaft DC Motor** (p. 8) | 12V DC (4–12V range), 30 RPM, Stall torque 28 kg-cm @ 1.3A, spur gears, carbon brushes. | Rapid joint articulation / base rotation of robotic arm. | High stall current (1.3A) necessitates robust H-bridge thermal management. |
| **100 RPM DC BO Motor** (p. 8–9) | 3–12V DC, 100 RPM @ rated voltage, 1 kg-cm torque, dual D-shaft, plastic gearbox. | Robotic base wheels (4 units) and conveyor drive rollers (4 units total). | Cheap, lightweight, but introduces wheel-speed variation; requires PWM calibration. |
| **MG946R Digital Servo Motor** (p. 9–10) | 4.8–6.6V DC, 180° rotation, 13 kg-cm @ 6V, metal gears, stall 1.2A, idle 10mA. | Conveyor diverter gate mechanism & robotic arm end-effector gripper. | Requires separate 5–6V regulated rail; **must never be powered directly from Arduino 5V pin**. |
| **HC-05 Bluetooth Module** (p. 10–12) | Bluetooth v2.0+EDR (Classic SPP), 2.4 GHz, 9600 default baud, 3.6–6V VCC, 3.3V logic UART. | Serial wireless telemetry and command reception from Android handset. | **Bluetooth Classic Serial Port Profile (SPP)**. Not BLE. Android handset requires Classic RFCOMM socket. |
| **ESP32-CAM Board** (p. 12–14) | AI-Thinker board, ESP32-S dual-core LX6, 520KB SRAM + 4MB external PSRAM, OV2640 2MP. | Wireless visual surveillance and material quality inspection. | Peak current during Wi-Fi transmission exceeds 310–500mA. Requires dedicated 5V 2A supply rail. |
| **TCS3200 Colour Sensor** (p. 14–15) | 2.7–5.5V, programmable 8x8 photodiode array (16 Red, 16 Green, 16 Blue, 16 Clear), freq output. | Optical classification of conveyored items (Red, Green, Blue). | Outputs square waves of varying frequency; cannot be read accurately via `analogRead()`. |
| **L293D Motor Shield** (p. 15–17) | Dual L293D (4 H-bridges, 0.6A cont/1.2A peak per channel) + 74HC595 shift register. | Drives 4 arm motors (Subsystem 2) and 3 conveyor motors (Subsystem 4). | Uses Arduino pins 3, 4, 5, 6, 7, 8, 9, 10, 11, 12. Extensively constrains remaining I/O. |
| **L298N Motor Driver** (p. 18–19) | Dual H-bridge, 2A per channel (25W total), on-board 78M05 5V regulator. | Drives 4 base motors (Subsystem 1) and Sorting Conveyor belt motor (Subsystem 3). | Internal 78M05 regulator overheats if powering external loads when V_motor > 12V. |
| **11.1V 3S LiPo Battery** (p. 20) | 3S (3 cells in series, nominal 11.1V, max 12.6V), 2200mAh, 30C discharge (66A cont), XT60. | High-current main energy reservoir for entire mobile robotic platform. | Critical safety hazard: Requires low-voltage cutoff (>=9.9V), fuse protection, and cell balancing. |

---

### 3.2 Chapter 2: Project Description, Block Diagrams & Pin Connections (Printed Pages 17–25)

#### Subsystem 1: Portable Robotic Base
* **Block Diagram Reference:** Page 22 (Printed p. 17)
* **Circuit Diagram Reference:** Page 23 (Printed p. 18)
* **Report Pin Connections (p. 24):**
  * Arduino 1 Pin 0 (RX) connected to TXD of HC-05 #1
  * Arduino 1 Pin 1 (TX) connected to RXD of HC-05 #1
  * Arduino 1 Pin 5 connected to IN1 of L298N
  * Arduino 1 Pin 6 connected to IN2 of L298N
  * Arduino 1 Pin 10 connected to IN3 of L298N
  * Arduino 1 Pin 11 connected to IN4 of L298N
  * L298N OUT1 & OUT2 connected to Motor 1 & Motor 3 (Left side)
  * L298N OUT3 & OUT4 connected to Motor 2 & Motor 4 (Right side)
* **Analysis & Verification:**
  * Pins 5, 6, 10, 11 are hardware PWM pins on the ATmega328P. This allows variable speed control via `analogWrite()`.
  * ENA and ENB jumpers on the L298N are assumed fitted (permanently HIGH), meaning speed is governed by pulsing IN1–IN4 directly.
  * Hardware serial on Pins 0/1 interferes with USB programming if HC-05 is physically wired during sketch upload. A programming disconnect jumper is mandatory.

#### Subsystem 2: Portable Robotic Arm
* **Block Diagram Reference:** Page 22 (Printed p. 17)
* **Circuit Diagram Reference:** Page 23 (Printed p. 18)
* **Report Pin Connections (p. 25):**
  * Arduino 2 Pin 0 (RX) connected to TXD of HC-05 #2
  * Arduino 2 Pin 1 (TX) connected to RXD of HC-05 #2
  * L293D Shield:
    * M1: 12V DC Gear Motor 1 (Waist / Base rotation)
    * M2: 12V DC Gear Motor 2 (Shoulder joint)
    * M3: 12V DC Gear Motor 3 (Elbow / Wrist joint)
    * M4: Stated as "Servo motor" on p. 25, but in Chapter 4 code (p. 50) initialized as `AF_DCMotor motor4(4)`!
* **Analysis & Verification:**
  * The L293D motor shield controls DC motors via the 74HC595 shift register (pins 4, 7, 8, 12) and PWM pins 3 (M2), 5 (M3), 6 (M4), 11 (M1).
  * The text discrepancy regarding M4 (DC motor vs Servo) must be accommodated by firmware supporting either a DC motorized gripper or an MG946R servo gripper plugged into the L293D Servo 1 or Servo 2 header (pins 9/10).

#### Subsystem 3: Colour-Sorting Conveyor
* **Block Diagram Reference:** Page 26 (Printed p. 21)
* **Circuit Diagram Reference:** Page 27 (Printed p. 22)
* **Report Pin Connections (p. 27–28):**
  * Arduino Pin 2: IN1 of L298N
  * Arduino Pin 3: IN2 of L298N
  * Arduino Pin 7: IR Sensor digital output
  * Arduino Pin 9: ENA of L298N (Motor enable/speed)
  * Servo signal: Listed as "Servo 2 pin is connected to servo motor" on p. 27, but attached to **Pin 9** in code on p. 53 (`servo1.attach(9);`)!
  * TCS3200 Colour Sensor (p. 28):
    * P1 connected to Analog pin A0
    * P2 connected to Analog pin A1
    * P3 connected to Analog pin A2
    * P4 connected to Analog pin A3
* **Analysis & Severe Flaws:**
  1. **Pin 9 Conflict:** Pin 9 cannot be simultaneously connected to L298N ENA and the Servo signal pin. Furthermore, the standard `Servo` library disables PWM on pins 9 and 10 on ATmega328P.
  2. **TCS3200 Miswiring & Bad Code:** The TCS3200 has S0, S1 (frequency scaling), S2, S3 (colour filter selection), and OUT (square-wave output). Connecting S0–S3 to A0–A3 and executing `analogRead(A0) + analogRead(A1)...` is technically incorrect. OUT pin was either omitted or connected to a pin not documented, and reading logic inputs with ADC produces indeterminate results.
  3. **Missing Function:** Code on p. 53 calls `motorControl(...)` which is never defined in the report.

#### Subsystem 4: 3-Conveyor Transfer Arrangement
* **Block Diagram Reference:** Page 28 (Printed p. 23)
* **Circuit Diagram Reference:** Page 29 (Printed p. 24)
* **Report Pin Connections (p. 29–30):**
  * Arduino Pin 2: IR Sensor 1
  * Arduino Pin 6: IR Sensor 2
  * Arduino Pin 10: IR Sensor 3
  * L293D Shield Motor Outputs 1, 2, 3 driving DC BO motors 1, 2, 3.
* **Analysis & Verification:**
  * The L293D shield uses Pin 6 for M4 PWM, and Pin 10 for Servo 1. Using Pin 6 and Pin 10 as digital inputs for IR sensors will conflict if M4 or Servo 1 are touched.
  * Moving IR inputs to free analog pins (A0, A1, A2 configured as `INPUT_PULLUP`) resolves all shield bus conflicts.
  * Code in report uses sequential `delay(5000);` blocks. Each detection stalls the processor for 5 seconds, blinding the other two conveyors. A non-blocking `millis()` finite-state machine (FSM) is essential.

#### Subsystem 5: Surveillance Camera (ESP32-CAM)
* **Description Reference:** Page 12–14 (Printed p. 7–9)
* **Pin Connections & Code Reference:** Page 57–59 (Printed p. 52–54)
* **Analysis & Verification:**
  * AI-Thinker ESP32-CAM pin definitions match standard OV2640 hardware.
  * Wi-Fi credentials printed on p. 57 (`ssid = "Esham 3503"`, `password = "12345678"`) must be expunged and moved to a dedicated `secrets.h` / configurable captive portal.
  * Power supply: ESP32-CAM requires an independent 5V >=2A rail. Powering it from the L298N 5V regulator will cause brownouts during RF bursts.

---

### 3.3 Chapter 4: Original Source Code Listing & Syntax Defects (Printed Pages 41–54)

#### Summary of Bugs in Original Report Code
1. **Robotic Base (p. 46–49):**
   * `#define in1 to pin 5` -> Invalid C preprocessor syntax.
   * `Pin Mode(in4, OUTPUT);` -> Syntax error: space inside keyword `pinMode`.
   * `Stop()` invoked unconditionally after `Serial.read()` before the switch statement, causing motor jitter on packet arrival.
   * Redundant and un-scoped `buttonState` logic inside `brakeOn()` with no return value.
2. **Robotic Arm (p. 50–52):**
   * Multi-character character constants evaluated against 1-byte read: `if (Val == 'TU')`, `if (Val == 'TD')`. In C++, `'TU'` evaluates to integer `0x5455`, which never equals single byte `Val`.
   * Invalid function identifiers with spaces: `top up();`, `top down();`.
   * Floating-point division into integer parameter: `Speeed / 3.1` passed to `uint8_t` `setSpeed()`.
3. **Colour-Sorting Conveyor (p. 53–54):**
   * Undeclared function: `motorControl(motor1EnablePin, 255, HIGH, LOW);` causes compilation abort (`error: 'motorControl' was not declared in this scope`).
   * Operator precedence bug in colour summing: `col = (analogRead(A0)+analogRead(A1)+analogRead(A2)+analogRead(A3)/4);` divides only A3 by 4 instead of the four-element sum.
   * Dual assignment of Digital Pin 9: ENA pin for L298N and `servo1.attach(9)`.
4. **Three Conveyor Belts (p. 55–56):**
   * Blocking delay cascade: Three consecutive `delay(5000)` invocations lock execution for up to 15 seconds.
5. **ESP32-CAM (p. 57–59):**
   * Exposes plaintext personal hotspot credentials (`Esham 3503` / `12345678`).
   * Omits `camera_pins.h` and camera HTTP streaming handler routines (`startCameraServer()` declared but implementation omitted).

---

## 4. Hardware Safety & Electrical Integrity Rules

1. **High-Discharge 3S LiPo Handling (11.1V 2200mAh 30C):**
   * Maximum burst current capability is 132A. Direct short-circuit will cause catastrophic thermal runaway, fire, or explosion.
   * A 10A inline automotive blade fuse must be installed immediately after the battery XT60 connector.
   * A low-voltage alarm (or 3S buzzer) must be fitted to sound when any cell drops below 3.3V (9.9V total pack voltage).
2. **Inductive Back-EMF & Flyback Protection:**
   * Motor drivers (L298N and L293D) contain internal clamp diodes, but high inductive spikes from stalled 12V gear motors can destabilize the 5V logic line. Bulk electrolytic decoupling capacitors (100uF to 470uF) must bridge the motor power input pins.
3. **Common Ground Distribution:**
   * All power rails (11.1V LiPo, 5V logic buck regulator, USB power, Arduino Uno boards, ESP32-CAM) must share an unambiguous low-impedance ground reference. Never connect disparate power supplies without tying ground lines.
4. **Logic Level Integrity on HC-05:**
   * HC-05 VCC requires 3.6V–6V, but its RX pin logic level is 3.3V. While many student projects connect Arduino 5V TX directly to HC-05 RX, this overstresses the Bluetooth baseband IC. A simple voltage divider (1k / 2k resistor pair) steps Arduino 5V TX down to 3.3V for long-term module survival.
5. **Separation of Logic & Motor Power:**
   * Remove the "5V Enable" jumper on the L298N driver when motor voltage exceeds 12V. Even on 11.1V nominal, powering 4 microcontrollers, 2 Bluetooth modules, and an ESP32-CAM from the L298N's on-board linear regulator will trigger thermal shutdown. An external DC-DC step-down buck converter (5V 3A) is mandatory.

---

## 5. Architectural Resolutions & Scope of Implementation

| Issue / Anomaly | Source Report Defect | Engineered Resolution in this Implementation |
| :--- | :--- | :--- |
| **Robotic Base Control** | Broken `#define`, syntax errors, jittery `Stop()`. | Clean Arduino C++ state machine, PWM velocity support, smooth ramp-down braking. |
| **Robotic Arm Protocol** | Multi-char `'TU'`, space in function names. | Single-byte ASCII protocol: `U`, `D`, `L`, `R`, `T`, `t`, `O`, `C`, `S`. Dual-mode gripper support (DC motor or MG946R servo). |
| **Conveyor Pin 9 Conflict** | Pin 9 shared between L298N ENA and Servo. | Relocate Servo to Pin 10. Dedicated L298N ENA on Pin 9. Implement missing `motorControl()` helper. |
| **TCS3200 Sensor Logic** | Faulty `analogRead` summing on digital pins. | Full TCS3200 pulse-frequency measurement engine (`pulseIn` with S0–S3 filter switching) + calibrated software fallback. |
| **3-Conveyor Blocking Delay** | `delay(5000)` freezes all conveyors. | Non-blocking `millis()` finite-state timers for independent parallel conveyor transit. |
| **ESP32-CAM Firmware** | Omitted HTTP handler, exposed credentials. | Complete MJPEG streaming web server with `camera_pins.h`, configurable Wi-Fi, and AP mode fallback. |
| **Android Controller** | Unspecified / rudimentary mobile app. | Production-grade Flutter application with Industrial Control UI, Bluetooth Classic SPP manager, and Mock Hardware engine. |
| **Demonstration Tooling** | None provided in report. | Standalone interactive Web Demonstration Console visualizing the physical automation cell in real time. |
