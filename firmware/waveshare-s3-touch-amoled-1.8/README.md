# Waveshare ESP32-S3 Touch AMOLED 1.8 Firmware

This firmware target is the dedicated NeoAgent wearable runtime for the Waveshare ESP32-S3 Touch AMOLED 1.8 board.

## Current Implementation Slice

- First-boot setup AP + captive setup web page
- Persistent config storage in NVS:
  - Backend URL
  - Device name
  - Pairing code
  - Device token (issued after pairing claim)
  - Up to 5 Wi-Fi profiles
- Automatic station connect using saved profiles
- Automatic pairing claim against backend using pairing code
- Authenticated heartbeat to backend device endpoint
- Live SH8601 QSPI response card rendering on-device (newest-first)
- Hold-to-record PCM capture over ES8311/I2S path and stream upload during hold
- Record release triggers utterance generation and multi-response polling/ack rendering
- AP fallback when no profile can connect
- BOOT long-press (4.5s) to clear setup and re-enter AP mode

## Build and Flash

From repository root:

```bash
cd firmware/waveshare-s3-touch-amoled-1.8
source ~/esp-idf-v5.5.1/export.sh
idf.py set-target esp32s3
cd ../../
./dev/flash-waveshare-wearable.sh /dev/cu.usbmodem101
```

Alternative wrapper that clears stale monitor processes first:

```bash
./scripts/flash_waveshare_wearable.sh /dev/cu.usbmodem101
```

Environment options:

- `NEO_IDF_PATH` to override ESP-IDF location (default: `$HOME/esp-idf-v5.5.1`)
- `ESPPORT` to set serial port
- `ESPBAUD` to set baud rate
