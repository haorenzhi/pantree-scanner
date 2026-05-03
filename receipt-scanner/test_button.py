#!/usr/bin/env python3
"""Quick test: is the scan button wired correctly on GPIO 23?
Uses gpiozero (works on Trixie / kernel 6.12+).
"""

from gpiozero import Button
import time

BUTTON_PIN = 23  # Physical Pin 16

btn = Button(BUTTON_PIN, pull_up=True, bounce_time=0.05)

print("=" * 40)
print("  Button Wiring Test — GPIO 23 (Pin 16)")
print("=" * 40)
print()

print(f"is_pressed: {btn.is_pressed}")
print(f"value: {btn.value}")
print(f"pin state: {'PRESSED (LOW)' if btn.is_pressed else 'NOT PRESSED (HIGH) -- good!'}")
print()

if btn.is_pressed:
    print("WARNING: Button reads as pressed without pressing!")
    print("  1. Is main.py still running? Kill it first: pkill -f main.py")
    print("  2. Check wiring: Pin 14 (GND) and Pin 16 (GPIO 23)")
    btn.close()
    exit(1)

print("Polling button state for 20 seconds...")
print("Press the button — you should see the state change.")
print()

try:
    count = 0
    start = time.time()
    was_pressed = False
    while time.time() - start < 20 and count < 3:
        if btn.is_pressed and not was_pressed:
            count += 1
            print(f"  Press #{count} detected! (is_pressed={btn.is_pressed}, value={btn.value})")
            was_pressed = True
        elif not btn.is_pressed and was_pressed:
            was_pressed = False
        time.sleep(0.05)

    if count == 0:
        elapsed = time.time() - start
        print(f"No presses detected in {elapsed:.0f}s.")
        print()
        print("Debugging: reading raw pin value 5 times (press button during this)...")
        for i in range(5):
            print(f"  [{i+1}] is_pressed={btn.is_pressed}, value={btn.value}")
            time.sleep(1)
    elif count < 3:
        print(f"Only {count}/3 presses detected before timeout.")
    else:
        print()
        print("All 3 presses detected! Button is wired correctly.")
        print("You can now run: python main.py")

except KeyboardInterrupt:
    print("\nStopped by user.")
finally:
    btn.close()
