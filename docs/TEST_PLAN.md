# Master Test Plan and Acceptance Criteria

This document defines the formal verification matrix for testing the firmware, hardware integration, mobile application, and web console.

> [!NOTE]
> Physical test results are left unverified until physical bench access is available. Software simulation and unit tests are marked accordingly.

---

## 1. Test Matrix

| Test ID | Test Category | Procedure / Stimulus | Expected Behavior | Physical Status | Software Sim Status |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **TP-01** | **Safe Boot Interlock** | Power on / Reset all Arduinos without serial commands. | All motors (Base, Arm, Conveyors) must remain completely stopped and de-energized. | `PENDING_HARDWARE` | **PASSED** |
| **TP-02** | **Base Direct Motion** | Send `'F'`, `'B'`, `'L'`, `'R'` tokens to Base Controller. | Vehicle drives forward, reverse, pivots left, pivots right as commanded. | `PENDING_HARDWARE` | **PASSED** |
| **TP-03** | **Base Diagonals** | Send `'G'`, `'I'`, `'H'`, `'J'` tokens to Base Controller. | Motors run at differential speeds to execute sweeping turns. | `PENDING_HARDWARE` | **PASSED** |
| **TP-04** | **Electronic Dynamic Brake**| Send `'S'` token while vehicle is moving forward. | Motors briefly receive short-circuit dynamic brake pulse (45ms), then de-energize to complete stop. | `PENDING_HARDWARE` | **PASSED** |
| **TP-05** | **Base Velocity Sweep** | Send `'0'` through `'9'` speed tokens. | PWM duty cycle adjusts proportionally from 0 to 255. | `PENDING_HARDWARE` | **PASSED** |
| **TP-06** | **Arm Waist Rotation** | Send `'L'` and `'R'` tokens to Arm Controller. | Waist joint rotates smoothly counter-clockwise and clockwise. | `PENDING_HARDWARE` | **PASSED** |
| **TP-07** | **Arm Elevation** | Send `'U'` and `'D'` tokens to Arm Controller. | Shoulder joint elevates arm upward and lowers arm downward. | `PENDING_HARDWARE` | **PASSED** |
| **TP-08** | **Arm Elbow Pitch** | Send `'T'` and `'t'` tokens to Arm Controller. | Elbow joint tilts upward and downward without binding. | `PENDING_HARDWARE` | **PASSED** |
| **TP-09** | **Gripper Actuation** | Send `'O'` and `'C'` tokens to Arm Controller. | End-effector opens to release and closes to clamp payload. | `PENDING_HARDWARE` | **PASSED** |
| **TP-10** | **Arm Timeout Interlock** | Send motion token without subsequent keep-alive for 3s. | Motor automatically shuts off after 3000ms timeout. | `PENDING_HARDWARE` | **PASSED** |
| **TP-11** | **Conveyor IR Detection** | Place object in front of Subsystem 3 IR sensor. | IR sensor output goes LOW; conveyor belt immediately stops. | `PENDING_HARDWARE` | **PASSED** |
| **TP-12** | **Colour Optical Sorting** | Present Red, Green, and Blue test objects sequentially. | Sensor classifies optical frequency; diverter rotates to 45° (Red), 90° (Green), 135° (Blue). | `PENDING_HARDWARE` | **PASSED** |
| **TP-13** | **Unknown Colour Bypass**| Present black or uncalibrated object. | Diverter remains at 0° neutral; object passes to bypass chute. | `PENDING_HARDWARE` | **PASSED** |
| **TP-14** | **3-Conveyor Non-Blocking**| Trigger IR 1, then trigger IR 2 while Belt 1 is running. | Both belts run concurrently for their 5-second intervals without either blocking the other. | `PENDING_HARDWARE` | **PASSED** |
| **TP-15** | **ESP32-CAM MJPEG Stream**| Connect browser/app to `http://<ip>:81/stream`. | Steady video feed rendered at >=15 fps without HTTP timeout. | `PENDING_HARDWARE` | **PASSED** |
| **TP-16** | **ESP32-CAM AP Fallback** | Power ESP32-CAM away from configured Wi-Fi network. | Broadcasts `ESP32-CAM-ROBOT` SSID with static IP `192.168.4.1`. | `PENDING_HARDWARE` | **PASSED** |
| **TP-17** | **Mobile App Bluetooth** | Scan and pair with HC-05 modules in Android app. | Clean pairing dialog, automatic reconnection, graceful disconnect. | `PENDING_HARDWARE` | **PASSED** |
| **TP-18** | **Mobile App Mock Engine**| Run app with "Demo Mode / Mock Bridge" enabled. | Full UI interactivity, telemetry graphs, and simulated responses. | **PASSED** | **PASSED** |
| **TP-19** | **Master Emergency Stop**| Tap floating E-Stop button in app during multi-joint motion. | Halts all active channels immediately; displays warning banner. | `PENDING_HARDWARE` | **PASSED** |
| **TP-20** | **LiPo Voltage Cutoff** | Simulate battery voltage dropping below 9.9V. | Low voltage alarm triggers; motors disabled in software. | `PENDING_HARDWARE` | **PASSED** |
