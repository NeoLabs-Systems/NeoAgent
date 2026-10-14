---
title: Devices and interfaces
sidebar_label: Devices
description: The computers and Android device NeoAgent can operate, plus every app and device that talks to your server.
---

# Devices and interfaces

**NeoAgent can operate a cloud computer, your own desktop and an Android emulator, and every app talks to the same server.**

Open **Devices** in the app, which has a **Computer** tab and an **Android** tab.

## ☁️ Cloud computer

Each account gets its own Linux computer on the NeoAgent server, where the agent's browser, shell and file tools run.

| Backend (`TERMINAL_ENV`) | What you get |
| --- | --- |
| `qemu` (default) | A Debian desktop VM with live view. Uses KVM, HVF or WHPX when available, otherwise slower software emulation. |
| `docker` | A per-user container with shell, browser and files. No desktop view. |
| `host` | Shell and workspace files on the server itself. No isolation, browser or desktop. |

- **Desktop.** Openbox with a tint2 launcher, PCManFM, Chromium, Mousepad, LXTerminal, Python and Git.
- **Live view.** **View desktop** opens a noVNC display in the app to follow the agent.
- **Take control.** **Interrupt AI** pauses the agent's run and hands you the mouse and keyboard.
- **Shared control.** The agent takes control back on its next computer action. Control lapses after 35 idle minutes.
- **Persistent.** Files and signed-in browser sessions survive between runs.

See [Security and permissions](security-boundaries.md#cloud-computer-backends) for what each backend isolates.

### Browser on protected sites

- **Referrer modes.** `browser_navigate` accepts `referrerMode` `direct` (default), `google` or `current`.
- **One retry.** When a bot challenge is detected on a direct visit, it retries once with a Google referrer.
- **Reported, not hidden.** Results include `botDetection`, so a blocked page is reported as blocked.
- **Your responsibility.** Automation must follow each site's terms and applicable law.

### Teach Mode {#teach-mode}

- **Show, then reuse.** Press **Teach**, answer **What should NeoAgent learn?**, do the task on the desktop, then press **Finish**.
- **Cloud only.** Teach Mode needs the cloud computer with its desktop view (QEMU backend).
- **What it records.** Clicks, keys, navigation, windows, commands, file changes, accessibility and page context.
- **Private by default.** Typed text is replaced by a placeholder; screenshots are skipped while a password field is visible.
- **Deleted afterwards.** The encrypted recording is purged once the skill is created.

The result is a skill; see [Skills and MCP](skills.md).

## 💻 This device

The desktop app for macOS, Windows and Linux can lend your own computer: switch the provider from **Cloud** to **This device**.

| Grant | Lets the agent |
| --- | --- |
| Screen | See what is on your screen |
| Mouse & keyboard | Click, type and move through your apps |
| Workspace files | Read and edit files in `~/NeoAgent Workspace` |
| Commands & apps | Run terminal commands and open apps or web pages |

- **Asked per grant.** Each prompt offers **Allow once**, **Always allow** or **Not now**.
- **Revoke any time.** Deselect a grant under **Access permissions**.
- **Outbound connection.** The app connects to your server; nothing listens on your machine.
- **No Teach Mode** on this device.

## 🤖 Android

- **Emulator, not your phone.** Each account gets its own Android emulator on the NeoAgent server, controlled over ADB.
- **Start it** with **Start Android**, or let the agent start it. The screen view accepts taps and swipes.
- **What the agent can do.** Screenshots, UI dumps, tap, long-press, swipe, type, keys, open apps and intents, install `.apk`/`.apks`, and `adb shell`.
- **Approvals.** `android_shell`, app installs and app or intent launches ask first by default.

## 📱 Apps

| App | Platforms | Notes |
| --- | --- | --- |
| Web | Any browser | Served by your server at `/app` |
| Desktop | macOS, Windows, Linux | Adds **This device** control |
| Android | APK | Health Connect, phone triggers, home-screen widgets, incoming agent calls |
| Android launcher | APK | Replaces the home screen with a voice-first assistant |

- **No iOS app yet.** There is no browser extension.
- **Voice assistant.** Live spoken calls through OpenAI GPT-Live or Google Gemini Live, hands-free or hold-to-talk.
- **Phone triggers.** **Location triggers** and **Notification triggers** (Android only) feed [automation](automation.md).
- **Widgets.** **NeoAgent status** and **Call NeoAgent** for the Android home screen.
- **Android Auto.** A **Voice mode** tile starts a voice call.

### When the agent calls you

- **`call_user` rings the app.** Signed-in NeoAgent apps ring for 30 seconds. It never dials a phone number.
- **Full-screen on Android.** An incoming call with **Answer** and **Decline**, shown over the lock screen.
- **Live on answer.** The agent speaks first in a live voice call.
- **Approval.** The **Call User** category asks first by default.

## ⌚ Wearable

- **Board.** Waveshare ESP32-S3-Touch-AMOLED-1.8, firmware in the repository. See [Hardware](hardware.md).
- **Push-to-talk.** Hold the mascot (or BOOT) to talk, release to send, tap to stop the reply. There is no wake word.
- **Setup.** Enter Wi-Fi and your server URL on its setup hotspot, then pair by QR sign-in.
- **Live voice.** The wearable opens a live voice session with your agent and hangs up after 60 idle seconds.

## 🔗 Related

- [Health](health.md): Health Connect data from the Android app
- [Security and permissions](security-boundaries.md): what each capability may do
- [Clients and device bridges](clients-and-devices.md): implementation details
