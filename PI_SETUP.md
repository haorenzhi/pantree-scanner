# Raspberry Pi Model B+ V1.2 — Environment Setup & Server Installation

Complete step-by-step guide to prepare the **Raspberry Pi Model B+ V1.2**
(BCM2835, ARMv6, 512 MB RAM) for the Pantree receipt scanner.

> ⚠️ **Hardware limitations** — The Pi 1 B+ is a single-core ARM11 at
> 700 MHz with 512 MB RAM. Tesseract OCR will be **slow** (~20-40 s per
> image). Plan accordingly.

> **Do all of this at a desk with a monitor + keyboard (or over SSH/Ethernet)
> BEFORE wiring the motor, camera, and LEDs.**

---

## Table of Contents

1. [Flash Raspberry Pi OS](#1-flash-raspberry-pi-os)
2. [First Boot & System Config](#2-first-boot--system-config)
3. [Install System Packages](#3-install-system-packages)
4. [Install Node.js (armv6l)](#4-install-nodejs-armv6l)
5. [Python Virtual Environment & Scanner Deps](#5-python-virtual-environment--scanner-deps)
6. [Bridge Server Setup](#6-bridge-server-setup)
7. [React Frontend Build](#7-react-frontend-build)
8. [Verify Camera (Legacy Stack)](#8-verify-camera-legacy-stack)
9. [Auto-Start Services (systemd)](#9-auto-start-services-systemd)
10. [GPIO Wiring Reference](#10-gpio-wiring-reference)
11. [Startup & Verification Checklist](#11-startup--verification-checklist)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Flash Raspberry Pi OS

The Pi 1 B+ uses a **BCM2835 (ARMv6)** SoC. You **must** use a
**32-bit Legacy** image — 64-bit and the latest Bookworm do not run
on ARMv6.

1. Download **Raspberry Pi Imager** on your Mac/PC:
   <https://www.raspberrypi.com/software/>
2. Insert the **Samsung 32 GB Micro SD** card (via USB card reader).
3. In the Imager, choose:
   - **Device:** Raspberry Pi 1
   - **OS:** Raspberry Pi OS (Legacy, 32-bit) — based on **Debian
     Bullseye**. The **Lite** variant (no desktop) is recommended to
     save RAM.  
     *Path in Imager: Raspberry Pi OS (other) → Raspberry Pi OS
     (Legacy, 32-bit) Lite*
   - **Storage:** your SD card.
4. Click the **gear ⚙** icon (or Ctrl+Shift+X) to pre-configure:
   - **Enable SSH** → Use password authentication
   - **Set username:** `pi`
   - **Set password:** (something you'll remember)
   - **Configure WiFi:** enter your SSID + password + country  
     *(only works if you plug a USB WiFi dongle in later; otherwise
     use Ethernet)*
   - **Set locale:** your timezone
5. Click **Write** and wait for it to finish.
6. Insert the SD card into the Pi B+ and power on via **micro USB**
   (5 V / 2 A minimum).

---

## 2. First Boot & System Config

### 2a. Connect to the Pi

**Option A — Ethernet (easiest):** Plug an Ethernet cable between the Pi
and your router. Then from your Mac:

```bash
ssh pi@raspberrypi.local
```

**Option B — USB WiFi dongle:** Plug in the dongle, and if you
pre-configured WiFi in the Imager it should connect automatically. SSH
as above.

**Option C — Monitor + keyboard:** Plug in directly and log in.

### 2b. raspi-config

```bash
sudo raspi-config
```

Enable the following under **Interface Options**:

| Interface       | Why                                        |
|-----------------|--------------------------------------------|
| **Legacy Camera** | Pi Camera Module via legacy `raspistill`   |
| **SSH**         | Remote access (should already be on)       |

> ⚠️ Make sure you enable the **Legacy Camera** option, NOT the new
> `libcamera` stack. On Bullseye the option says "Enable legacy camera
> support". The Pi 1 B+ does not support libcamera.

You do **NOT** need to enable SPI (we use PWM for NeoPixels now).

### 2c. GPU memory split

Still in raspi-config → **Performance Options → GPU Memory**:

Set to **128** MB (default is 64). The camera needs at least 128.

### 2d. Reboot

```bash
sudo reboot
```

---

## 3. Install System Packages

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  python3-pip \
  python3-venv \
  python3-dev \
  tesseract-ocr \
  libtesseract-dev \
  libatlas-base-dev \
  libraspberrypi-bin \
  git
```

| Package              | Purpose                                     |
|----------------------|---------------------------------------------|
| `python3-pip/venv`   | Python package management + virtual envs    |
| `tesseract-ocr`      | OCR engine for receipt text extraction       |
| `libtesseract-dev`   | Headers for pytesseract bindings            |
| `libatlas-base-dev`  | NumPy linear algebra backend (armhf build)  |
| `libraspberrypi-bin` | `raspistill` / `raspivid` camera CLI tools  |
| `git`                | Clone the project repo                      |

> **Note:** Do NOT install `libcamera-apps` — it is not compatible with
> the BCM2835 on this Pi.

---

## 4. Install Node.js (armv6l)

NodeSource **does not provide** armv6l binaries for Node 18+.
You have two options:

### Option A — Unofficial builds (recommended)

The Node.js project publishes **unofficial** armv6l builds:

```bash
NODE_VERSION=18.20.4

cd /tmp
wget https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-armv6l.tar.xz
sudo tar -xJf node-v${NODE_VERSION}-linux-armv6l.tar.xz -C /usr/local --strip-components=1
rm node-v${NODE_VERSION}-linux-armv6l.tar.xz
```

### Option B — Use Node 16 from NodeSource

Node 16 is the last major version with **official** armv6l support
(EOL September 2023 but still functional):

```bash
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs
```

### Verify

```bash
node --version   # v16.x or v18.x
npm --version    # 8.x or 9.x
```

---

## 5. Python Virtual Environment & Scanner Deps

### 5a. Clone the project (if not already on the Pi)

```bash
cd ~
git clone https://github.com/<your-user>/pantree-scanner.git
cd pantree-scanner
```

Or copy via `scp` from your Mac:

```bash
# from Mac terminal:
scp -r /path/to/pantree-scanner pi@raspberrypi.local:~/
```

### 5b. Create & activate virtual environment

```bash
python3 -m venv ~/scanner-env
source ~/scanner-env/bin/activate
```

> **Tip:** Add `source ~/scanner-env/bin/activate` to `~/.bashrc` so it
> activates on every login.

### 5c. Install Python packages

```bash
cd ~/pantree-scanner/receipt-scanner
pip install --upgrade pip
pip install -r requirements.txt
```

This installs:

| Package        | Purpose                                   |
|----------------|-------------------------------------------|
| `pytesseract`  | Python wrapper for Tesseract OCR          |
| `Pillow`       | Image processing                          |
| `picamera`     | Legacy Pi Camera control (v1 library)     |
| `RPi.GPIO`     | GPIO pin control (motor, button)          |
| `requests`     | HTTP POST to Bridge Server                |
| `numpy`        | Image array operations                    |
| `rpi_ws281x`   | NeoPixel LED via PWM on GPIO 18           |

> **Memory note:** `pip install` may be slow or run out of memory on
> 512 MB RAM. If pip gets killed, try installing packages one at a time,
> or add swap:
>
> ```bash
> sudo dphys-swapfile swapoff
> sudo sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
> sudo dphys-swapfile setup
> sudo dphys-swapfile swapon
> ```

### 5d. Verify Tesseract

```bash
tesseract --version
# Should show 4.x or 5.x
```

---

## 6. Bridge Server Setup

The Bridge Server is a Node.js Express API that receives scanned food
items from the Python scanner and serves them to the React frontend.
It runs on **port 4000**.

### 6a. Install dependencies

```bash
cd ~/pantree-scanner/bridge-server
npm install
```

This installs: `express`, `cors`, `multer`, `tesseract.js`.

> ⚠️ `tesseract.js` includes a WASM OCR engine (~100 MB). On the Pi 1
> this install will be slow. The Python scanner uses native Tesseract
> for actual OCR, so the Bridge Server's `tesseract.js` is only a
> fallback.

### 6b. Test run

```bash
node server.js
```

You should see:

```
Pantree Bridge Server running on port 4000
Data file: /home/pi/pantree-scanner/bridge-server/pantree-data.json
```

Verify:

```bash
curl http://localhost:4000/api/health
# → {"status":"ok",...}
```

Press `Ctrl+C` to stop — we'll set up auto-start in step 9.

---

## 7. React Frontend Build

> ⚠️ **Building React on the Pi 1 B+ is extremely slow** and may fail
> due to insufficient RAM. **Recommended:** Build on your Mac and copy
> the `build/` folder to the Pi.

### Option A — Build on Mac (recommended)

```bash
# on your Mac:
cd /path/to/pantree-scanner
npm install
npm run build

# Copy built files to Pi:
scp -r build/ pi@raspberrypi.local:~/pantree-scanner/
```

### Option B — Build on Pi (slow, may need extra swap)

```bash
cd ~/pantree-scanner
npm install     # this alone may take 10+ minutes
npm run build   # will be very slow, may OOM
```

### 7c. Serve the frontend

Option A — Use `serve`:

```bash
sudo npm install -g serve
serve -s build -l 3000 &
```

Option B — Serve from Bridge Server (no extra process):

```bash
# Add to bridge-server/server.js near the top after other middleware:
# app.use(express.static(path.join(__dirname, '..', 'build')));
# Then access the app at http://raspberrypi.local:4000
```

### 7d. Access the UI

From any device on the same network:

```
http://raspberrypi.local:3000   # if using serve
http://raspberrypi.local:4000   # if serving from bridge server
```

> If using Ethernet (no mDNS), find the Pi's IP with `hostname -I` and
> use `http://<ip>:4000`.

---

## 8. Verify Camera (Legacy Stack)

The Pi 1 B+ uses the **legacy Broadcom camera stack** (`raspistill`),
NOT `libcamera`.

### 8a. CLI test

```bash
raspistill -o ~/test-photo.jpg
```

You should see a 5-second preview (on HDMI) then a captured JPEG.

If you get errors:
- Reseat the CSI ribbon cable (blue side toward the **Ethernet** jack).
- Confirm **Legacy Camera** is enabled in `raspi-config`.
- Confirm `gpu_mem=128` (or higher) in `/boot/config.txt`.

### 8b. Python test

```bash
source ~/scanner-env/bin/activate
python3 -c "
import picamera, time, io
cam = picamera.PiCamera()
cam.resolution = (1296, 972)
time.sleep(2)
cam.capture('/home/pi/test-python.jpg')
cam.close()
print('Capture OK')
"
```

Copy to your Mac to check:

```bash
scp pi@raspberrypi.local:~/test-python.jpg ~/Desktop/
```

---

## 9. Auto-Start Services (systemd)

### 9a. Bridge Server service

```bash
sudo tee /etc/systemd/system/pantree-bridge.service << 'EOF'
[Unit]
Description=Pantree Bridge Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/pantree-scanner/bridge-server
ExecStart=/usr/local/bin/node server.js
Restart=on-failure
RestartSec=5
Environment=PORT=4000

[Install]
WantedBy=multi-user.target
EOF
```

> Note: `ExecStart` path may differ. Run `which node` to confirm.

### 9b. Receipt Scanner service

The scanner needs **root** for NeoPixel PWM (rpi_ws281x) and GPIO:

```bash
sudo tee /etc/systemd/system/pantree-scanner.service << 'EOF'
[Unit]
Description=Pantree Receipt Scanner
After=pantree-bridge.service
Requires=pantree-bridge.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/pi/pantree-scanner/receipt-scanner
ExecStart=/home/pi/scanner-env/bin/python main.py --bridge-url http://localhost:4000/api/foods
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

> ⚠️ The scanner service runs as **root** because `rpi_ws281x` requires
> direct PWM hardware access. If you don't use NeoPixels, you can change
> `User=root` to `User=pi` and add `pi` to the `gpio` group.

### 9c. (Optional) React Frontend service

Only needed if you used `serve` (Option A in step 7):

```bash
sudo tee /etc/systemd/system/pantree-frontend.service << 'EOF'
[Unit]
Description=Pantree React Frontend
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/pantree-scanner
ExecStart=/usr/local/bin/npx serve -s build -l 3000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### 9d. Enable & start

```bash
sudo systemctl daemon-reload

sudo systemctl enable pantree-bridge.service
sudo systemctl enable pantree-scanner.service
# sudo systemctl enable pantree-frontend.service   # if using serve

sudo systemctl start pantree-bridge.service
sudo systemctl start pantree-scanner.service

sudo systemctl status pantree-bridge.service
sudo systemctl status pantree-scanner.service
```

View logs:

```bash
journalctl -u pantree-bridge.service -f
journalctl -u pantree-scanner.service -f
```

---

## 10. GPIO Wiring Reference

All pins use **BCM numbering**. The Pi 1 B+ V1.2 has a 40-pin header
(same layout as newer Pi models).

### Easy Driver Stepper Motor (NEMA 17)

| Easy Driver Pin | Pi GPIO (BCM) | Physical Pin | Notes                        |
|-----------------|---------------|--------------|------------------------------|
| **STEP**        | GPIO 17       | Pin 11       | Pulse rising edge = 1 step   |
| **DIR**         | GPIO 27       | Pin 13       | HIGH = forward, LOW = reverse|
| **ENABLE**      | GPIO 22       | Pin 15       | LOW = enabled, HIGH = sleep  |
| **GND**         | GND           | Pin 6/9/etc  | Common ground with Pi        |
| **M+**          | —             | —            | 12V power supply positive    |
| **GND** (power) | —             | —            | 12V power supply negative    |

> **Do NOT connect 12V to any Pi pin.** The Easy Driver's M+/GND are for
> the motor supply only.

### NeoPixel LED Strip (WS2812B via PWM)

| NeoPixel Wire  | Pi GPIO (BCM) | Physical Pin | Notes                      |
|----------------|---------------|--------------|----------------------------|
| **DIN** (data) | GPIO 18       | Pin 12       | PWM0 channel               |
| **5V**         | 5V or ext. PSU| Pin 2/4      | Use external for >8 LEDs   |
| **GND**        | GND           | Pin 6/9/etc  | Common ground               |

> 🔑 NeoPixel control via `rpi_ws281x` requires **sudo** (root).
> The PWM peripheral is accessed directly, not through `/dev`.

### Scan Button

| Button Wire  | Pi GPIO (BCM) | Physical Pin | Notes                      |
|--------------|---------------|--------------|----------------------------|
| **Signal**   | GPIO 23       | Pin 16       | Internal pull-up, active LOW|
| **GND**      | GND           | Pin 14/etc   | Other side of button        |

### Pi Camera Module V2

- Connect via the **CSI ribbon cable** to the camera port between the
  Ethernet jack and HDMI port.
- Blue side of ribbon faces the **Ethernet jack**.
- No GPIO pins used — camera uses the dedicated MIPI CSI-2 interface.

### Full GPIO Map (visual)

```
              Pi 1 B+ V1.2 — GPIO Header (top view, USB ports at bottom)
              ┌─────────────────────────────────┐
              │  3V3  (1) (2)  5V ← NeoPixel 5V │
              │  SDA  (3) (4)  5V               │
              │  SCL  (5) (6)  GND ← shared GND │
              │   4   (7) (8)  TX               │
              │  GND  (9) (10) RX               │
  STEP ►──── │  17  (11) (12) 18  ◄── NeoPixel │
   DIR ►──── │  27  (13) (14) GND              │
ENABLE ►──── │  22  (15) (16) 23  ◄── BUTTON   │
              │  3V3 (17) (18) 24               │
              │  10  (19) (20) GND              │
              │   9  (21) (22) 25               │
              │  11  (23) (24)  8               │
              │  GND (25) (26)  7               │
              │   0  (27) (28)  1               │
              │   5  (29) (30) GND              │
              │   6  (31) (32) 12               │
              │  13  (33) (34) GND              │
              │  19  (35) (36) 16               │
              │  26  (37) (38) 20               │
              │  GND (39) (40) 21               │
              └─────────────────────────────────┘
```

---

## 11. Startup & Verification Checklist

Run through this after everything is installed, **before** final
hardware assembly:

```bash
# 1. Check Bridge Server
curl http://localhost:4000/api/health
# Expected: {"status":"ok",...}

# 2. Check Tesseract
tesseract --version
# Expected: 4.x or 5.x

# 3. Check Python env
source ~/scanner-env/bin/activate
python -c "import pytesseract; print('pytesseract OK')"
python -c "import RPi.GPIO; print('GPIO OK')"
python -c "import picamera; print('picamera OK')"
python -c "from rpi_ws281x import PixelStrip; print('rpi_ws281x OK')"

# 4. Test camera (legacy stack)
raspistill -o /tmp/test.jpg && echo "Camera OK"

# 5. Test motor (short move — have motor connected first!)
cd ~/pantree-scanner/receipt-scanner
python -c "
from motor import init_motor, feed_mm, cleanup_motor
init_motor()
feed_mm(5)   # move 5mm forward
cleanup_motor()
print('Motor OK')
"

# 6. Test LED strip (requires sudo! Have strip connected first!)
sudo /home/pi/scanner-env/bin/python -c "
from led import init_leds, leds_on, leds_off, cleanup_leds
import time
init_leds()
leds_on()
time.sleep(2)
leds_off()
cleanup_leds()
print('LEDs OK')
"

# 7. Test full pipeline with a receipt image
python main.py --test /path/to/sample-receipt.jpg

# 8. Check React frontend (if built)
curl -s http://localhost:3000 | head -5
```

---

## 12. Troubleshooting

### Camera not detected

```bash
# Check if camera is recognized
vcgencmd get_camera
# Expected: supported=1 detected=1

# If detected=0:
# - Reseat the ribbon cable (blue side toward Ethernet jack)
# - Enable legacy camera in raspi-config
# - Check /boot/config.txt has: start_x=1 and gpu_mem=128
```

> Do NOT use `libcamera-hello` — it does not work on Pi 1 B+.

### Out of memory during pip install

```bash
# Increase swap to 512 MB
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=512/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Then retry: pip install -r requirements.txt
# After install, you can reduce swap back to 100 MB
```

### GPIO permission denied

```bash
# Add user to gpio group
sudo usermod -aG gpio pi
# Log out and back in, or reboot
```

### NeoPixel LEDs don't light up

```bash
# rpi_ws281x REQUIRES root
sudo /home/pi/scanner-env/bin/python -c "
from led import init_leds, leds_on, cleanup_leds
init_leds()
leds_on()
import time; time.sleep(3)
cleanup_leds()
"

# If still nothing:
# - Check DIN wire goes to GPIO 18 (Physical Pin 12)
# - Check 5V and GND connections
# - Check strip direction (DIN vs DOUT end)
```

### Easy Driver motor not moving

1. Check 12V supply is connected to Easy Driver M+ / GND.
2. Check STEP/DIR/ENABLE wires are on the correct GPIO pins.
3. ENABLE must be LOW (connected to GPIO 22, pulled LOW by code).
4. Test with a simple pulse script (see step 11, test #5).

### Bridge Server port conflict

```bash
sudo lsof -i :4000
# Change port if needed:
PORT=4001 node server.js
```

### WiFi not connecting (USB dongle)

```bash
# Check if the dongle is detected
lsusb
# Should show a wireless adapter entry

# Check interface
iwconfig
# Should show wlan0

# If not connecting, edit wpa_supplicant:
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
# Add:
# network={
#     ssid="YourNetwork"
#     psk="YourPassword"
# }

sudo wpa_cli -i wlan0 reconfigure
```

### Node.js crashes or won't install

```bash
# Verify architecture
uname -m
# Must show: armv6l

# If node --version fails, reinstall from unofficial builds:
NODE_VERSION=18.20.4
cd /tmp
wget https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-armv6l.tar.xz
sudo tar -xJf node-v${NODE_VERSION}-linux-armv6l.tar.xz -C /usr/local --strip-components=1
```

### Tesseract OCR is very slow

This is expected on the Pi 1 B+. Tips to improve speed:
- Use `--psm 6` (assume uniform text block) in pytesseract config.
- Crop receipt images to text regions only before OCR.
- Lower capture resolution if text is still readable.
- Consider running OCR on the Bridge Server (Mac/PC) instead of the Pi.

---

## Quick Reference: Service Commands

```bash
# Start / stop / restart
sudo systemctl start pantree-bridge
sudo systemctl stop pantree-scanner
sudo systemctl restart pantree-bridge

# View logs (live)
journalctl -u pantree-bridge -f
journalctl -u pantree-scanner -f

# Check status
sudo systemctl status pantree-bridge
sudo systemctl status pantree-scanner
```

---

## Performance Notes for Pi 1 B+

| Task                  | Expected Time | Notes                        |
|-----------------------|---------------|------------------------------|
| Boot to login         | ~30-45 s      | Lite OS, no desktop          |
| `npm install`         | 5-15 min      | Depends on packages          |
| `pip install`         | 3-10 min      | May need swap                |
| React `npm run build` | 10-30 min     | Build on Mac instead         |
| Tesseract OCR (1 img) | 20-40 s       | Single core, limited RAM     |
| Camera capture        | 2-3 s         | Including warmup              |
| Full receipt scan     | 2-5 min       | Depends on receipt length    |
