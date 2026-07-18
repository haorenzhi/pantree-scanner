"""
Pantree bridge server integration.

Sends parsed food items to the bridge server via HTTP POST,
which makes them available to the Pantree React app.
"""

import random
from datetime import date, timedelta

import requests

# Bridge server URL — change host if Pantree runs on a different machine
BRIDGE_URL = "http://localhost:4000/api/foods"


def send_to_pantree(items, bridge_url=BRIDGE_URL):
    """
    Send parsed food items to the Pantree bridge server.

    Args:
        items: list of dicts from parser.parse_receipt()
               Each dict has: name, price, section, exp_days
        bridge_url: URL of the bridge server endpoint

    Returns:
        True if items were added successfully, False otherwise
    """
    today = date.today()
    foods = []

    for item in items:
        exp_date = today + timedelta(days=item["exp_days"])
        foods.append({
            "id": random.randint(10000, 99999),
            "name": item["name"],
            "icon": "",  # bridge server resolves emoji
            "buyDate": today.isoformat(),
            "expDate": exp_date.isoformat(),
            "section": item["section"],
        })

    try:
        response = requests.post(bridge_url, json={"foods": foods}, timeout=10)
        if response.status_code == 200:
            result = response.json()
            print(f"[send] Added {result.get('added', len(foods))} items to Pantree")
            return True
        else:
            print(f"[send] Bridge server returned status {response.status_code}")
            print(f"[send] Response: {response.text}")
            return False
    except requests.ConnectionError:
        print(f"[send] Could not connect to bridge server at {bridge_url}")
        print("[send] Make sure the bridge server is running: cd bridge-server && node server.js")
        return False
    except requests.Timeout:
        print("[send] Request to bridge server timed out")
        return False
