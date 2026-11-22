# Hardware Setup and Assembly Guide

This guide details the physical assembly, wiring best practices, power tree distribution, and calibration sequence for the automation cell.

---

## 1. High-Current Battery & Power Tree Architecture

### 1.1 11.1V 3S LiPo Battery Handling (Orange 3S 2200mAh 30C)
> [!CAUTION]
> **LIPO PACK INTEGRITY AND SAFETY:**
> * Always check cell balance voltages before connecting. Nominal voltage: 3.7V/cell (11.1V pack). Fully charged: 4.2V/cell (12.6V pack).
> * **Never discharge below 3.3V/cell (9.9V pack total).** Deep discharge damages lithium polymer chemistry and can cause cell swelling or combustion.
> * Always charge in a fireproof LiPo safety bag using a balanced lithium charger (e.g. IMAX B6). Never exceed a 1C charge rate (2.2A).
> * Install a 10A automotive inline blade fuse immediately adjacent to the battery XT60 connector.

### 1.2 Step-by-Step Power Distribution Wiring
1. Connect battery negative to the master low-impedance ground distribution rail.
2. Connect battery positive through the 10A fuse to the master power toggle switch.
3. Split the switched +11.1V line into three dedicated branches:
   * **Branch A (Raw Motor Rail):** Directly to the `+12V` screw terminal of the Base L298N driver and the `EXT-PWR` terminal of the Arm L293D shield.
   * **Branch B (Logic Buck Converter):** To the input of an LM2596 switching DC-DC regulator calibrated with a multimeter to deliver **exactly 5.05V DC** to the logic bus (Arduinos, HC-05 modules, ESP32-CAM).
   * **Branch C (High-Current Servo Buck Converter):** To a secondary buck converter supplying **5.5V–6.0V DC** dedicated to the MG946R servo motors (avoids servo current dips resetting the microcontrollers).

---

## 2. Subsystem Mechanical & Electrical Assembly

### 2.1 Robotic Base Assembly
1. Mount four 100 RPM BO geared motors to the acrylic/aluminum mobile chassis.
2. Solder 0.1uF ceramic noise-suppression capacitors across the motor terminals.
3. Connect the two left-side motors in parallel to L298N `OUT1` and `OUT2`.
4. Connect the two right-side motors in parallel to L298N `OUT3` and `OUT4`.
5. Connect L298N `IN1`, `IN2`, `IN3`, and `IN4` to Arduino Uno #1 Pins 5, 6, 10, and 11.
6. Connect HC-05 module #1 to Arduino Pins 0 and 1 via a 1k/2k voltage divider on the Arduino TX line.

### 2.2 Robotic Arm Assembly
1. Secure the base rotation turret driven by the 30 RPM centre-shaft gear motor.
2. Mount the primary shoulder arm link driven by the first 10 RPM high-torque gear motor.
3. Mount the elbow/forearm link driven by the second 10 RPM gear motor.
4. Mount the gripper end-effector assembly (either rack/pinion DC motor or MG946R servo).
5. Seat the Adafruit L293D Motor Shield firmly on Arduino Uno #2. Ensure `EXT-PWR` jumper is **removed**.
6. Wire waist motor to `M1`, shoulder to `M2`, elbow to `M3`, and gripper to `M4` (or Servo 1 header).

### 2.3 Colour-Sorting Conveyor Assembly
1. Mount the conveyor belt frame with the 100 RPM BO drive roller at the drive end.
2. Position the IR optical obstacle sensor across the belt at the inspection staging gate.
3. Mount the TCS3200 sensor module enclosed in a lightweight black shroud to shield it from ambient room lighting variations.
4. Mount the MG946R sorting diverter servo downstream of the inspection gate with the diverter arm sweeping cleanly across the belt surface into the 3 sorting chutes.

---

## 3. Optical Sensor Calibration Procedure (TCS3200)

Because ambient room lighting, sensor mounting distance, and target material reflectivity vary significantly:
1. Power up Subsystem 3 with the serial monitor connected @ 9600 baud.
2. Place a matte white calibration card 20mm directly below the TCS3200 aperture.
3. Record raw frequency readings for Red, Green, and Blue filter channels.
4. Repeat with a matte black reference card to establish the optical dynamic range.
5. Present reference sample tokens (Red, Green, Blue) to register the nominal frequency ranges for sorting.
6. Store or calibrate threshold values directly in `firmware/colour_sorting_conveyor/colour_sorting_conveyor.ino`.
