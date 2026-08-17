# 🛰️ ESP32-S3 NAT Router — LilyGo CC1101 Plus

> **Full setup guide**: Flashing `esp_nat_router` firmware on a **LilyGo T3S3 CC1101 Plus (ESP32-S3)**, with WireGuard VPN, firewall rules, and advanced network configuration.

<p align="center">
  <img src="https://img.shields.io/badge/Chip-ESP32--S3-blue?style=for-the-badge&logo=espressif" />
  <img src="https://img.shields.io/badge/Board-LilyGo%20CC1101%20Plus-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Firmware-esp__nat__router-green?style=for-the-badge&logo=github" />
  <img src="https://img.shields.io/badge/VPN-WireGuard-blueviolet?style=for-the-badge&logo=wireguard" />
  <img src="https://img.shields.io/badge/Firewall-Configured-red?style=for-the-badge&logo=shield" />
</p>

---

## 📋 Table of Contents

1. [Hardware Overview](#hardware-overview)
2. [Prerequisites](#prerequisites)
3. [Flashing esp_nat_router](#flashing-esp_nat_router)
4. [Initial Configuration](#initial-configuration)
5. [Firewall Setup](#firewall-setup)
6. [WireGuard VPN Configuration](#wireguard-vpn-configuration)
7. [Network Topology](#network-topology)
8. [Troubleshooting](#troubleshooting)
9. [References](#references)

---

## 🔩 Hardware Overview

| Component | Details |
|-----------|---------|
| **Board** | LilyGo T3S3 CC1101 Plus |
| **Chip** | ESP32-S3 (Xtensa LX7 dual-core, 240 MHz) |
| **Flash** | 16 MB |
| **PSRAM** | 8 MB (QSPI) |
| **RF Module** | CC1101 (Sub-GHz transceiver, 315/433/868/915 MHz) |
| **USB** | USB-C (native USB, JTAG capable) |
| **Connectivity** | Wi-Fi 802.11 b/g/n + BLE 5.0 |
| **I/O** | GPIO, SPI, I2C, UART |

---

## ⚙️ Prerequisites

### Software Requirements

```bash
# Install ESP-IDF (v5.x recommended)
git clone --recursive https://github.com/espressif/esp-idf.git
cd esp-idf
./install.sh esp32s3
source ./export.sh

# Or use esptool directly
pip install esptool

# Optional: Install Arduino IDE 2.x with ESP32 board support
```

### Python & Tools

```bash
pip install esptool pyserial
```

### Clone esp_nat_router

```bash
git clone https://github.com/jonask24/esp_nat_router.git
cd esp_nat_router
```

---

## ⚡ Flashing esp_nat_router

### Step 1 — Enter Boot Mode

Hold the **BOOT** button on the LilyGo CC1101 Plus while connecting USB-C to your PC.
Release BOOT after the device is detected.

```bash
# Verify device is detected
esptool.py --port COM3 chip_id   # Windows
esptool.py --port /dev/ttyUSB0 chip_id  # Linux/macOS
```

Expected output:
```
Chip is ESP32-S3(revision v0.2)
Features: WiFi, BLE
Crystal is 40MHz
```

### Step 2 — Erase Flash

```bash
esptool.py --chip esp32s3 --port COM3 erase_flash
```

### Step 3 — Build Firmware

```bash
cd esp_nat_router
idf.py set-target esp32s3
idf.py menuconfig   # Optional: adjust settings
idf.py build
```

### Step 4 — Flash the Firmware

```bash
esptool.py --chip esp32s3 \
  --port COM3 \
  --baud 921600 \
  --before default_reset \
  --after hard_reset \
  write_flash \
  -z \
  --flash_mode dio \
  --flash_freq 80m \
  --flash_size 16MB \
  0x0     build/bootloader/bootloader.bin \
  0x8000  build/partition_table/partition-table.bin \
  0x10000 build/esp_nat_router.bin
```

### Step 5 — Verify Flash

```bash
esptool.py --chip esp32s3 --port COM3 flash_id
```

---

## 🌐 Initial Configuration

After flashing, the ESP32-S3 boots as a Wi-Fi access point:

| Setting | Default Value |
|---------|--------------|
| **AP SSID** | `ESP32_NAT_Router` |
| **AP Password** | `12345678` |
| **AP IP** | `192.168.4.1` |
| **Web UI** | `http://192.168.4.1` |

### Connect & Configure via Web UI

1. Connect your device to the `ESP32_NAT_Router` Wi-Fi network
2. Open a browser → `http://192.168.4.1`
3. Navigate to **Station Configuration**
4. Enter your upstream Wi-Fi SSID and password
5. Click **Connect** — the ESP32-S3 will reboot and bridge the connections

### Configure via Serial (UART)

```bash
# Open serial monitor at 115200 baud
idf.py -p COM3 monitor

# Set upstream Wi-Fi
sta_ssid YourWiFiName
sta_pass YourWiFiPassword

# Set AP credentials
ap_ssid MyNATRouter
ap_pass SecurePassword123!
```

---

## 🔥 Firewall Setup

The `esp_nat_router` uses **lwIP** (Lightweight IP stack) with packet filtering hooks. Below are the configured firewall rules applied via the custom `firewall/rules.c` implementation.

### Firewall Philosophy

```
[Internet / Upstream AP]
        |
   [ESP32-S3 STA]  ← Upstream connection
        |
   [NAT + Firewall] ← Rules applied here
        |
   [ESP32-S3 AP]   ← Downstream client network
        |
  [Your Devices]   192.168.4.x
```

### Active Firewall Rules

See [`firewall/firewall_rules.conf`](firewall/firewall_rules.conf) for full rule set.

**Summary of applied rules:**

| Rule # | Direction | Protocol | Source | Destination | Port | Action |
|--------|-----------|----------|--------|-------------|------|--------|
| 1 | INBOUND | ALL | ANY | ANY | ANY | DROP (default) |
| 2 | OUTBOUND | ALL | 192.168.4.0/24 | ANY | ANY | ACCEPT |
| 3 | INBOUND | TCP | ANY | ANY | 22 | DROP (block SSH from WAN) |
| 4 | INBOUND | TCP | ANY | ANY | 23 | DROP (block Telnet) |
| 5 | INBOUND | UDP | ANY | ANY | 53 | ACCEPT (DNS) |
| 6 | INBOUND | TCP | ANY | ANY | 80,443 | ACCEPT (HTTP/S) |
| 7 | INBOUND | UDP | ANY | ANY | 51820 | ACCEPT (WireGuard) |
| 8 | INBOUND | ICMP | ANY | ANY | - | ACCEPT (ping) |
| 9 | ESTABLISHED | ALL | ANY | ANY | ANY | ACCEPT (stateful) |

### Applying Firewall Config

```bash
# Flash the firewall config via web UI or paste into nvs
# Or apply via serial:
fw_rule add inbound tcp 0.0.0.0/0 22 drop
fw_rule add inbound tcp 0.0.0.0/0 23 drop
fw_rule add inbound udp 0.0.0.0/0 51820 accept
fw_rule add outbound all 192.168.4.0/24 0 accept
fw_rule apply
```

---

## 🔐 WireGuard VPN Configuration

`esp_nat_router` includes WireGuard support via **WireGuard-ESP32** (embedded implementation).

### ESP32-S3 WireGuard Interface

See [`vpn/wg0.conf`](vpn/wg0.conf) for the full WireGuard config.

```ini
[Interface]
PrivateKey = <ESP32_PRIVATE_KEY>
Address = 10.0.0.1/24
ListenPort = 51820
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <PEER_PUBLIC_KEY>
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = <YOUR_VPN_SERVER_IP>:51820
PersistentKeepalive = 25
```

### Generate Keys

```bash
# Generate ESP32 key pair
wg genkey | tee esp32_private.key | wg pubkey > esp32_public.key

# Generate peer key pair (for your client device)
wg genkey | tee peer_private.key | wg pubkey > peer_public.key

# View keys
cat esp32_private.key
cat esp32_public.key
```

### Apply WireGuard Config via Web UI

1. Go to `http://192.168.4.1` → **VPN Settings**
2. Paste your private key in **WireGuard Private Key**
3. Add peer public key
4. Set endpoint and AllowedIPs
5. Click **Save & Apply**

### Apply via Serial

```bash
wg_privkey <your_esp32_private_key_base64>
wg_peer_pubkey <peer_public_key_base64>
wg_endpoint <server_ip>:51820
wg_allowed_ips 0.0.0.0/0
wg_keepalive 25
wg_enable 1
```

### Verify WireGuard Status

```bash
# Via serial monitor
wg_status

# Expected output:
# interface: wg0
#   public key: xxxx...
#   listening port: 51820
# peer: xxxx...
#   endpoint: x.x.x.x:51820
#   allowed ips: 0.0.0.0/0
#   latest handshake: X seconds ago
#   transfer: X MiB received, X MiB sent
```

---

## 🗺️ Network Topology

```
                    ┌─────────────────────────────────────┐
                    │          INTERNET / WAN              │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────┐
                    │       Upstream Wi-Fi Router          │
                    │       192.168.1.1  (ISP/Home)        │
                    └──────────────┬──────────────────────┘
                                   │ Wi-Fi (STA mode)
                    ┌──────────────▼──────────────────────┐
                    │     LilyGo CC1101 Plus               │
                    │     ESP32-S3 NAT Router              │
                    │  ┌────────────────────────────────┐ │
                    │  │  STA: 192.168.1.X (DHCP)       │ │
                    │  │  AP:  192.168.4.1/24           │ │
                    │  │  WireGuard: 10.0.0.1/24        │ │
                    │  │  Firewall: lwIP packet filter  │ │
                    │  └────────────────────────────────┘ │
                    └──────────────┬──────────────────────┘
                                   │ Wi-Fi AP (802.11n)
               ┌───────────────────┼───────────────────┐
               │                   │                   │
  ┌────────────▼──┐    ┌───────────▼───┐   ┌──────────▼───┐
  │   Laptop      │    │   Phone       │   │   IoT Device  │
  │ 192.168.4.2   │    │ 192.168.4.3   │   │ 192.168.4.4   │
  └───────────────┘    └───────────────┘   └───────────────┘
```

---

## 🔧 Troubleshooting

### Device Not Detected in Boot Mode

```bash
# Check available COM ports (Windows)
Get-WmiObject Win32_PnPEntity | Where-Object {$_.Name -like "*COM*"}

# Check USB (Linux)
lsusb | grep Espressif
dmesg | tail -20
```

### Flash Fails

```bash
# Try lower baud rate
esptool.py --baud 115200 --port COM3 write_flash ...

# Try with --no-stub flag
esptool.py --no-stub --chip esp32s3 --port COM3 write_flash ...
```

### Wi-Fi Won't Connect to Upstream

- Verify SSID/password in web UI at `http://192.168.4.1`
- Ensure upstream router is 2.4 GHz (ESP32-S3 does NOT support 5 GHz)
- Check signal strength — move ESP32-S3 closer to router

### WireGuard Handshake Fails

```bash
# Check firewall isn't blocking UDP 51820
# Verify server endpoint is reachable from ESP32's upstream network
# Confirm public keys match on both ends
```

### Web UI Not Accessible

```bash
# Hard reset the device
# Connect to ESP32_NAT_Router AP
# Try 192.168.4.1 in browser (not https)
```

---

## 📚 References

- [esp_nat_router GitHub](https://github.com/jonask24/esp_nat_router)
- [ESP32-S3 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf)
- [LilyGo T3S3 Schematic](https://github.com/Xinyuan-LilyGO/LilyGo-LoRa-Series)
- [WireGuard Protocol](https://www.wireguard.com/protocol/)
- [lwIP Documentation](https://www.nongnu.org/lwip/2_0_x/index.html)
- [esptool.py Docs](https://docs.espressif.com/projects/esptool/en/latest/)

---

## 📄 License

MIT License — feel free to use, modify, and share.

---

<p align="center">Made with ❤️ — ESP32-S3 NAT Router Project by <b>Gej5yehe</b></p>
