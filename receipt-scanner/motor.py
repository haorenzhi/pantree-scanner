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
    from gpiozero import OutputDevice
except ImportError:
    OutputDevice = None

try:
    import RPi.GPIO as GPIO
except ImportError:
    GPIO = None

# --- Pin assignments (BCM) ---
STEP_PIN = 17
DIR_PIN = 27
ENABLE_PIN = 22

ALL_MOTOR_PINS = [STEP_PIN, DIR_PIN, ENABLE_PIN]

_backend = None
_step_device = None
_dir_device = None
_enable_device = None

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
    global _backend, _step_device, _dir_device, _enable_device

    if OutputDevice is not None:
        try:
            _step_device = OutputDevice(STEP_PIN, active_high=True, initial_value=False)
            _dir_device = OutputDevice(DIR_PIN, active_high=True, initial_value=False)
            # ENABLE is active-LOW: active_high=False means .on() drives LOW.
            _enable_device = OutputDevice(ENABLE_PIN, active_high=False, initial_value=True)
            _backend = "gpiozero"
            print("[motor] Easy Driver initialized via gpiozero/lgpio (STEP=17, DIR=27, EN=22)")
            return True
        except Exception as e:
            print(f"[motor] gpiozero init failed: {e}")
            _step_device = None
            _dir_device = None
            _enable_device = None

    if GPIO is not None:
        try:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            # STEP and DIR as outputs, default LOW
            GPIO.setup(STEP_PIN, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(DIR_PIN, GPIO.OUT, initial=GPIO.LOW)
            # ENABLE active-LOW: set LOW to enable the driver
            GPIO.setup(ENABLE_PIN, GPIO.OUT, initial=GPIO.LOW)
            _backend = "rpi_gpio"
            print("[motor] Easy Driver initialized via RPi.GPIO (STEP=17, DIR=27, EN=22)")
            return True
        except Exception as e:
            print(f"[motor] RPi.GPIO init failed: {e}")

    print("[motor] No GPIO backend available (install python3-gpiozero python3-lgpio)")
    return False


def enable_motor():
    """Enable the Easy Driver (active-LOW)."""
    if _backend == "gpiozero" and _enable_device is not None:
        _enable_device.on()
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(ENABLE_PIN, GPIO.LOW)


def disable_motor():
    """Disable the Easy Driver to save power and reduce heat."""
    if _backend == "gpiozero" and _enable_device is not None:
        _enable_device.off()
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(ENABLE_PIN, GPIO.HIGH)


def cleanup_motor():
    """Disable driver and release GPIO pins."""
    global _backend, _step_device, _dir_device, _enable_device
    try:
        disable_motor()
        if _backend == "gpiozero":
            for device in (_step_device, _dir_device, _enable_device):
                if device is not None:
                    device.close()
        elif _backend == "rpi_gpio" and GPIO is not None:
            GPIO.output(STEP_PIN, GPIO.LOW)
            GPIO.output(DIR_PIN, GPIO.LOW)
            GPIO.cleanup(ALL_MOTOR_PINS)
    except RuntimeError:
        # Pins were never set up — nothing to clean
        pass
    finally:
        _backend = None
        _step_device = None
        _dir_device = None
        _enable_device = None


def feed_steps(steps, delay=DEFAULT_STEP_DELAY):
    """
    Advance the receipt by a given number of microsteps.
    Positive = feed forward, negative = reverse.
    """
    if _backend is None:
        print(f"[motor] Simulating {steps} microsteps")
        return

    # Set direction
    if _backend == "gpiozero" and _dir_device is not None:
        _dir_device.on() if steps > 0 else _dir_device.off()
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(DIR_PIN, GPIO.HIGH if steps > 0 else GPIO.LOW)

    # Pulse the STEP pin
    pause = max(delay - PULSE_WIDTH, PULSE_WIDTH)
    for _ in range(abs(steps)):
        if _backend == "gpiozero" and _step_device is not None:
            _step_device.on()
        elif _backend == "rpi_gpio" and GPIO is not None:
            GPIO.output(STEP_PIN, GPIO.HIGH)
        time.sleep(PULSE_WIDTH)
        if _backend == "gpiozero" and _step_device is not None:
            _step_device.off()
        elif _backend == "rpi_gpio" and GPIO is not None:
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
