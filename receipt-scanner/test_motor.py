#!/usr/bin/env python3
"""Quick motor wiring test for the receipt feeder.

Examples:
  python test_motor.py --driver drv8833
  python test_motor.py --driver stepper
"""

import argparse
import time

from motor import init_motor, cleanup_motor, feed_mm


def main():
    parser = argparse.ArgumentParser(description="Test receipt feeder motor wiring")
    parser.add_argument("--driver", choices=("stepper", "drv8833"), default="drv8833")
    parser.add_argument("--mm", type=float, default=30, help="Approximate feed distance to test")
    parser.add_argument("--repeat", type=int, default=1)
    args = parser.parse_args()

    print("=" * 42)
    print(f"  Motor Test — {args.driver}")
    print("=" * 42)
    print("Keep fingers clear of rollers. Press Ctrl+C to stop.")

    if not init_motor(args.driver):
        raise SystemExit("Motor GPIO init failed")

    try:
        for i in range(args.repeat):
            print(f"Forward feed #{i + 1}: {args.mm} mm")
            feed_mm(args.mm)
            time.sleep(0.5)
        print("Done. If direction is backwards, swap the two motor wires or reverse AIN1/AIN2 in wiring.")
    finally:
        cleanup_motor()


if __name__ == "__main__":
    main()
