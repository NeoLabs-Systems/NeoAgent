# Devices and interfaces

NeoAgent clients connect to one self-hosted server. A client interface does not
move the server-side data or tools onto that client unless a device is
explicitly paired as a runtime backend.

## Web interface

The web interface provides chat, runs, tasks, agents, integrations, memory,
devices, health, settings, permissions, and logs. It is served by
the NeoAgent backend.

## Android app

The Android app connects to the same backend and adds:

- Health Connect synchronization
- Android notification forwarding
- Native notifications and device pairing

The normal Android app is distinct from the Android device that the agent
controls over ADB.

## Launcher mode

NeoAgent also has an Android launcher build. It provides an integrated home
experience, pairing, device controls, and hardware-button
integration. Launcher releases use a separate application package from the
standard Android client.

## Desktop companion

The Flutter desktop client can pair with a server. When selected in settings,
shell and desktop-control actions run on the paired desktop with that user's
permissions. Pair only a machine and OS account that the agent is allowed to
operate.

## Chrome extension

The bundled extension pairs a Chrome profile with NeoAgent. Browser actions can
then run in that profile instead of the isolated server browser.

Download the extension from `/api/browser-extension/download`, load the
unpacked directory through `chrome://extensions`, and pair it after signing in.
Use a dedicated browser profile because pairing grants the agent access to its
open sessions and sites.

## Android control

NeoAgent controls a server-attached emulator or physical Android device over
ADB. The agent can inspect screenshots and UI nodes, tap, swipe, type, launch
apps and intents, install application bundles, and run `adb shell`.

If NeoAgent runs on a remote server, it controls the Android device attached to
that server, not the phone displaying the NeoAgent client.

## Wearable firmware

The repository includes an ESP-IDF firmware target for the Waveshare ESP32-S3
Touch AMOLED 1.8 board. This is a source-level hardware target, not part of the
npm installer. See [Hardware](hardware.md).
