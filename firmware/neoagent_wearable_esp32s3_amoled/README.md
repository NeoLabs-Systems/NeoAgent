# NeoAgent Wearable Firmware

ESP-IDF firmware target for the Waveshare `ESP32-S3-Touch-AMOLED-1.8` wearable client.

## Current structure

- `main/`: boot entrypoint, startup sequencing and the shell loop (call screen, settings, buttons)
- `components/app_shell`: screen routing and shell lifecycle
- `components/board_support`: display, touch, buttons, audio codec and PMU; the LVGL screens (`board_ui.c`) and the mascot renderer (`mascot_view.c`)
- `components/common`: shared wearable data types
- `components/mascot`: the NeoAgent mascot's frames, clip player and mood stabilizer, ported from `flutter_app/lib/src/mascot/` (change both together)
- `components/network`: provisioning and server configuration state
- `components/pairing`: QR login challenge state machine
- `components/storage`: persistent config and session storage in NVS
- `components/telemetry`: structured logging helpers
- `components/ui`: thin screen facade over `board_support`
- `components/updates`: firmware manifest handling
- `components/voice`: live voice call client for `/api/wearable/ws`, plus the PCM resampler

## Voice

The home screen is a voice call with the agent, laid out like the app's phone call: the mascot inside its halo, the call state, live captions and the call controls. Calls run on the server's live voice system (`server/services/voice/live/`): microphone audio streams to the live speech-to-speech model, its reply streams back as PCM, and requests it hands off run as ordinary agent runs.

- Tap **Call**, the mascot, or press **BOOT** to place a call. Tap the mascot while the agent talks to stop it.
- The input mode comes from the agent's voice settings. Hands-free calls open the microphone at once (**Mute** / BOOT press to mute); push-to-talk calls talk while **Hold to talk** or BOOT is held.
- Hold BOOT or tap **End** to hang up. A task still running keeps going on the server and its result lands in chat.
- The board has no echo cancellation, so a hands-free call sends no microphone audio while a reply is audible.

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

The project is structured so hardware-specific drivers can be expanded behind stable interfaces without changing pairing, voice, update, or storage contracts.

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
