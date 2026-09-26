---
title: Clients and device bridges
sidebar_label: Clients and device bridges
description: Application modes, backend communication, Android bridges, and how local computer control is registered.
---

# Clients and device bridges

*One root state object, several targets, native code where it is required.*

The Flutter project uses one root `ChangeNotifier` and shared feature models
across web, Android, and desktop targets. Platform-specific side effects are
implemented through bridge classes and native host code.

## 🧭 Application modes

The standard mode provides the full NeoAgent client. The launcher mode uses a
separate Android application ID and enables the home-screen launcher activity,
hardware-button events, device settings, and pairing.

Build mode is selected at compile time. Release artifacts distinguish standard
and launcher APKs.

## 🙂 Mascot

The live mascot ([user guide](mascot.md)) is split so the widget stays thin:

- `lib/src/mascot/mascot_frames.dart` — the 9×9 frames and clips for each mood
- `lib/src/mascot/mascot_mood.dart` — `MascotMood` and `MascotMoodStabilizer` (dwell times, one-shot done/blocked)
- `lib/src/mascot/neo_mascot.dart` — `NeoMascot`: frames step on timers, only cross-fades use the ticker
- `lib/main_mascot.dart` — maps controller state to a mood and drives `_LiveMascot`

`landing/js/mascot.js` draws the same frames in SVG for the landing page. The
frame tables exist in both files, so change them together.

## 🔌 Backend communication

The backend client wraps authenticated HTTP calls. Socket.IO streams chat
tokens, run events, approvals, messaging events, device state, and operational
updates into `MainController`, which notifies the relevant UI.

## 🤖 Android bridges

Native Kotlin code handles Health Connect, notifications, launcher functions,
and telecom integration. Flutter bridges normalize
permission and lifecycle behavior before updating application state.

## 🖥️ Cloud computer display

All clients open the same authenticated Linux computer display through a
short-lived same-origin session. Input follows the server-issued control lease;
files and terminal panels address the same guest and persistent data disk.

## 💻 Local computer control

The macOS, Windows, and Linux desktop builds can register **This device** over
an outbound session-authenticated WebSocket. It implements the same Computer
provider contract as the QEMU guest. The app reports OS capture/accessibility
state and adds independent, revocable approvals for screen, input, files, and
shell/app actions. Web and mobile clients can select or observe the cloud
provider, but cannot volunteer their host as a local computer.

## 📱 ADB device control

ADB control is a server capability exposed through the Android service and
routes. It is independent of the Flutter Android client and can target an
emulator or physical device attached to the NeoAgent host.
