---
title: Hardware
sidebar_label: Hardware
description: The ESP32-S3 wearable firmware target shipped in the repository.
---

# Hardware

**Optional firmware that turns a small ESP32-S3 board into a push-to-talk voice client for your agent.**

## 🧩 What you need

| Part | Details |
| --- | --- |
| Board | Waveshare ESP32-S3-Touch-AMOLED-1.8: 368×448 AMOLED touch screen, ES8311 audio codec, AXP2101 battery chip |
| Firmware | `firmware/neoagent_wearable_esp32s3_amoled`, an ESP-IDF 5.x project |
| Server | A NeoAgent server the board can reach, with a [live voice](models.md#live-voice) provider key |
| Phone | The NeoAgent Android app, signed in, to approve pairing |

## 🔌 Flash it

- **Prebuilt.** Every release attaches `neoagent-wearable-firmware.bin`, its bootloader, partition table and a `.sha256` checksum.
- **From source.** With ESP-IDF 5.x installed, run the helper from the repository root. It sets the `esp32s3` target, builds and flashes.

```bash
./scripts/flash_wearable.sh --monitor
```

| Flag | Effect |
| --- | --- |
| `--port <device>` | Use this serial port |
| `--erase` | Erase flash first |
| `--skip-build` | Flash the existing build |
| `--monitor` | Open the serial monitor afterwards |

## 📶 Pair it

1. Join the board's Wi-Fi hotspot, **NeoAgent Setup XXXX**. The setup page opens at `http://192.168.4.1`.
2. Enter your NeoAgent server URL, your Wi-Fi network and password, and an optional device name.
3. The board shows a QR code.
4. In the Android app, open **Settings › Sign-in & security › Approve QR login** and scan it.

The board stays signed in for 90 days.

## 🎙️ Use it

- **Hold to talk.** Hold the mascot on screen (or the BOOT button), speak, let go to send.
- **Always push-to-talk.** The board ignores the hands-free setting. There is no wake word.
- **Tap to interrupt.** A short tap stops the agent's reply.
- **Hangs up by itself.** After 60 seconds with nothing said, played or running. A task that outlives the call lands in chat.
- **Real work runs in the background.** The live voice model hands tool work to normal agent runs, same as in-app calls.

## 🔄 Updates

- **Automatic.** The board checks its server for newer firmware 90 seconds after boot, then hourly.
- **Battery-aware.** Updates wait below 30 % battery unless external power is connected.
- **Safe rollback.** A failed update boots the previous firmware.

Automation can react to the board too: see the `wearable_connection_changed` trigger in [Automation](automation.md).
