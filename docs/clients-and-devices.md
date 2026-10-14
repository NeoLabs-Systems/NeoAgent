---
title: Clients and device bridges
sidebar_label: Clients and device bridges
description: Application modes, backend communication, Android bridges, and how local computer control is registered.
---

# Clients and device bridges

**One Flutter codebase builds the web, Android and desktop apps; native code covers what Flutter cannot, and every client talks to the same server API.**

## Targets

| Target | Build | Notes |
|---|---|---|
| Web | `flutter build web` into `server/public` | Served at `/app`; built by the release pipeline only |
| Android | `flutter build apk` | Application ID `com.neoagent.flutter_app` |
| Android launcher | `NEOAGENT_ANDROID_LAUNCHER_MODE=true`, `-t lib/main_launcher_entry.dart` | Application ID `com.neoagent.flutter_app.launcher`; replaces the home screen |
| macOS, Windows, Linux | `flutter build macos`, `windows`, `linux` | Can install a local server and act as the local computer |
| Wearable | `firmware/neoagent_wearable_esp32s3_amoled` (ESP-IDF) | ESP32-S3, push-to-talk voice |

- **No iOS.** There is no iOS build.
- **Release names.** Android releases ship `neoagent-android-<version>.apk` and `neoagent-android-launcher-<version>.apk`.

## App structure

| Piece | Location |
|---|---|
| Root state | `MainController` in `lib/main_controller.dart`, the only global `ChangeNotifier` |
| Screens | `lib/main_*.dart` (parts of `lib/main.dart`) and `lib/features/` |
| Platform logic | `lib/src/*_bridge.dart` and `lib/src/*_service.dart` |
| Platform variants | `_io`, `_web` and `_stub` files behind conditional exports |
| HTTP | `lib/src/backend_client.dart` on `lib/src/network/app_http_client*.dart` |
| Real time | `socket_io_client`; events update `MainController`, which notifies the UI |
| Strings | `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, generated into `lib/l10n/gen/` |

- **Discovery.** Desktop and mobile apps find servers on the LAN over mDNS (`_neoagent._tcp.local`) and confirm with `GET /api/setup/handshake`.
- **Setup contract.** `lib/src/setup_contract.g.dart` is generated from `lib/setup/contract.json` by `scripts/generate_setup_contract.js`.

## Android native code

Kotlin lives in `android/app/src/main/kotlin/com/neoagent/flutter_app/`.

| Feature | Native side | Flutter side |
|---|---|---|
| Agent calls | `telecom/NeoAgentConnectionService.kt`, `call/CallBridge.kt` (channel `neoagent/telecom`) | `lib/src/call/call_bridge.dart` |
| Android Auto | `auto/NeoAgentCarAppService.kt` | `lib/src/android_auto_bridge.dart` |
| Health Connect | `health/HealthSyncWorker.kt` posts to `/api/mobile/health/sync` | `lib/src/health_bridge.dart` |
| Home widgets | `widgets/StatusWidgetProvider.kt`, `widgets/CallWidgetProvider.kt` | `lib/src/home_widget_bridge.dart` |
| Launcher | Channels `neoagent/launcher_device`, `neoagent/launcher_buttons` | `lib/src/android_launcher_bridge.dart` |
| Live voice audio | `voice/VoicePcmPlayer.kt` (channel `neoagent/voice_audio`) | `lib/src/live_voice_player.dart` |
| Notifications | `notification_listener_service` plugin | `lib/features/notifications/` posts to `/api/triggers/notification` |
| Location | `geolocator` plugin | Geofence events post to `/api/triggers/geofence` |

- **Background work.** Health sync and widget refresh run in WorkManager jobs and call the server natively while the app is closed.
- **Calls.** `call_user` emits `voice:incoming_call`; Android rings through the Telecom `ConnectionService`, and accepting opens a live voice session.

## Cloud computer display

1. The app asks for a display session; the server issues a token valid for 5 minutes.
2. The noVNC client loads from `/api/computer/novnc`.
3. It connects to `/api/computer/display-ws` with the token and the session cookie.
4. Input is accepted only while the user holds the control lease.

## Local computer

- **Registration.** Desktop apps connect outbound to `/api/computer/local/ws` with the signed-in session.
- **Implementation.** `lib/src/desktop_companion_io.dart`; screen capture in `lib/src/desktop_screen_capture_io.dart`.
- **Permissions.** `screen`, `input`, `files` and `shell`, each granted once or always, denied or revoked in the app.
- **Limits.** Web and mobile clients can select or watch the cloud computer but cannot register as the local computer.
- **Details.** See [Runtime and tool execution](runtime-and-tools.md#local-computer).

## Local server install

Desktop apps can install the server on the same machine from the signed runtime; see [Runtime packaging and trust](runtime-packaging.md).

## Wearable

- **Gateway.** The ESP32-S3 wearable connects to `/api/wearable/ws` with a session and streams push-to-talk audio into a live voice session.
- **Firmware updates.** `services/wearable/firmware_manifest.js` reads `neoagent-wearable-firmware.bin` from GitHub releases.
- **Flashing.** `scripts/flash_wearable.sh` builds and flashes a connected board with ESP-IDF.

## ADB device control

ADB control is a server capability that drives an emulator or a device attached to the NeoAgent host, independent of the Flutter Android app ([details](runtime-and-tools.md#android)).

## Mascot

The live mascot ([user guide](mascot.md)) is a 9×9 dot-matrix face drawn from one frame table.

| File | Role |
|---|---|
| `lib/src/mascot/mascot_frames.dart` | Frames and clips for each mood (source of truth) |
| `lib/src/mascot/mascot_mood.dart` | `MascotMood` and `MascotMoodStabilizer` (dwell times, one-shot done and blocked) |
| `lib/src/mascot/neo_mascot.dart` | `NeoMascot` widget: frames step on timers, only cross-fades use the ticker |
| `lib/main_mascot.dart` | Maps controller state to a mood and drives `_LiveMascot` |
| `tool/render_widget_faces.dart` | Renders the Android home-widget faces from the Dart frames |

:::warning Frame tables are duplicated
`landing/js/mascot.js` (landing page) and `firmware/neoagent_wearable_esp32s3_amoled/components/mascot/mascot_frames.c` (wearable) copy the Dart frames, so change all three together.
:::
