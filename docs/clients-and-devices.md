# Clients and device bridges

The Flutter project uses one root `ChangeNotifier` and shared feature models
across web, Android, and desktop targets. Platform-specific side effects are
implemented through bridge classes and native host code.

## Application modes

The standard mode provides the full NeoAgent client. The launcher mode uses a
separate Android application ID and enables the home-screen launcher activity,
hardware-button events, device settings, pairing, and launcher widgets.

Build mode is selected at compile time. Release artifacts distinguish standard
and launcher APKs.

## Backend communication

The backend client wraps authenticated HTTP calls. Socket.IO streams chat
tokens, run events, approvals, messaging events, device state, and operational
updates into `MainController`, which notifies the relevant UI.

## Android bridges

Native Kotlin code handles Health Connect, background recording,
notifications, launcher functions, telecom integration, and Android home
widgets. Flutter bridges normalize permission and lifecycle behavior before
updating application state.

## Desktop and Chrome pairing

Desktop companions and browser extensions authenticate with the server and
register under the owning user. The runtime manager chooses them only when the
user has selected that backend and the registered device is online.

The Chrome extension uses the protocol in
`extensions/chrome-browser/protocol.mjs`. Protocol changes require matching
updates to the extension and backend gateway.

## ADB device control

ADB control is a server capability exposed through the Android service and
routes. It is independent of the Flutter Android client and can target an
emulator or physical device attached to the NeoAgent host.
