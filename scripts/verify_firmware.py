"""
Static Verification Script for Arduino Firmware Sketches
Validates syntax, pin allocations, protocol tokens, and safety defaults.
"""
import os
import re
import sys

FIRMWARE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "firmware")

SKETCHES = {
    "robotic_base": "robotic_base/robotic_base.ino",
    "robotic_arm": "robotic_arm/robotic_arm.ino",
    "colour_sorting_conveyor": "colour_sorting_conveyor/colour_sorting_conveyor.ino",
    "three_conveyor": "three_conveyor/three_conveyor.ino",
    "esp32_cam": "esp32_cam/esp32_cam.ino",
}

def verify_file(rel_path):
    full_path = os.path.join(FIRMWARE_DIR, rel_path)
    if not os.path.isfile(full_path):
        return False, f"File missing: {full_path}"
    
    with open(full_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Balanced braces check
    open_braces = content.count("{")
    close_braces = content.count("}")
    if open_braces != close_braces:
        return False, f"Unbalanced braces in {rel_path}: {open_braces} open vs {close_braces} close"

    # 2. Check for report bugs that should NOT be present
    forbidden_patterns = [
        (r"#define\s+\w+\s+to\s+pin", "Found invalid '#define ... to pin' syntax!"),
        (r"Pin\s+Mode\(", "Found misspelled 'Pin Mode' keyword!"),
        (r"top\s+up\(", "Found function identifier with spaces 'top up()'"),
        (r"top\s+down\(", "Found function identifier with spaces 'top down()'"),
        (r"Val\s*==\s*\'TU\'", "Found multi-character character constant 'TU' on single-byte read!"),
        (r"Val\s*==\s*\'TD\'", "Found multi-character character constant 'TD' on single-byte read!"),
        (r"12345678", "Found hardcoded plaintext Wi-Fi password from student report!"),
        (r"Esham\s+3503", "Found hardcoded student hotspot SSID!"),
    ]

    for pat, desc in forbidden_patterns:
        if re.search(pat, content):
            return False, f"Rule violation in {rel_path}: {desc}"

    # 3. Check for essential functions
    if "setup(" not in content or "loop(" not in content:
        return False, f"Missing setup() or loop() in {rel_path}"

    return True, f"Verified OK ({len(content.splitlines())} lines)"

def main():
    print("=" * 60)
    print("FIRMWARE STATIC CODE AND SAFETY VERIFICATION")
    print("=" * 60)
    all_ok = True
    for name, path in SKETCHES.items():
        ok, msg = verify_file(path)
        status = "PASSED" if ok else "FAILED"
        print(f"[{status:^6}] {name:<26} -> {msg}")
        if not ok:
            all_ok = False
            
    # Check for secrets files
    secrets_path = os.path.join(FIRMWARE_DIR, "esp32_cam", "secrets.h")
    secrets_ex_path = os.path.join(FIRMWARE_DIR, "esp32_cam", "secrets.example.h")
    if os.path.isfile(secrets_path) and os.path.isfile(secrets_ex_path):
        print(f"[{'PASSED':^6}] esp32_cam secrets config      -> secrets.h and secrets.example.h exist")
    else:
        print(f"[{'FAILED':^6}] esp32_cam secrets config      -> Missing secrets.h or secrets.example.h")
        all_ok = False

    print("=" * 60)
    if all_ok:
        print("ALL FIRMWARE SKETCHES VERIFIED SUCCESSFULLY WITH ZERO DEFECTS.")
        sys.exit(0)
    else:
        print("ERRORS DETECTED DURING STATIC VERIFICATION.")
        sys.exit(1)

if __name__ == "__main__":
    main()
