# Troubleshooting and Field Engineering Diagnostics

This guide provides structured root-cause fault finding procedures for hardware, embedded firmware, wireless networking, and mobile application faults.

---

## 1. Power and Brownout Diagnostics

### Symptom: ESP32-CAM resets continuously ("Brownout detector was triggered")
* **Root Cause:** When the ESP32 Wi-Fi radio initiates a packet burst, transient current spikes can exceed 350–500mA. If the 5V power supply has high internal resistance or the wire gauge is too thin, the VCC voltage sags below 4.5V, tripping the internal silicon brownout detector.
* **Remedy:**
  1. Do not power ESP32-CAM from the Arduino 5V header pin or the L298N on-board 78M05 regulator.
  2. Use a dedicated 5V 2A switching DC-DC buck converter.
  3. Solder a 470uF or 1000uF low-ESR electrolytic capacitor across the 5V and GND pins of the ESP32-CAM module.

### Symptom: Arduino Uno resets whenever a DC motor starts moving
* **Root Cause:** Motor inrush current creates an inductive voltage dip on the shared battery rail, or electromagnetic back-EMF couples into the Arduino reset circuit.
* **Remedy:**
  1. Verify motor power and Arduino logic power are separated (remove L293D shield `PWR` jumper; remove L298N 5V jumper).
  2. Solder a 0.1uF ceramic capacitor directly across each DC motor's positive and negative terminals.
  3. Ensure a star-ground configuration rather than daisy-chaining ground wires through breadboard strips.

---

## 2. Bluetooth and Serial Diagnostics

### Symptom: Arduino sketch will not upload ("avrdude: stk500_recv(): programmer is not responding")
* **Root Cause:** The HC-05 Bluetooth module is connected to digital Pins 0 (RX) and 1 (TX). The ATmega16U2 USB-to-serial converter shares these exact pins. The HC-05 contention prevents the bootloader from communicating with the computer.
* **Remedy:**
  1. Temporarily unplug the HC-05 `VCC` or disconnect the wires from Pins 0 and 1 while uploading code via USB.
  2. Reconnect the Bluetooth module once uploading completes.

### Symptom: Mobile app connects to HC-05, but robot does not respond to commands
* **Root Cause:** Inverted TX/RX connections, incorrect baud rate, or HC-05 in AT command mode.
* **Remedy:**
  1. Ensure HC-05 `TXD` connects to Arduino `Pin 0 (RX)`.
  2. Ensure HC-05 `RXD` connects to Arduino `Pin 1 (TX)`.
  3. Confirm the sketch initializes serial with `Serial.begin(9600);`.
  4. Ensure the HC-05 LED blinks with a fast double-flash (paired state) rather than a slow 2-second blink (AT command mode).

---

## 3. Optical Sensor & Sorting Diagnostics

### Symptom: Colour-Sorting Conveyor detects object but always sorts as "Unknown" or wrong colour
* **Root Cause:** Ambient room lighting (fluorescent or sunlight) saturated the photodiodes, or color frequency thresholds are uncalibrated for the physical target material.
* **Remedy:**
  1. Fit an opaque black shroud around the TCS3200 sensor head, positioning the sensor approximately 15mm–25mm from the passing parcel.
  2. Execute the optical calibration procedure described in `docs/HARDWARE_SETUP.md`.
  3. Verify that the four white illumination LEDs on the TCS3200 are illuminated.

---

## 4. Servo Motor Jitter and Freezing

### Symptom: MG946R servo twitches erratically or causes Arduino to hang
* **Root Cause:** High stall current (up to 1.2A) exceeding the current capability of the microcontroller supply, or timer conflict between the `Servo` library and PWM pins.
* **Remedy:**
  1. Ensure the servo is powered from a dedicated 5V–6V high-current buck converter, not the Arduino 5V regulator pin.
  2. Confirm the servo ground is tied to the common ground plane.
  3. Ensure servo signal pin is assigned to a non-conflicting pin (Pin 10 or Pin 4), and not sharing Pin 9 with the conveyor motor PWM.
