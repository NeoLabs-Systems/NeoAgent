# Clients and device bridges

The Flutter project uses one root `ChangeNotifier` and shared feature models
across web, Android, and desktop targets. Platform-specific side effects are
implemented through bridge classes and native host code.

## Application modes

The standard mode provides the full NeoAgent client. The launcher mode uses a
separate Android application ID and enables the home-screen launcher activity,
hardware-button events, device settings, and pairing.

Build mode is selected at compile time. Release artifacts distinguish standard
and launcher APKs.

## Backend communication

The backend client wraps authenticated HTTP calls. Socket.IO streams chat
tokens, run events, approvals, messaging events, device state, and operational
updates into `MainController`, which notifies the relevant UI.

## Android bridges

Native Kotlin code handles Health Connect, notifications, launcher functions,
and telecom integration. Flutter bridges normalize
permission and lifecycle behavior before updating application state.

## Cloud computer display

All clients open the same authenticated Linux computer display through a
short-lived same-origin session. Input follows the server-issued control lease;
files and terminal panels address the same guest and persistent data disk.

## Local computer control

The macOS, Windows, and Linux desktop builds can register **This device** over
an outbound session-authenticated WebSocket. It implements the same Computer
provider contract as the QEMU guest. The app reports OS capture/accessibility
state and adds independent, revocable approvals for screen, input, files, and
shell/app actions. Web and mobile clients can select or observe the cloud
provider, but cannot volunteer their host as a local computer.

## ADB device control

ADB control is a server capability exposed through the Android service and
routes. It is independent of the Flutter Android client and can target an
emulator or physical device attached to the NeoAgent host.
