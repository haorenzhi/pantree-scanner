#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-${PI_HOST:-horange@172.20.10.10}}"
REMOTE_DIR="${PI_REMOTE_DIR:-/home/horange/pantree-scanner}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required on this Mac." >&2
  exit 1
fi

echo "== Pantree Pi 5 scanner deploy =="
echo "Target:     $TARGET"
echo "Remote dir: $REMOTE_DIR"
echo

echo "[1/5] Creating remote project directory..."
ssh "$TARGET" "mkdir -p '$REMOTE_DIR'"

echo "[2/5] Installing Raspberry Pi OS packages..."
ssh -t "$TARGET" "sudo apt update && sudo apt install -y \
  rsync \
  python3-venv \
  python3-pip \
  python3-picamera2 \
  python3-libcamera \
  python3-gpiozero \
  python3-lgpio \
  python3-pil \
  python3-numpy \
  python3-requests \
  tesseract-ocr \
  curl \
  ca-certificates"

echo "[2b/5] Installing Node.js LTS from NodeSource (avoids apt npm/libssl conflict)..."
ssh -t "$TARGET" "if ! command -v node >/dev/null 2>&1; then \
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && \
    sudo apt install -y nodejs; \
  else echo \"node \$(node --version) already installed\"; fi"

echo "[3/5] Copying scanner, bridge server, and web build..."
rsync -az --delete \
  --exclude '__pycache__/' \
  --exclude '.pytest_cache/' \
  --exclude '.DS_Store' \
  "$REPO_ROOT/receipt-scanner/" "$TARGET:$REMOTE_DIR/receipt-scanner/"

rsync -az --delete \
  --exclude 'node_modules/' \
  --exclude 'pantree-data.json' \
  --exclude '.DS_Store' \
  "$REPO_ROOT/bridge-server/" "$TARGET:$REMOTE_DIR/bridge-server/"

if [ -d "$REPO_ROOT/build" ]; then
  rsync -az --delete \
    --exclude '.DS_Store' \
    "$REPO_ROOT/build/" "$TARGET:$REMOTE_DIR/build/"
fi

echo "[4/5] Creating Python venv and installing scanner Python packages..."
ssh "$TARGET" "cd '$REMOTE_DIR' && \
  python3 -m venv --system-site-packages .venv && \
  . .venv/bin/activate && \
  python -m pip install --upgrade pip && \
  python -m pip install -r receipt-scanner/requirements.txt"

echo "[5/5] Installing bridge server packages..."
ssh "$TARGET" "cd '$REMOTE_DIR/bridge-server' && npm install --omit=dev"

cat <<EOF

Deploy complete.

Next manual checks on the Pi:
  ssh $TARGET
  cd $REMOTE_DIR/receipt-scanner
  source ../.venv/bin/activate

Test button:
  python test_button.py

Test camera snapshot + OCR without motor:
  python main.py --no-motor

Run bridge server in another SSH session:
  cd $REMOTE_DIR/bridge-server
  npm start

Then run full scanner:
  cd $REMOTE_DIR/receipt-scanner
  source ../.venv/bin/activate
  python main.py

EOF
