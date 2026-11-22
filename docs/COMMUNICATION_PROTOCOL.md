# Communication Protocol Specification

This document defines the serial and network protocols connecting the operator interface (Android App / Web Console) with the embedded microcontroller network.

---

## 1. Physical Layer and Topology

### 1.1 Bluetooth Serial (HC-05 Modules)
* **Transport:** Bluetooth v2.0+EDR (Classic Bluetooth) via Serial Port Profile (SPP / RFCOMM).
* **Baud Rate:** 9600 bps.
* **Data Frame:** 8 data bits, no parity, 1 stop bit (`9600-8-N-1`), no hardware flow control.
* **Connection Architecture:**
  * Handset establishes an independent RFCOMM connection to the target subsystem's HC-05 module:
    * **Target 1:** Mobile Base Controller (`HC-05-BASE`)
    * **Target 2:** Robotic Arm Controller (`HC-05-ARM`)
  * If the mobile device or operating system does not support simultaneous dual RFCOMM connections, the application supports seamless channel multiplexing and switching from the dashboard.

### 1.2 Video Streaming Network (ESP32-CAM)
* **Transport:** IEEE 802.11 b/g/n Wi-Fi @ 2.4 GHz.
* **Protocol:** HTTP 1.1 Multipart Server (`multipart/x-mixed-replace; boundary=123456789000000000000987654321`).
* **Endpoints:**
  * `GET /`: HTML Web view & camera configuration console.
  * `GET :81/stream`: Raw MJPEG video stream (compatible with Flutter `Image.network` or web viewer).
  * `GET /control?var=flash&val=[0|1]`: Toggle flash illuminator LED.
  * `GET /status`: JSON camera telemetry and sensor diagnostics.

---

## 2. Command Protocol: Portable Robotic Base

The robotic base accepts single-character ASCII command tokens as well as structured newline-terminated strings.

### 2.1 Motion Command Set
| Command Byte | Action | IN1 (Pin 5) | IN2 (Pin 6) | IN3 (Pin 10) | IN4 (Pin 11) | Description |
| :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| `'F'` | Forward | PWM (Speed) | 0 | PWM (Speed) | 0 | Both left and right wheels drive forward. |
| `'B'` | Backward | 0 | PWM (Speed) | 0 | PWM (Speed) | Both left and right wheels drive reverse. |
| `'L'` | Pivot Left | 0 | PWM (Speed) | PWM (Speed) | 0 | Left wheels reverse, right wheels forward. |
| `'R'` | Pivot Right | PWM (Speed) | 0 | 0 | PWM (Speed) | Left wheels forward, right wheels reverse. |
| `'G'` | Forward-Left | PWM (Speedsec)| 0 | PWM (Speed) | 0 | Left wheels slow/stop, right wheels forward. |
| `'I'` | Forward-Right| PWM (Speed) | 0 | PWM (Speedsec)| 0 | Left wheels forward, right wheels slow/stop. |
| `'H'` | Back-Left | 0 | PWM (Speedsec)| 0 | PWM (Speed) | Left wheels reverse slowly, right reverse. |
| `'J'` | Back-Right | 0 | PWM (Speed) | 0 | PWM (Speedsec)| Left wheels reverse, right reverse slowly. |
| `'S'` | Emergency Stop| 0 | 0 | 0 | 0 | Activates dynamic electronic brake pulse, then idles. |

### 2.2 Velocity Configuration
* Commands `'0'` through `'9'` adjust base velocity in 10% increments ($PWM = \text{val} \times 28$, where `'9'` = 255 max speed).
* Alternatively, sending framed string `V<value>\n` (e.g. `V204\n`) sets the explicit 8-bit PWM speed (0–255).

### 2.3 Base Controller Telemetry & Acknowledgement
When a valid command is received, the base controller transmits an immediate acknowledgement frame:
* `ACK:F,SPEED:204\r\n`
* `ACK:STOP,BRAKE:ON\r\n`
* `ERR:UNKNOWN_CMD\r\n`

---

## 3. Command Protocol: Portable Robotic Arm

The robotic arm controller drives three high-torque joint gear motors and an end-effector gripper.

### 3.1 Joint Motion Command Set
| Command Byte | Target Joint | Motor Port | Direction | Action Summary |
| :---: | :--- | :---: | :---: | :--- |
| `'U'` | Shoulder Elevation | M2 | FORWARD | Arm lifts upwards against gravity. |
| `'D'` | Shoulder Lowering | M2 | BACKWARD | Arm lowers downwards. |
| `'L'` | Base / Waist Turret | M1 | BACKWARD | Turret rotates counter-clockwise (Left). |
| `'R'` | Base / Waist Turret | M1 | FORWARD | Turret rotates clockwise (Right). |
| `'T'` | Elbow / Wrist Joint| M3 | FORWARD | Forearm / wrist articulates upwards (Top Up). |
| `'t'` | Elbow / Wrist Joint| M3 | BACKWARD | Forearm / wrist articulates downwards (Top Down). |
| `'O'` | End-Effector Gripper| M4 / S1 | FORWARD / 120° | Gripper jaws open to release payload. |
| `'C'` | End-Effector Gripper| M4 / S1 | BACKWARD / 30° | Gripper jaws close to clamp object. |
| `'S'` | Master Arm Halt | ALL | RELEASE | All arm motors immediately de-energized. |

### 3.2 Safety Timeout Interlock
To protect the gearboxes against mechanical binding and stall current:
* Joint motion commands automatically time out after **3000 ms** if no subsequent keep-alive or directional byte is received.
* Software limits prevent sustained reverse drive beyond mechanical limits.

---

## 4. Conveyor & Optical Sorting Protocol

### 4.1 Telemetry Frames (Transmitted via Serial)
When the Colour-Sorting Conveyor or 3-Stage Transfer system operates, status frames are emitted to the serial bus:

| Event | Serial Output String | Explanation |
| :--- | :--- | :--- |
| **Object Detected** | `EVT:OBJ_DETECTED,POS:STAGE_1\r\n` | IR obstacle sensor triggered. |
| **Colour Classification**| `EVT:COLOR,R:125,G:48,B:32,MATCH:RED\r\n` | Optical spectrum result from TCS3200. |
| **Diverter Angle** | `EVT:DIVERT,ANGLE:45,BIN:RED\r\n` | MG946R servo diverter moved. |
| **Conveyor Status** | `STA:CONV1:RUN,CONV2:IDLE,CONV3:RUN\r\n`| Real-time state of 3-conveyor arrangement.|

### 4.2 Calibration Command Mode
Sending `CAL:WHITE\n`, `CAL:BLACK\n`, or `CAL:TEST\n` to the sorting Arduino initiates the optical calibration routine, outputting raw frequency metrics for threshold tuning.
