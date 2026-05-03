"""
Stepper motor control for receipt feeder.

Controls a NEMA 17 stepper motor via Easy Driver (A3967) board
using STEP/DIR pulse interface to scroll a receipt past the camera.

Easy Driver wiring (BCM pins):
  STEP   -> GPIO 17   (pulse rising-edge = one microstep)
  DIR    -> GPIO 27   (HIGH = forward, LOW = reverse)
  ENABLE -> GPIO 22   (active-LOW: LOW = enabled, HIGH = disabled/sleep)

Easy Driver defaults to 1/8 microstepping (MS1=HIGH, MS2=HIGH).
  NEMA 17 = 200 full steps/rev  ->  1600 microsteps/rev at 1/8.

Power: 12V supply to Easy Driver M+ / GND. Pi 5V NOT connected to driver.
"""

import time

try:
    import RPi.GPIO as GPIO
except ImportError:
    GPIO = None

# --- Pin assignments (BCM) ---
STEP_PIN = 17
DIR_PIN = 27
ENABLE_PIN = 22

ALL_MOTOR_PINS = [STEP_PIN, DIR_PIN, ENABLE_PIN]

# --- Motor / mechanical constants ---
FULL_STEPS_PER_REV = 200          # NEMA 17 standard
MICROSTEP_DIVISOR = 8             # Easy Driver default (1/8)
MICROSTEPS_PER_REV = FULL_STEPS_PER_REV * MICROSTEP_DIVISOR  # 1600

# Roller circumference — adjust to your actual roller diameter.
# Default assumes ~20mm diameter roller -> C = π * 20 ≈ 62.8mm
ROLLER_CIRCUMFERENCE_MM = 62.8
STEPS_PER_MM = MICROSTEPS_PER_REV / ROLLER_CIRCUMFERENCE_MM  # ~25.5

# Pulse timing — total cycle = delay per step.
# 0.001s (1ms) per microstep -> ~1600ms/rev -> ~39 mm/s
# 0.002s (2ms) per microstep -> ~5 mm/s (matches original feed rate)
DEFAULT_STEP_DELAY = 0.002  # seconds per microstep (~5 mm/s)

# Easy Driver minimum pulse width is ~1μs; we use 50μs for safety.
PULSE_WIDTH = 0.00005  # 50 μs HIGH pulse


def init_motor():
    """Initialize GPIO pins for Easy Driver motor control."""
    if GPIO is None:
        print("[motor] RPi.GPIO not available (not running on Pi)")
        return False
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    # STEP and DIR as outputs, default LOW
    GPIO.setup(STEP_PIN, GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(DIR_PIN, GPIO.OUT, initial=GPIO.LOW)
    # ENABLE active-LOW: set LOW to enable the driver
    GPIO.setup(ENABLE_PIN, GPIO.OUT, initial=GPIO.LOW)
    print("[motor] Easy Driver initialized (STEP=17, DIR=27, EN=22)")
    return True


def enable_motor():
    """Enable the Easy Driver (active-LOW)."""
    if GPIO is None:
        return
    GPIO.output(ENABLE_PIN, GPIO.LOW)


def disable_motor():
    """Disable the Easy Driver to save power and reduce heat."""
    if GPIO is None:
        return
    GPIO.output(ENABLE_PIN, GPIO.HIGH)


def cleanup_motor():
    """Disable driver and release GPIO pins."""
    if GPIO is None:
        return
    try:
        disable_motor()
        GPIO.output(STEP_PIN, GPIO.LOW)
        GPIO.output(DIR_PIN, GPIO.LOW)
        GPIO.cleanup(ALL_MOTOR_PINS)
    except RuntimeError:
        # Pins were never set up — nothing to clean
        pass


def feed_steps(steps, delay=DEFAULT_STEP_DELAY):
    """
    Advance the receipt by a given number of microsteps.
    Positive = feed forward, negative = reverse.
    """
    if GPIO is None:
        print(f"[motor] Simulating {steps} microsteps")
        return

    # Set direction
    GPIO.output(DIR_PIN, GPIO.HIGH if steps > 0 else GPIO.LOW)

    # Pulse the STEP pin
    pause = max(delay - PULSE_WIDTH, PULSE_WIDTH)
    for _ in range(abs(steps)):
        GPIO.output(STEP_PIN, GPIO.HIGH)
        time.sleep(PULSE_WIDTH)
        GPIO.output(STEP_PIN, GPIO.LOW)
        time.sleep(pause)


def feed_mm(mm, delay=DEFAULT_STEP_DELAY):
    """Advance the receipt by a given distance in millimeters."""
    steps = int(mm * STEPS_PER_MM)
    feed_steps(steps, delay)


def feed_receipt_segment(segment_height_mm=30):
    """
    Feed one camera-frame worth of receipt paper.
    Default segment is 30mm to allow ~20% overlap between frames.
    """
    feed_mm(segment_height_mm)
