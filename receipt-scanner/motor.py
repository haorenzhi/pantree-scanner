"""
Stepper motor control for receipt feeder.

Controls a 28BYJ-48 stepper motor via ULN2003 driver board
to scroll a receipt past the camera.

GPIO pin mapping (active BCM pins):
  IN1 -> GPIO 17
  IN2 -> GPIO 18
  IN3 -> GPIO 27
  IN4 -> GPIO 22
"""

import time

try:
    import RPi.GPIO as GPIO
except ImportError:
    GPIO = None

# GPIO pins connected to ULN2003 IN1-IN4
MOTOR_PINS = [17, 18, 27, 22]

# Half-step sequence for smoother motion
STEP_SEQUENCE = [
    [1, 0, 0, 0],
    [1, 1, 0, 0],
    [0, 1, 0, 0],
    [0, 1, 1, 0],
    [0, 0, 1, 0],
    [0, 0, 1, 1],
    [0, 0, 0, 1],
    [1, 0, 0, 1],
]

# 28BYJ-48 specs: 4096 half-steps per revolution, ~6cm roller circumference
STEPS_PER_MM = 4096 / 60  # ~68 steps per mm of paper travel
DEFAULT_STEP_DELAY = 0.001  # seconds between steps (~5mm/s feed rate)


def init_motor():
    """Initialize GPIO pins for motor control."""
    if GPIO is None:
        print("[motor] RPi.GPIO not available (not running on Pi)")
        return False
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    for pin in MOTOR_PINS:
        GPIO.setup(pin, GPIO.OUT)
        GPIO.output(pin, 0)
    return True


def cleanup_motor():
    """Release GPIO pins."""
    if GPIO is None:
        return
    for pin in MOTOR_PINS:
        GPIO.output(pin, 0)
    GPIO.cleanup(MOTOR_PINS)


def feed_steps(steps, delay=DEFAULT_STEP_DELAY):
    """
    Advance the receipt by a given number of half-steps.
    Positive = feed forward, negative = reverse.
    """
    if GPIO is None:
        print(f"[motor] Simulating {steps} steps")
        return

    direction = 1 if steps > 0 else -1
    seq = STEP_SEQUENCE if direction == 1 else list(reversed(STEP_SEQUENCE))

    for i in range(abs(steps)):
        phase = seq[i % len(seq)]
        for pin_idx, pin in enumerate(MOTOR_PINS):
            GPIO.output(pin, phase[pin_idx])
        time.sleep(delay)

    # De-energize coils to prevent heating
    for pin in MOTOR_PINS:
        GPIO.output(pin, 0)


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
