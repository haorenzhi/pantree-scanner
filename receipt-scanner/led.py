"""
NeoPixel LED strip control for receipt scanner illumination.

Uses the rpi_ws281x library with PWM on GPIO 18 (hardware PWM0).
This approach works perfectly on the Raspberry Pi Model B+ V1.2
(BCM2835). It does NOT work on Pi 5 but that is not our target.

Wiring:
  NeoPixel DIN  -> GPIO 18  (PWM0)
  NeoPixel 5V   -> 5V rail  (use external 5V supply for long strips)
  NeoPixel GND  -> Pi GND

NOTE: The rpi_ws281x library requires ROOT privileges (sudo) because
it accesses the PWM peripheral directly.

Adjust NUM_PIXELS and BRIGHTNESS to match your strip.
"""

try:
    from rpi_ws281x import PixelStrip, Color
    WS281X_AVAILABLE = True
except ImportError:
    WS281X_AVAILABLE = False

# --- LED configuration ---
LED_PIN = 18                # GPIO 18 = PWM0 channel
NUM_PIXELS = 10             # Number of LEDs on the strip
LED_FREQ_HZ = 800000       # 800 kHz signal (standard for WS2812)
LED_DMA = 10                # DMA channel (10 avoids conflicts on Pi 1)
LED_BRIGHTNESS = 153        # 0-255 (~60 %)
LED_INVERT = False          # Invert signal (set True if using NPN level-shifter)
LED_CHANNEL = 0             # PWM channel (0 for GPIO 18)

SCAN_COLOR = (255, 255, 255)  # Neutral white for even receipt illumination
IDLE_COLOR = (0, 20, 0)      # Dim green when idle / ready
OFF_COLOR = (0, 0, 0)

_strip = None


def _color(rgb_tuple):
    """Convert (R, G, B) tuple to a rpi_ws281x Color int."""
    return Color(rgb_tuple[0], rgb_tuple[1], rgb_tuple[2])


def init_leds():
    """Initialize the NeoPixel strip via PWM on GPIO 18."""
    global _strip
    if not WS281X_AVAILABLE:
        print("[led] rpi_ws281x not available — LEDs disabled")
        return False
    try:
        _strip = PixelStrip(
            NUM_PIXELS, LED_PIN, LED_FREQ_HZ,
            LED_DMA, LED_INVERT, LED_BRIGHTNESS, LED_CHANNEL,
        )
        _strip.begin()
        _fill(OFF_COLOR)
        print(f"[led] NeoPixel strip initialized ({NUM_PIXELS} pixels on GPIO {LED_PIN})")
        return True
    except Exception as e:
        print(f"[led] Failed to initialize NeoPixel: {e}")
        _strip = None
        return False


def _fill(color_tuple):
    """Set every pixel to the given (R,G,B) and push to strip."""
    if _strip is None:
        return
    c = _color(color_tuple)
    for i in range(_strip.numPixels()):
        _strip.setPixelColor(i, c)
    _strip.show()


def leds_on(color=SCAN_COLOR):
    """Turn all LEDs to the given color (default: bright white for scanning)."""
    if _strip is None:
        print("[led] LEDs not initialized — simulating ON")
        return
    _fill(color)


def leds_idle():
    """Set LEDs to dim idle/ready indicator."""
    leds_on(IDLE_COLOR)


def leds_off():
    """Turn all LEDs off."""
    _fill(OFF_COLOR)


def leds_scan_feedback(progress_ratio):
    """
    Visual progress indicator during scanning.
    Lights up LEDs proportionally to scan progress (0.0 → 1.0).
    """
    if _strip is None:
        return
    lit_count = max(1, int(NUM_PIXELS * progress_ratio))
    for i in range(NUM_PIXELS):
        if i < lit_count:
            _strip.setPixelColor(i, _color(SCAN_COLOR))
        else:
            _strip.setPixelColor(i, _color((10, 10, 10)))
    _strip.show()


def cleanup_leds():
    """Turn off all LEDs."""
    global _strip
    if _strip is None:
        return
    _fill(OFF_COLOR)
    _strip = None
