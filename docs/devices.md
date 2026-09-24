---
title: Devices and interfaces
sidebar_label: Devices
description: The Computer and Android surfaces NeoAgent can drive, plus every client that talks to the same server.
---

# Devices and interfaces

*One server, several surfaces — a Linux desktop, your own machine, and Android.*

NeoAgent exposes two agent-controlled devices: **Computer** and **Android**.
The web, mobile, and desktop clients all connect to the same NeoAgent server
and show the same device model.

## 🖥️ Computer

Computer offers two locations without splitting the tools or UI: a persistent,
isolated Linux cloud computer or **This device** in the NeoAgent desktop app.
Browser, desktop, files, terminal, and Python-capable shell tools all go
through the same agent loop and selected provider.

The guest is a deliberately small Debian desktop with Openbox, Tint2, PCManFM,
Chromium, Mousepad, LXTerminal, Python, Git, and standard Unix tools. A
same-origin noVNC display lets the user watch the agent or take an exclusive
control lease. Files and terminal are panels within Computer, not separate
devices.

Teach Mode records a user demonstration in this computer. It combines input
events with browser semantics, Linux accessibility, shell events, file changes,
and masked screenshots. NeoAgent synthesizes and validates an adaptive skill,
then deletes the encrypted recording data.

On macOS, Windows, and Linux, **This device** uses an outbound authenticated
connection from the signed-in desktop app. The user separately approves screen
observation, mouse/keyboard input, the scoped `NeoAgent Workspace`, and local
CLI/app access. Every permission can be granted once, remembered, denied, or
revoked. Teach Mode currently remains available only for the cloud provider.

## 🤖 Android

NeoAgent controls a server-attached emulator or physical Android device over
ADB. It can inspect screenshots and UI nodes, tap, swipe, type, launch apps and
intents, install application bundles, and run `adb shell`.

:::note Remote server, remote device
If NeoAgent runs on a remote server, it controls the Android device attached to
that server, not the phone displaying the NeoAgent client. Android Teach Mode
is not part of the first release.
:::

## 📱 Client interfaces

The Flutter web, Android, desktop, and Android launcher applications are user
interfaces for the same server. The standard Android client can additionally
synchronize Health Connect data and forward notifications. Wearable firmware
remains a separate source-level hardware target; see [Hardware](hardware.md).

## 🔗 Related

- [Health](health.md) — Health Connect data from the Android client
- [Security and permissions](security-boundaries.md) — what each capability is allowed to do
- [Clients and device bridges](clients-and-devices.md) — implementation details
