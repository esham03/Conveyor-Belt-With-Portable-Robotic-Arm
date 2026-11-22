# System Architecture: Conveyor Belt with Portable Robotic Arm

## 1. System Philosophy and Design Intent
The project integrates mobile robotics, multi-degree-of-freedom manipulation, automated optical inspection, material transfer, and wireless telemetry into a unified industrial automation cell.

The physical design separates control responsibilities among dedicated embedded microcontrollers, preventing real-time motor control timing loops from interfering with sensor processing or wireless communication.

```
+====================================================================================================+
|                                    OPERATOR CONTROL INTERFACES                                     |
+====================================================================================================+
           |                                                                          |
           | Bluetooth Classic (RFCOMM / SPP)                                         | Wi-Fi (HTTP 80/81)
           v                                                                          v
+-------------------------------+                                      +-----------------------------+
|    ANDROID MOBILE CONTROL     |                                      |    WEB / MONITOR CONSOLE    |
| - D-Pad Mobile Base Control   |                                      | - Automation Cell 2D/3D Sim |
| - 4-Axis Arm Articulation     |                                      | - Serial Protocol Monitor   |
| - Conveyor & Sorting Controls |                                      | - Live MJPEG Camera Feed    |
| - Telemetry & Event Logging   |                                      | - Pin & Wiring Reference    |
| - Master Emergency Stop       |                                      | - Subsystem Health Status   |
+-------------------------------+                                      +-----------------------------+
           |                                                                          |
+====================================================================================================+
|                                  WIRELESS TRANSMISSION LAYERS                                      |
+====================================================================================================+
     |                                          |                                     |
     v HC-05 Channel 1                          v HC-05 Channel 2                     v 802.11 b/g/n
+-----------------------+              +-----------------------+              +----------------------+
| HC-05 Module #1       |              | HC-05 Module #2       |              | ESP32-CAM AI-Thinker |
| (Base Controller)     |              | (Arm Controller)      |              | (2MP OV2640 Sensor)  |
| UART: 9600-8-N-1      |              | UART: 9600-8-N-1      |              | HTTP MJPEG Server    |
+-----------------------+              +-----------------------+              +----------------------+
     |                                          |                                     |
+====================================================================================================+
|                                     EMBEDDED CONTROL CORE                                          |
+====================================================================================================+
     | Pins 0/1                                 | Pins 0/1                            |
     v                                          v                                     |
+-----------------------+              +-----------------------+                      |
|   ARDUINO UNO #1      |              |   ARDUINO UNO #2      |                      |
| Mobile Robotic Base   |              | Robotic Manipulator   |                      |
| - 4WD PWM Drive       |              | - Waist Rotation      |                      |
| - Electronic Braking  |              | - Shoulder Lift       |                      |
| - Diagonal Omnidrive  |              | - Elbow / Wrist Artic |                      |
| - Speed Control       |              | - Gripper Clamping    |                      |
+-----------------------+              +-----------------------+                      |
     |                                          |                                     |
     | IN1-IN4 (Pins 5,6,10,11)                 | AFMotor SPI & PWM                   |
     v                                          v                                     |
+-----------------------+              +-----------------------+                      |
| L298N Motor Driver    |              | L293D Shield v1       |                      |
| - Dual H-Bridge 2A    |              | - Quad H-Bridge 0.6A  |                      |
| - Left/Right Ganged   |              | - 74HC595 Shift Reg   |                      |
+-----------------------+              +-----------------------+                      |
     |                                          |                                     |
     v                                          v                                     |
+-----------------------+              +-----------------------+                      |
| 4x 100 RPM BO Motors  |              | 3x 12V DC Gear Motors |                      |
| (Mobile Base Wheels)  |              | + 1x Gripper Actuator |                      |
+-----------------------+              +-----------------------+                      |
                                                                                      |
+-----------------------------------------------------------------------+             |
|                  CONVEYOR MATERIAL HANDLING SUITE                     |             |
|                                                                       |             |
|   +-------------------------------+   +---------------------------+   |             |
|   |        ARDUINO UNO #3         |   |      ARDUINO UNO #4       |   |             |
|   | Optical Sorting Conveyor      |   | 3-Stage Transfer Conveyor |   |             |
|   | - Digital IR Obstacle Detect  |   | - Non-blocking FSM Logic  |   |             |
|   | - TCS3200 RGB Spectral Freq   |   | - 3x Independent IR Gates |   |             |
|   | - MG946R High-Torque Diverter |   | - 3x BO DC Transfer Drives|   |             |
|   | - L298N Belt Motor Control    |   | - L293D Quad Shield       |   |             |
|   +-------------------------------+   +---------------------------+   |             |
|                |                                    |                 |             |
|                v                                    v                 |             |
|   +-------------------------------+   +---------------------------+   |             |
|   | 1x BO DC Belt Motor           |   | 3x BO DC Transfer Belts   |   |             |
|   | 1x MG946R Diverter Servo      |   | 3x Sharp/IR Photo-Gates   |   |             |
|   | 1x TCS3200 Optical Sensor     |   +---------------------------+   |             |
|   | 1x IR Proximity Sensor        |                                   |             |
|   +-------------------------------+                                   |             |
+-----------------------------------------------------------------------+             |
                                                                                      |
+====================================================================================================+
|                                    POWER DISTRIBUTION SYSTEM                                       |
+====================================================================================================+
|  Primary Energy Source: 11.1V (3S) LiPo 2200mAh 30C Battery Pack via XT60 & 10A Master Fuse       |
|  High-Current Rail (11.1V): Direct to L298N VMS & L293D EXT-PWR terminals                        |
|  Regulated Logic Rail (5.0V): Dedicated 3A DC-DC Buck Converter -> Arduinos, HC-05s, ESP32-CAM     |
|  Regulated Servo Rail (5.0–6.0V): High-Peak Servo Buck Regulator -> MG946R Diverter & Gripper      |
|  Common Reference: Unified low-impedance Ground Plane interconnecting all five nodes              |
+====================================================================================================+
```

---

## 2. Subsystem Functional Breakdown

### Subsystem 1: Portable Robotic Base
* **Microcontroller:** Arduino Uno R3 (ATmega328P).
* **Driver:** L298N Dual H-Bridge Driver module.
* **Actuators:** 4x 100 RPM BO DC geared motors. Left motors wired in parallel to OUT1/OUT2; right motors wired in parallel to OUT3/OUT4.
* **Telemetry & Control:** HC-05 Bluetooth Classic module connected to hardware UART (Pins 0/1).
* **Control Modes:**
  * Cardinal Directions: Forward (`F`), Backward (`B`), Left Pivot (`L`), Right Pivot (`R`).
  * Diagonal Motion: Forward-Left (`G`), Forward-Right (`I`), Backward-Left (`H`), Backward-Right (`J`).
  * Velocity Adjustment: PWM speed variable from 0 to 255.
  * Electronic Braking (`S`): Momentarily drives both motor terminals to HIGH logic to short-circuit the armature, creating electromagnetic dynamic braking before disabling drive.

### Subsystem 2: Portable Robotic Arm
* **Microcontroller:** Arduino Uno R3 (ATmega328P).
* **Driver:** Adafruit L293D Motor Driver Shield v1.
* **Actuators:**
  * Motor 1 (M1 port): 30 RPM 12V centre-shaft DC gear motor for 360° waist rotation (Left/Right).
  * Motor 2 (M2 port): 10 RPM 12V high-torque DC gear motor for shoulder elevation (Up/Down).
  * Motor 3 (M3 port): 10 RPM 12V high-torque DC gear motor for elbow/wrist pitch (Top Up/Top Down).
  * Motor 4 (M4 port or Servo 1 header): Dual configuration:
    * Mode A (DC motor): DC geared motor with rack/pinion gripper.
    * Mode B (Servo): MG946R metal-gear servo for proportional gripper angle (0° to 180°).
* **Telemetry & Control:** HC-05 Bluetooth Classic module #2 on UART (Pins 0/1).

### Subsystem 3: Colour-Sorting Conveyor
* **Microcontroller:** Arduino Uno R3 (ATmega328P).
* **Driver:** L298N Motor Driver module.
* **Sensors:**
  * IR Optical Proximity Obstacle Sensor (active low digital input on Pin 7).
  * TCS3200 Colour Recognition Sensor (8x8 photodiode array with programmable color filters).
* **Actuator:**
  * 1x 100 RPM BO motor driving the main feed belt.
  * 1x MG946R metal-gear servo driving the sorting diverter chute.
* **Sorting Logic:**
  1. Conveyor runs forward, feeding incoming parcels.
  2. IR sensor detects arrival of a parcel at the optical inspection chamber; belt immediately stops.
  3. TCS3200 initiates spectral frequency sampling across Red, Green, and Blue filter banks.
  4. Decision engine maps measured values against calibrated thresholds:
     * Red -> Chute diverted to 45°
     * Green -> Chute diverted to 90°
     * Blue -> Chute diverted to 135°
     * Unknown/Uncalibrated -> Default neutral bypass (0°)
  5. Chute actuates; belt pulses briefly to eject parcel into the assigned bin; diverter resets to neutral; continuous feed resumes.

### Subsystem 4: 3-Stage Transfer Conveyor
* **Microcontroller:** Arduino Uno R3 (ATmega328P).
* **Driver:** L293D Motor Driver Shield v1.
* **Sensors:** 3x IR Proximity Sensors positioned at conveyor transfer junctions.
* **Actuators:** 3x 100 RPM BO DC geared motors driving Belts 1, 2, and 3.
* **Concurrency Engine:** Fully non-blocking event-driven finite-state machine (FSM). Each conveyor operates an independent timer and state tracker:
  * Sensor trigger starts the designated belt for a configurable transfer duration (default 5.0 seconds).
  * Independent timers ensure that triggers on any belt do not block or interrupt ongoing transport on the other two belts.

### Subsystem 5: Surveillance Camera (ESP32-CAM)
* **Processor:** ESP32-S dual-core Xtensa LX6 @ 240 MHz, 520 KB SRAM, 4 MB external PSRAM.
* **Sensor:** OV2640 2.0 Megapixel CMOS image sensor.
* **Wireless Protocol:** 802.11 b/g/n Wi-Fi @ 2.4 GHz.
* **Streaming Protocol:** HTTP Multipart MJPEG video streaming server on port 80/81.
* **Resolution Support:** QVGA (320x240) default for low-latency streaming (15–25 fps); configurable up to SVGA/VGA.
* **Network Modes:**
  * Station Mode (STA): Joins existing production Wi-Fi network (configured via `secrets.h`).
  * Access Point Mode (AP): Autonomous hotspot (`ESP32-CAM-ROBOT`, 192.168.4.1) for zero-configuration field deployments.
