# NeoAgent Wearable Firmware

ESP-IDF firmware target for the Waveshare `ESP32-S3-Touch-AMOLED-1.8` wearable client.

## Current structure

- `main/`: boot entrypoint and top-level startup sequencing
- `components/app_shell`: screen routing and shell lifecycle
- `components/board_support`: power-state and board-facing abstractions
- `components/common`: shared wearable data types
- `components/network`: provisioning and server configuration state
- `components/pairing`: QR login challenge state machine
- `components/storage`: persistent config and session storage in NVS
- `components/telemetry`: structured logging helpers
- `components/ui`: UI state model for wearable screens
- `components/updates`: firmware manifest handling
- `components/voice`: raw wearable voice message codec and session state
- `components/widgets`: widget snapshot cache and decode helpers

## Build

1. Install ESP-IDF `5.x`.
2. Set your target:

```bash
idf.py set-target esp32s3
```

3. Build:

```bash
idf.py build
```

The project is structured so hardware-specific drivers can be expanded behind stable interfaces without changing pairing, widget, voice, or storage contracts.

## Managed components

The project declares the following managed dependencies in [`main/idf_component.yml`](./main/idf_component.yml):

- `espressif/esp_websocket_client`
- `espressif/network_provisioning`
- `espressif/qrcode`

This matches current Espressif guidance where WebSocket and provisioning-related pieces are consumed through the component registry rather than assumed to be bundled in every ESP-IDF release.

## Flashing

Use the repo helper from the root:

```bash
./scripts/flash_wearable.sh --monitor
```

Options:

- `--port /dev/cu.usbmodemXXXX` to force a serial port
- `--erase` to erase flash first
- `--skip-build` to flash an already-built image
