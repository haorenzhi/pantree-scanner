#!/usr/bin/env python3
"""
Receipt Scanner — Main entry point.

Orchestrates the full scan pipeline:
1. Wait for button press or keyboard trigger
2. Feed receipt through rollers + capture frames
3. Run OCR on captured frames
4. Parse receipt text into food items
5. Display parsed items for confirmation
6. POST to Pantree bridge server
7. Print summary and return to waiting state

Usage:
    python main.py              # hardware mode (Pi + camera + motor)
    python main.py --test FILE  # test mode with an image file
    python main.py --text FILE  # test mode with a text file (skip OCR)
"""

import argparse
import sys

from motor import init_motor, cleanup_motor, feed_mm
from capture import ReceiptCamera, capture_receipt, load_test_images
from ocr import ocr_receipt
from parser import parse_receipt
from send import send_to_pantree
from led import init_leds, leds_on, leds_idle, leds_off, cleanup_leds

# GPIO pin for the scan button (active LOW with internal pull-up)
BUTTON_PIN = 23


def wait_for_button():
    """Wait for physical button press on GPIO to start a scan.
    Uses gpiozero (works on Trixie kernel 6.12+) with RPi.GPIO fallback.
    """
    # Try gpiozero first — it uses the modern character device interface
    try:
        from gpiozero import Button
        btn = Button(BUTTON_PIN, pull_up=True, bounce_time=0.3)
        print("\nReady. Press the scan button to start...")
        btn.wait_for_press()
        btn.close()
        return True
    except Exception:
        pass

    # Fallback to RPi.GPIO (works on older kernels)
    try:
        import RPi.GPIO as GPIO
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        print("\nReady. Press the scan button to start...")
        GPIO.wait_for_edge(BUTTON_PIN, GPIO.FALLING, bouncetime=300)
        return True
    except ImportError:
        return False
    except RuntimeError as e:
        print(f"[main] GPIO edge detection failed: {e}")
        return False


def wait_for_keyboard():
    """Wait for Enter key press to start a scan."""
    try:
        input("\nReady. Press Enter to start scanning...")
        return True
    except (KeyboardInterrupt, EOFError):
        return False


def display_items(items):
    """Display parsed items in a formatted table."""
    if not items:
        print("\n  No food items found on receipt.")
        return

    print(f"\n  Found {len(items)} food item(s):")
    print(f"  {'#':<4} {'Name':<25} {'Section':<10} {'Exp Days':<10} {'Price':<8}")
    print(f"  {'-'*4} {'-'*25} {'-'*10} {'-'*10} {'-'*8}")

    for i, item in enumerate(items, 1):
        price_str = f"${item['price']:.2f}" if item.get("price") else "-"
        print(
            f"  {i:<4} {item['name']:<25} {item['section']:<10} "
            f"{item['exp_days']:<10} {price_str:<8}"
        )


def scan_receipt_hardware(use_motor=True):
    """Full hardware scan pipeline using Pi Camera and stepper motor.
    
    Args:
        use_motor: If False, skip motor and take a single snapshot instead.
    """
    # Initialize hardware
    motor_ok = False
    if use_motor:
        motor_ok = init_motor()
    camera = ReceiptCamera()
    camera_ok = camera.init_camera()
    led_ok = init_leds()

    if not camera_ok:
        print("[main] Camera initialization failed")
        print("[main] Use --test or --text mode for testing without hardware")
        return

    try:
        # Turn on LEDs for illumination during scanning
        leds_on()

        if use_motor and motor_ok:
            # Full multi-frame scan: feed receipt through rollers
            print("[main] Scanning receipt (motor + camera)...")
            frames = capture_receipt(camera, feed_mm)
        else:
            # Single snapshot mode
            print("[main] Taking snapshot...")
            frame = camera.capture_frame()
            frames = [frame] if frame else []

        if not frames:
            print("[main] No frames captured. Is a receipt inserted?")
            return

        # OCR
        print("[main] Running OCR...")
        text = ocr_receipt(frames)
        print(f"\n--- Raw OCR Text ---\n{text}\n---\n")

        # Parse
        items = parse_receipt(text)
        display_items(items)

        if not items:
            return

        # Confirm and send
        try:
            confirm = input("\n  Send these items to Pantree? [Y/n] ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print("\n  Cancelled.")
            return

        if confirm in ("", "y", "yes"):
            send_to_pantree(items)
        else:
            print("  Skipped.")

    finally:
        leds_off()
        camera.close()
        cleanup_motor()
        cleanup_leds()


def scan_from_image(image_path):
    """Test pipeline using an image file instead of live camera capture."""
    print(f"[main] Loading test image: {image_path}")
    frames = load_test_images([image_path])

    if not frames:
        print("[main] Failed to load image")
        return

    print("[main] Running OCR...")
    text = ocr_receipt(frames)
    print(f"\n--- Raw OCR Text ---\n{text}\n---\n")

    items = parse_receipt(text)
    display_items(items)

    if not items:
        return

    try:
        confirm = input("\n  Send these items to Pantree? [Y/n] ").strip().lower()
    except (KeyboardInterrupt, EOFError):
        print("\n  Cancelled.")
        return

    if confirm in ("", "y", "yes"):
        send_to_pantree(items)
    else:
        print("  Skipped.")


def scan_from_text(text_path):
    """Test pipeline using a text file (skip OCR, go straight to parsing)."""
    print(f"[main] Loading text file: {text_path}")
    try:
        with open(text_path, "r") as f:
            text = f.read()
    except FileNotFoundError:
        print(f"[main] File not found: {text_path}")
        return

    print(f"\n--- Receipt Text ---\n{text}\n---\n")

    items = parse_receipt(text)
    display_items(items)

    if not items:
        return

    try:
        confirm = input("\n  Send these items to Pantree? [Y/n] ").strip().lower()
    except (KeyboardInterrupt, EOFError):
        print("\n  Cancelled.")
        return

    if confirm in ("", "y", "yes"):
        send_to_pantree(items)
    else:
        print("  Skipped.")


def main():
    parser = argparse.ArgumentParser(
        description="Receipt Scanner for Pantree — scan grocery receipts and add items to your pantry"
    )
    parser.add_argument(
        "--test", metavar="IMAGE",
        help="Test mode: process a receipt image file instead of using hardware"
    )
    parser.add_argument(
        "--text", metavar="FILE",
        help="Text mode: process a text file (skips OCR, tests parser only)"
    )
    parser.add_argument(
        "--no-motor", action="store_true",
        help="Snapshot mode: take a single photo per button press (no stepper motor)"
    )
    parser.add_argument(
        "--bridge-url", default="http://localhost:4000/api/foods",
        help="Bridge server URL (default: http://localhost:4000/api/foods)"
    )
    args = parser.parse_args()

    print("=" * 50)
    print("  Pantree Receipt Scanner")
    print("=" * 50)

    if args.test:
        scan_from_image(args.test)
    elif args.text:
        scan_from_text(args.text)
    else:
        # Hardware mode — loop waiting for button/keyboard
        has_button = False
        try:
            from gpiozero import Button
            has_button = True
        except ImportError:
            try:
                import RPi.GPIO
                has_button = True
            except ImportError:
                pass

        print("[main] Running in hardware mode")
        if not has_button:
            print("[main] GPIO not available — using keyboard trigger")

        # Show idle LED while waiting for scans
        init_leds()
        leds_idle()

        try:
            while True:
                if has_button:
                    if not wait_for_button():
                        # GPIO edge detection failed — fall back to keyboard
                        print("[main] Falling back to keyboard trigger")
                        has_button = False
                        continue
                else:
                    if not wait_for_keyboard():
                        break

                scan_receipt_hardware(use_motor=not args.no_motor)
                # Return to idle indicator between scans
                leds_idle()

        except KeyboardInterrupt:
            print("\n[main] Shutting down...")
        finally:
            leds_off()
            cleanup_leds()
            cleanup_motor()

    print("\nDone.")


if __name__ == "__main__":
    main()
