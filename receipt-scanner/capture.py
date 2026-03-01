"""
Pi Camera image capture for receipt scanning.

Captures frames from the Pi Camera Module v2/v3 as the receipt
is fed past the camera by the stepper motor.
"""

import time

try:
    from picamera2 import Picamera2
except ImportError:
    Picamera2 = None

from PIL import Image
import numpy as np


# Camera resolution (Pi Camera v2 max: 3280x2464, we use a lower res for speed)
CAPTURE_WIDTH = 1640
CAPTURE_HEIGHT = 1232

# Blank-frame detection: if mean pixel value is above this, frame is blank
BLANK_THRESHOLD = 245

# Maximum frames to capture per receipt (safety limit)
MAX_FRAMES = 30


class ReceiptCamera:
    def __init__(self):
        self.camera = None

    def init_camera(self):
        """Initialize the Pi Camera with settings tuned for receipt scanning."""
        if Picamera2 is None:
            print("[capture] picamera2 not available (not running on Pi)")
            return False

        self.camera = Picamera2()
        config = self.camera.create_still_configuration(
            main={"size": (CAPTURE_WIDTH, CAPTURE_HEIGHT), "format": "RGB888"}
        )
        self.camera.configure(config)

        # Manual white balance tuned for white paper + black text
        self.camera.set_controls({
            "AwbEnable": False,
            "ColourGains": (1.4, 1.5),  # slightly warm to handle thermal paper
            "ExposureTime": 20000,  # 20ms exposure
            "AnalogueGain": 2.0,
        })

        self.camera.start()
        # Let auto-exposure settle
        time.sleep(1)
        return True

    def capture_frame(self):
        """Capture a single still frame and return as PIL Image."""
        if self.camera is None:
            print("[capture] Camera not initialized")
            return None

        array = self.camera.capture_array()
        return Image.fromarray(array)

    def is_blank_frame(self, img):
        """Detect if a frame is blank (no receipt paper / end of receipt)."""
        gray = np.array(img.convert("L"))
        return gray.mean() > BLANK_THRESHOLD

    def close(self):
        """Shut down the camera."""
        if self.camera is not None:
            self.camera.stop()
            self.camera.close()
            self.camera = None


def capture_receipt(camera, feed_fn, segment_mm=30):
    """
    Capture a full receipt by coordinating motor feed and camera capture.

    Args:
        camera: ReceiptCamera instance
        feed_fn: callable that feeds paper by segment_mm (e.g., motor.feed_mm)
        segment_mm: mm of paper to advance between frames

    Returns:
        list of PIL Images covering the full receipt
    """
    frames = []
    blank_count = 0

    for i in range(MAX_FRAMES):
        frame = camera.capture_frame()
        if frame is None:
            break

        if camera.is_blank_frame(frame):
            blank_count += 1
            # 2 consecutive blank frames = end of receipt
            if blank_count >= 2:
                print(f"[capture] End of receipt detected at frame {i}")
                break
        else:
            blank_count = 0
            frames.append(frame)

        # Feed the next segment
        feed_fn(segment_mm)
        # Brief pause for paper to settle
        time.sleep(0.1)

    print(f"[capture] Captured {len(frames)} frames")
    return frames


def load_test_images(paths):
    """Load images from file paths for testing without hardware."""
    frames = []
    for p in paths:
        try:
            frames.append(Image.open(p))
        except Exception as e:
            print(f"[capture] Failed to load {p}: {e}")
    return frames
