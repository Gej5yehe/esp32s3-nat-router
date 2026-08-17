#!/usr/bin/env bash
# ============================================================
#  flash.sh — Flash esp_nat_router to LilyGo CC1101 Plus
#  (ESP32-S3)
#
#  Usage:
#    chmod +x flash.sh
#    ./flash.sh          # Auto-detect port
#    ./flash.sh COM3     # Specify port (Windows via WSL/Git Bash)
#    ./flash.sh /dev/ttyUSB0  # Linux/macOS
# ============================================================

set -e

# ── CONFIG ───────────────────────────────────────────────────
CHIP="esp32s3"
BAUD="921600"
FLASH_MODE="dio"
FLASH_FREQ="80m"
FLASH_SIZE="16MB"
BUILD_DIR="./build"

BOOTLOADER_BIN="${BUILD_DIR}/bootloader/bootloader.bin"
PARTITION_BIN="${BUILD_DIR}/partition_table/partition-table.bin"
APP_BIN="${BUILD_DIR}/esp_nat_router.bin"

# ── COLORS ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── FUNCTIONS ─────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_err()     { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

detect_port() {
  if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
    # Git Bash / WSL on Windows — list COM ports
    PORT=$(ls /dev/ttyS* 2>/dev/null | head -1)
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PORT=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -1)
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    PORT=$(ls /dev/cu.usbserial-* /dev/cu.SLAB_USB* 2>/dev/null | head -1)
  fi
  echo "$PORT"
}

# ── MAIN ──────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ESP32-S3 NAT Router Flash Script       ║${NC}"
echo -e "${CYAN}║   Board: LilyGo CC1101 Plus              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Port detection
if [ -n "$1" ]; then
  PORT="$1"
  log_info "Using specified port: ${PORT}"
else
  PORT=$(detect_port)
  if [ -z "$PORT" ]; then
    log_err "No serial port detected. Connect the ESP32-S3 and hold BOOT button, then retry.\n       Or specify port manually: ./flash.sh /dev/ttyUSB0"
  fi
  log_info "Auto-detected port: ${PORT}"
fi

# Check esptool
if ! command -v esptool.py &> /dev/null; then
  log_err "esptool.py not found. Install it with: pip install esptool"
fi

# Check build artifacts
log_info "Checking build artifacts..."
[ -f "$BOOTLOADER_BIN" ] || log_err "Bootloader not found: ${BOOTLOADER_BIN}\n       Run: idf.py build"
[ -f "$PARTITION_BIN" ]  || log_err "Partition table not found: ${PARTITION_BIN}"
[ -f "$APP_BIN" ]        || log_err "Application binary not found: ${APP_BIN}"
log_ok "All build artifacts found."

# Confirm
echo ""
log_warn "This will ERASE and reflash the ESP32-S3."
read -p "  Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log_info "Aborted."
  exit 0
fi

# Erase flash
log_info "Erasing flash..."
esptool.py --chip $CHIP --port "$PORT" --baud $BAUD erase_flash
log_ok "Flash erased."

# Write firmware
log_info "Flashing firmware..."
esptool.py \
  --chip $CHIP \
  --port "$PORT" \
  --baud $BAUD \
  --before default_reset \
  --after hard_reset \
  write_flash \
  -z \
  --flash_mode $FLASH_MODE \
  --flash_freq $FLASH_FREQ \
  --flash_size $FLASH_SIZE \
  0x0     "$BOOTLOADER_BIN" \
  0x8000  "$PARTITION_BIN" \
  0x10000 "$APP_BIN"

log_ok "Firmware flashed successfully!"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Done! ESP32-S3 rebooting...              ${NC}"
echo -e "${GREEN}  Connect to Wi-Fi: ESP32_NAT_Router       ${NC}"
echo -e "${GREEN}  Web UI: http://192.168.4.1               ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
