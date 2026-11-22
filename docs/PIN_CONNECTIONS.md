# Pin Connections and Wiring Guide

This document specifies the exact physical wiring, pin assignments, electrical ratings, and safety interlocks for all five subsystems.

> [!WARNING]
> **VERIFY BEFORE POWER ON:**
> Always verify with a digital multimeter that no motor driver inputs or servo signal lines share the same Arduino pins. Disconnect the 11.1V battery main plug before making or modifying any pin connections.

---

## 1. Subsystem 1: Portable Robotic Base (Arduino Uno #1 + L298N)

### Microcontroller Pin Map
| Arduino Pin | Signal Function | Target Device & Pin | Logic Level | Electrical Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Pin 0 (RX)** | Serial Receive | HC-05 #1 TXD | 3.3V / 5V | Disconnect during USB programming. |
| **Pin 1 (TX)** | Serial Transmit | HC-05 #1 RXD | 3.3V (via divider) | 1k/2k resistor voltage divider recommended. |
| **Pin 5** | PWM / Direction IN1 | L298N IN1 | 5V TTL | Left Motors Forward. |
| **Pin 6** | PWM / Direction IN2 | L298N IN2 | 5V TTL | Left Motors Reverse. |
| **Pin 10** | PWM / Direction IN3 | L298N IN3 | 5V TTL | Right Motors Forward. |
| **Pin 11** | PWM / Direction IN4 | L298N IN4 | 5V TTL | Right Motors Reverse. |
| **5V Pin** | Logic Power Input | Regulated 5V Rail | 5.0V DC | From external 5V 3A buck converter. |
| **GND** | Ground Reference | Common Ground Rail | 0V | Tie to L298N GND and battery negative. |

### L298N Motor Driver Connections
| L298N Terminal | Connection Target | Voltage / Current | Notes |
| :--- | :--- | :--- | :--- |
| **+12V (VMS)** | Battery Positive (after fuse) | 11.1V–12.6V (LiPo) | Provide 100uF decoupling capacitor. |
| **GND** | Battery Negative & Common GND | 0V | Unified ground bus. |
| **+5V (Logic)** | Regulated 5V Rail | 5.0V DC | **Remove 5V Jumper** if VMS > 12V. |
| **ENA** | Hardwired Jumper to 5V | 5V HIGH | Speed controlled via IN1/IN2 PWM. |
| **ENB** | Hardwired Jumper to 5V | 5V HIGH | Speed controlled via IN3/IN4 PWM. |
| **OUT1 & OUT2**| Front-Left & Rear-Left BO Motors | Reversible 0–12V DC | Motors wired in parallel with matched polarity. |
| **OUT3 & OUT4**| Front-Right & Rear-Right BO Motors| Reversible 0–12V DC | Motors wired in parallel with matched polarity. |

---

## 2. Subsystem 2: Portable Robotic Arm (Arduino Uno #2 + L293D Shield)

### Microcontroller & Shield Pin Map
| Arduino / Shield Pin | Function | Associated Hardware | Operational Role |
| :--- | :--- | :--- | :--- |
| **Pin 0 (RX)** | Serial RX | HC-05 #2 TXD | Serial Bluetooth Command Link. |
| **Pin 1 (TX)** | Serial TX | HC-05 #2 RXD | Serial Telemetry & Acknowledgement. |
| **Shield Pins 4, 7, 8, 12** | 74HC595 Shift Reg | Internal to L293D Shield | Direction logic for all 4 H-bridge ports. |
| **Shield Pin 11 (PWM)** | Motor 1 Speed (M1) | Internal to L293D Shield | 30 RPM 12V Gear Motor (Waist Rotate L/R). |
| **Shield Pin 3 (PWM)** | Motor 2 Speed (M2) | Internal to L293D Shield | 10 RPM 12V Gear Motor (Shoulder Up/Down). |
| **Shield Pin 5 (PWM)** | Motor 3 Speed (M3) | Internal to L293D Shield | 10 RPM 12V Gear Motor (Elbow Up/Down). |
| **Shield Pin 6 (PWM)** | Motor 4 Speed (M4) | Internal to L293D Shield | Gripper DC Motor (Open/Close in DC Mode). |
| **Shield Pin 10 (SERVO1)** | Servo 1 Signal | MG946R Gripper Servo | Optional Servo Gripper Mode (Pin 10). |
| **EXT-PWR Terminal** | Motor Power Input | 11.1V LiPo Raw Rail | **Remove PWR Jumper**; do not power via USB! |

---

## 3. Subsystem 3: Colour-Sorting Conveyor (Arduino Uno #3 + L298N + Sensors)

### Resolved Conflict-Free Pin Map
| Arduino Pin | Hardware Interface | Connected Device | Voltage Level | Signal Type |
| :--- | :--- | :--- | :--- | :--- |
| **Pin 2** | Motor Direction IN1 | L298N IN1 | 5V TTL | Belt Forward Drive. |
| **Pin 3** | Motor Direction IN2 | L298N IN2 | 5V TTL | Belt Reverse Drive (Braking). |
| **Pin 9** | Motor Speed ENA | L298N ENA Terminal | 5V PWM | Conveyor Belt Speed (0–255). |
| **Pin 10** | Diverter Servo Signal| MG946R Signal (Orange)| 5V PPM | Diverter Chute Position (45°, 90°, 135°). |
| **Pin 7** | Optical Obstacle Sense | IR Proximity Sensor OUT | 5V Logic | Active LOW when parcel present. |
| **Pin 4** | Filter Select S2 | TCS3200 S2 Pin | 5V Logic | Photodiode matrix color select. |
| **Pin 5** | Filter Select S3 | TCS3200 S3 Pin | 5V Logic | Photodiode matrix color select. |
| **Pin 6** | Freq Scaling S0 | TCS3200 S0 Pin | 5V Logic | Set HIGH for 20% scaling mode. |
| **Pin 8** | Freq Scaling S1 | TCS3200 S1 Pin | 5V Logic | Set HIGH for 20% scaling mode. |
| **Pin 12** | Frequency Output OUT | TCS3200 OUT Pin | 5V Pulse Train | Sampled using `pulseIn()` function. |

> [!IMPORTANT]
> **Resolution of Pin 9 Conflict:**
> In the source report, Pin 9 was assigned to both the L298N ENA motor enable pin and the Servo signal pin. This created a dead short between motor driver PWM and servo control logic.
> **Engineered Fix:** Motor speed control remains on **Pin 9 (ENA)**. The MG946R diverter servo signal is relocated to **Pin 10**.

---

## 4. Subsystem 4: 3-Stage Transfer Conveyor (Arduino Uno #4 + L293D Shield)

### Resolved Shield-Safe Pin Map
| Arduino Pin | Designated Signal | Connected Sensor / Device | Resolution of Shield Conflict |
| :--- | :--- | :--- | :--- |
| **Analog Pin A0 (D14)** | Digital Input (Pullup) | IR Sensor 1 (Belt 1 Intake) | Relocated from Pin 2 to prevent bus conflict. |
| **Analog Pin A1 (D15)** | Digital Input (Pullup) | IR Sensor 2 (Belt 2 Transfer)| **Relocated from Pin 6** (Pin 6 was L293D M4 PWM!). |
| **Analog Pin A2 (D16)** | Digital Input (Pullup) | IR Sensor 3 (Belt 3 Discharge)| **Relocated from Pin 10** (Pin 10 was Servo 1 line!). |
| **Shield M1 Port** | DC Motor Output | Conveyor 1 BO Motor | Driven via AFMotor port 1. |
| **Shield M2 Port** | DC Motor Output | Conveyor 2 BO Motor | Driven via AFMotor port 2. |
| **Shield M3 Port** | DC Motor Output | Conveyor 3 BO Motor | Driven via AFMotor port 3. |

---

## 5. Subsystem 5: Surveillance Camera (AI-Thinker ESP32-CAM)

### Physical Module Pinout & Interfacing
| ESP32-CAM Pin | Peripheral / Signal | Connected Target | Notes |
| :--- | :--- | :--- | :--- |
| **5V** | Main Power In | Regulated 5V 2A Rail | **Must supply >=2A.** Brownout risk if below 4.75V. |
| **GND** | Power Ground | Common Ground Bus | Solid ground connection required. |
| **U0TXD (GPIO 1)** | Serial Programming TX | FTDI / USB-UART RXD | Used for debugging and firmware burning. |
| **U0RXD (GPIO 3)** | Serial Programming RX | FTDI / USB-UART TXD | Used for debugging and firmware burning. |
| **GPIO 0** | Boot Mode Select | Ground during flashing | Leave open/floating during normal operation. |
| **GPIO 4** | High-Power Flash LED | Internal MOSFET | Software controllable flash illuminator. |
| **GPIO 32** | Camera Power Control | Internal Camera LDO | Pulled LOW by camera driver to power sensor. |
| **Internal Pins** | OV2640 D0–D7, XCLK, PCLK, VSYNC, HREF, SIOD, SIOC | Camera Ribbon Cable | Standard AI-Thinker pinout matrix. |

---

## 6. Power Distribution and Grounding Architecture

```
                                  [+ 11.1V 3S LiPo Battery Pack]
                                                 |
                                         [10A Master Fuse]
                                                 |
                                     [Heavy-Duty Master Switch]
                                                 |
                 +-------------------------------+-------------------------------+
                 |                                                               |
                 v                                                               v
      [Raw 11.1V Motor Rail]                                     [DC-DC Buck Converter 5V 3A]
                 |                                                               |
     +-----------+-----------+                                       +-----------+-----------+
     |                       |                                       |                       |
     v                       v                                       v                       v
[L298N VMS Base]     [L293D EXT-PWR Arm]                     [5V Logic Bus]          [5V-6V Servo Bus]
(4x BO Motors)       (3x DC Gear Motors)                             |                       |
                                                 +-------------------+----+                  v
                                                 |         |         |    |            [MG946R Servos]
                                                 v         v         v    v
                                              [Uno 1]   [Uno 2]   [Uno 3] [Uno 4]
                                                 |         |         |    |
                                              [HC-05]   [HC-05]   [IR/TCS][ESP32-CAM]
                                                 |         |         |    |
=================================================+=========+=========+====+===================
                                      UNIFIED COMMON GROUND BUS (0V)
```
