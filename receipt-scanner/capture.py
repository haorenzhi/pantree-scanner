"""
Pi Camera image capture for receipt scanning.

Uses picamera2 (libcamera stack) for Raspberry Pi 3 and later.
Falls back to the legacy picamera library if picamera2 is not available.

On Raspberry Pi OS Trixie/Bookworm, install via:
    sudo apt install -y python3-picamera2

Camera is auto-detected via libcamera; no raspi-config needed.
"""

import time
import io

# Try picamera2 first (modern libcamera stack — Pi 3+)
try:
    from picamera2 import Picamera2
    PICAMERA2_AVAILABLE = True
except Exception:
    Picamera2 = None
    PICAMERA2_AVAILABLE = False

# Fallback: legacy picamera (Pi 1/2 with legacy camera stack)
try:
    import picamera
    PICAMERA_LEGACY = True
except Exception:
    picamera = None
    PICAMERA_LEGACY = False

from PIL import Image
import numpy as np


# Camera resolution
CAPTURE_WIDTH = 1296
CAPTURE_HEIGHT = 972

# Blank-frame detection: if mean pixel value is above this, frame is blank
BLANK_THRESHOLD = 245

# Maximum frames to capture per receipt (safety limit)
MAX_FRAMES = 30


class ReceiptCamera:
    def __init__(self):
        self.camera = None
        self._backend = None  # "picamera2" or "legacy"

    def init_camera(self):
        """Initialize the Pi Camera with settings tuned for receipt scanning."""
        # --- Try picamera2 first (Pi 3 / Pi 4 / Pi 5 on Bookworm/Trixie) ---
        if PICAMERA2_AVAILABLE:
            return self._init_picamera2()

        # --- Fallback to legacy picamera (Pi 1 / Pi 2 on Bullseye) ---
        if PICAMERA_LEGACY:
            return self._init_legacy()

        print("[capture] No camera library available (not running on Pi?)")
        return False

    # ------------------------------------------------------------------ #
    #  picamera2 backend
    # ------------------------------------------------------------------ #
    def _init_picamera2(self):
        """Initialize camera using picamera2 / libcamera."""
        try:
            cam = Picamera2()
            # Still configuration optimised for receipt scanning
            config = cam.create_still_configuration(
                main={"size": (CAPTURE_WIDTH, CAPTURE_HEIGHT), "format": "RGB888"},
            )
            cam.configure(config)
            cam.start()
            # Let AEC/AWB settle
            time.sleep(2)
            self.camera = cam
            self._backend = "picamera2"
            print(f"[capture] picamera2 camera initialized ({CAPTURE_WIDTH}x{CAPTURE_HEIGHT})")
            return True
        except Exception as e:
            print(f"[capture] picamera2 init failed: {e}")
            return False

    # ------------------------------------------------------------------ #
    #  Legacy picamera backend
    # ------------------------------------------------------------------ #
    def _init_legacy(self):
        """Initialize camera using legacy picamera (v1)."""
        try:
            cam = picamera.PiCamera()
            cam.resolution = (CAPTURE_WIDTH, CAPTURE_HEIGHT)
            cam.awb_mode = "off"
            cam.awb_gains = (1.4, 1.5)
            cam.shutter_speed = 20000
            cam.iso = 200
            time.sleep(2)
            self.camera = cam
            self._backend = "legacy"
            print(f"[capture] Legacy picamera initialized ({CAPTURE_WIDTH}x{CAPTURE_HEIGHT})")
            return True
        except picamera.PiCameraError as e:
            print(f"[capture] Legacy camera init failed: {e}")
            return False

    # ------------------------------------------------------------------ #
    #  Common interface
    # ------------------------------------------------------------------ #
    def capture_frame(self):
        """Capture a single still frame and return as PIL Image."""
        if self.camera is None:
            print("[capture] Camera not initialized")
            return None

        if self._backend == "picamera2":
            # capture_array returns a numpy array (RGB888)
            arr = self.camera.capture_array()
            return Image.fromarray(arr)
        else:
            # Legacy path
            stream = io.BytesIO()
            self.camera.capture(stream, format="jpeg", quality=90)
            stream.seek(0)
            return Image.open(stream)

    def is_blank_frame(self, img):
        """Detect if a frame is blank (no receipt paper / end of receipt)."""
        gray = np.array(img.convert("L"))
        return gray.mean() > BLANK_THRESHOLD

    def close(self):
        """Shut down the camera."""
        if self.camera is not None:
            if self._backend == "picamera2":
                self.camera.stop()
                self.camera.close()
            else:
                self.camera.close()
            self.camera = None
            self._backend = None


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
