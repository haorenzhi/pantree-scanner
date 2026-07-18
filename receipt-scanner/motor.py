"""
Motor control for receipt feeder.

Supported modes:
    1. STEP/DIR stepper driver (A3967/Easy Driver, STSPIN220, etc.)
    2. DRV8833 H-bridge with a 2-wire DC right-angle gear motor

Default mode is STEP/DIR. Select DRV8833 with:
    python main.py --motor-driver drv8833

DRV8833 wiring for one motor on channel A:
    AIN1 / IN1 / A1  -> GPIO 22   (physical pin 15)
    AIN2 / IN2 / A2  -> GPIO 27   (physical pin 13)
    SLEEP / nSLEEP   -> not used by default; tie to 3.3V only if your board exposes it
    GND              -> Pi GND + external motor supply GND
    VM / VIN         -> external motor supply + (match motor voltage)
    AOUT1/AO1/OUT1   -> motor wire 1
    AOUT2/AO2/OUT2   -> motor wire 2

Never power the motor from a Pi GPIO pin. Pi GPIO logic is 3.3V only.
"""

import os
import time

try:
    from gpiozero import OutputDevice, PWMOutputDevice
except ImportError:
    OutputDevice = None
    PWMOutputDevice = None

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
_motor_driver = None
_step_device = None
_dir_device = None
_enable_device = None
_dc_in1_device = None
_dc_in2_device = None
_dc_sleep_device = None
_active_motor_pins = []

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

# Timed feed calibration for a 2-wire DC gear motor on DRV8833.
# Increase/decrease after measuring how far your roller moves in 1 second.
DC_FEED_MM_PER_SECOND = float(os.getenv("PANTREE_DC_FEED_MM_PER_SECOND", "20"))
DC_DEFAULT_SPEED = float(os.getenv("PANTREE_DC_SPEED", "0.55"))
DC_IN1_PIN = int(os.getenv("PANTREE_DRV8833_IN1_PIN", "22"))
DC_IN2_PIN = int(os.getenv("PANTREE_DRV8833_IN2_PIN", "27"))
_dc_sleep_pin_text = os.getenv("PANTREE_DRV8833_SLEEP_PIN", "").strip()
DC_SLEEP_PIN = int(_dc_sleep_pin_text) if _dc_sleep_pin_text else None


def _normalized_driver_name(driver=None):
    return (driver or os.getenv("PANTREE_MOTOR_DRIVER", "stepper")).strip().lower()


def init_motor(driver=None):
    """Initialize GPIO pins for the selected motor driver."""
    driver = _normalized_driver_name(driver)
    if driver in ("drv8833", "dc", "gear", "gear-motor", "right-angle"):
        return _init_drv8833()
    return _init_step_dir()


def _init_step_dir():
    """Initialize GPIO pins for STEP/DIR motor control."""
    global _backend, _motor_driver, _step_device, _dir_device, _enable_device, _active_motor_pins

    if OutputDevice is not None:
        try:
            _step_device = OutputDevice(STEP_PIN, active_high=True, initial_value=False)
            _dir_device = OutputDevice(DIR_PIN, active_high=True, initial_value=False)
            # ENABLE is active-LOW: active_high=False means .on() drives LOW.
            _enable_device = OutputDevice(ENABLE_PIN, active_high=False, initial_value=True)
            _backend = "gpiozero"
            _motor_driver = "stepper"
            _active_motor_pins = ALL_MOTOR_PINS
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
            _motor_driver = "stepper"
            _active_motor_pins = ALL_MOTOR_PINS
            print("[motor] Easy Driver initialized via RPi.GPIO (STEP=17, DIR=27, EN=22)")
            return True
        except Exception as e:
            print(f"[motor] RPi.GPIO init failed: {e}")

    print("[motor] No GPIO backend available (install python3-gpiozero python3-lgpio)")
    return False


def _init_drv8833():
    """Initialize GPIO pins for DRV8833 + 2-wire DC gear motor control."""
    global _backend, _motor_driver, _dc_in1_device, _dc_in2_device, _dc_sleep_device, _active_motor_pins

    active_pins = [DC_IN1_PIN, DC_IN2_PIN]
    if DC_SLEEP_PIN is not None:
        active_pins.append(DC_SLEEP_PIN)

    if OutputDevice is not None:
        try:
            output_class = PWMOutputDevice or OutputDevice
            _dc_in1_device = output_class(DC_IN1_PIN, active_high=True, initial_value=False)
            _dc_in2_device = output_class(DC_IN2_PIN, active_high=True, initial_value=False)
            _dc_sleep_device = (
                OutputDevice(DC_SLEEP_PIN, active_high=True, initial_value=True)
                if DC_SLEEP_PIN is not None else None
            )
            _backend = "gpiozero"
            _motor_driver = "drv8833"
            _active_motor_pins = active_pins
            sleep_text = DC_SLEEP_PIN if DC_SLEEP_PIN is not None else "disabled"
            print(f"[motor] DRV8833 initialized via gpiozero/lgpio (AIN1={DC_IN1_PIN}, AIN2={DC_IN2_PIN}, SLP={sleep_text})")
            return True
        except Exception as e:
            print(f"[motor] DRV8833 gpiozero init failed: {e}")
            _dc_in1_device = None
            _dc_in2_device = None
            _dc_sleep_device = None

    if GPIO is not None:
        try:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            GPIO.setup(DC_IN1_PIN, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(DC_IN2_PIN, GPIO.OUT, initial=GPIO.LOW)
            if DC_SLEEP_PIN is not None:
                GPIO.setup(DC_SLEEP_PIN, GPIO.OUT, initial=GPIO.HIGH)
            _backend = "rpi_gpio"
            _motor_driver = "drv8833"
            _active_motor_pins = active_pins
            sleep_text = DC_SLEEP_PIN if DC_SLEEP_PIN is not None else "disabled"
            print(f"[motor] DRV8833 initialized via RPi.GPIO (AIN1={DC_IN1_PIN}, AIN2={DC_IN2_PIN}, SLP={sleep_text})")
            return True
        except Exception as e:
            print(f"[motor] DRV8833 RPi.GPIO init failed: {e}")

    print("[motor] No GPIO backend available (install python3-gpiozero python3-lgpio)")
    return False


def enable_motor():
    """Enable the motor driver."""
    if _motor_driver == "drv8833" and _backend == "gpiozero" and _dc_sleep_device is not None:
        _dc_sleep_device.on()
    elif _motor_driver == "drv8833" and _backend == "rpi_gpio" and GPIO is not None and DC_SLEEP_PIN is not None:
        GPIO.output(DC_SLEEP_PIN, GPIO.HIGH)
    elif _backend == "gpiozero" and _enable_device is not None:
        _enable_device.on()
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(ENABLE_PIN, GPIO.LOW)


def disable_motor():
    """Disable the motor driver to save power and reduce heat."""
    if _motor_driver == "drv8833":
        _stop_dc_motor()
        if _backend == "gpiozero" and _dc_sleep_device is not None:
            _dc_sleep_device.off()
        elif _backend == "rpi_gpio" and GPIO is not None and DC_SLEEP_PIN is not None:
            GPIO.output(DC_SLEEP_PIN, GPIO.LOW)
    elif _backend == "gpiozero" and _enable_device is not None:
        _enable_device.off()
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(ENABLE_PIN, GPIO.HIGH)


def cleanup_motor():
    """Disable driver and release GPIO pins."""
    global _backend, _motor_driver, _step_device, _dir_device, _enable_device
    global _dc_in1_device, _dc_in2_device, _dc_sleep_device, _active_motor_pins
    try:
        disable_motor()
        if _backend == "gpiozero":
            for device in (_step_device, _dir_device, _enable_device, _dc_in1_device, _dc_in2_device, _dc_sleep_device):
                if device is not None:
                    device.close()
        elif _backend == "rpi_gpio" and GPIO is not None:
            for pin in _active_motor_pins:
                GPIO.output(pin, GPIO.LOW)
            GPIO.cleanup(_active_motor_pins)
    except RuntimeError:
        # Pins were never set up — nothing to clean
        pass
    finally:
        _backend = None
        _motor_driver = None
        _step_device = None
        _dir_device = None
        _enable_device = None
        _dc_in1_device = None
        _dc_in2_device = None
        _dc_sleep_device = None
        _active_motor_pins = []


def _set_device_value(device, value):
    """Set OutputDevice/PWMOutputDevice value safely."""
    if device is None:
        return
    if hasattr(device, "value"):
        device.value = max(0, min(1, value))
    elif value > 0:
        device.on()
    else:
        device.off()


def _stop_dc_motor():
    """Coast/stop the DRV8833 channel."""
    if _backend == "gpiozero":
        _set_device_value(_dc_in1_device, 0)
        _set_device_value(_dc_in2_device, 0)
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(DC_IN1_PIN, GPIO.LOW)
        GPIO.output(DC_IN2_PIN, GPIO.LOW)


def _run_dc_motor(seconds, forward=True, speed=DC_DEFAULT_SPEED):
    """Run the DRV8833 motor channel for a timed feed."""
    if _backend is None:
        print(f"[motor] Simulating DC motor for {seconds:.2f}s")
        return

    enable_motor()
    speed = max(0.15, min(1.0, speed))
    if _backend == "gpiozero":
        if forward:
            _set_device_value(_dc_in1_device, speed)
            _set_device_value(_dc_in2_device, 0)
        else:
            _set_device_value(_dc_in1_device, 0)
            _set_device_value(_dc_in2_device, speed)
    elif _backend == "rpi_gpio" and GPIO is not None:
        GPIO.output(DC_IN1_PIN, GPIO.HIGH if forward else GPIO.LOW)
        GPIO.output(DC_IN2_PIN, GPIO.LOW if forward else GPIO.HIGH)
    time.sleep(max(0, seconds))
    _stop_dc_motor()


def feed_steps(steps, delay=DEFAULT_STEP_DELAY):
    """
    Advance the receipt by a given number of microsteps.
    Positive = feed forward, negative = reverse.
    """
    if _motor_driver == "drv8833":
        # Compatibility shim: approximate step-style requests as timed DC movement.
        mm = steps / STEPS_PER_MM
        feed_mm(mm)
        return

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
    if _motor_driver == "drv8833":
        seconds = abs(mm) / max(1, DC_FEED_MM_PER_SECOND)
        print(f"[motor] DRV8833 timed feed: {mm:.1f} mm ≈ {seconds:.2f}s at speed {DC_DEFAULT_SPEED:.2f}")
        _run_dc_motor(seconds, forward=mm >= 0)
        return

    steps = int(mm * STEPS_PER_MM)
    feed_steps(steps, delay)


def feed_receipt_segment(segment_height_mm=30):
    """
    Feed one camera-frame worth of receipt paper.
    Default segment is 30mm to allow ~20% overlap between frames.
    """
    feed_mm(segment_height_mm)
