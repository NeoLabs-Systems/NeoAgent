# NeoAgent — Android Live Notifications

An Android 16 companion app for NeoAgent.  
Runs a 24/7 background service that connects to your NeoAgent instance over Socket.IO
and surfaces every agent task as a **Live Update** notification — promoted to the
status bar chip, lock screen, and top of the notification shade in real time.

---

## What it looks like

| State | Notification |
|---|---|
| **Thinking** | Indeterminate violet progress bar + elapsed chronometer chip |
| **Tool running** | Determinate progress + tool name chip (e.g. "Browser") |
| **Complete** | Full bar in green + "Done" chip · auto-dismissed after 8 s |
| **Error** | Partial bar in red + "Failed" chip · auto-dismissed after 8 s |

---

## Requirements

| Requirement | Value |
|---|---|
| Android | **16 (API 36)** — Live Update API |
| Architecture | `arm64-v8a` or `x86_64` (emulator) |
| NeoAgent | Any recent version with WebSocket enabled |

---

## Setup

### 1 — Configure the build

```bash
cd mobile/android
cp local.properties.example local.properties
```

Edit `local.properties`:

```properties
# IP of your NeoAgent server (no trailing slash)
BACKEND_URL=http://192.168.1.100:3000

# Same credentials you use for the web UI
AUTH_USERNAME=admin
AUTH_PASSWORD=yourpassword
```

These values are baked into the APK at compile time via `BuildConfig`.  
**Never commit `local.properties`** — it is already in `.gitignore`.

### 2 — Build

```bash
# Debug APK  (fastest)
./gradlew assembleDebug

# Release APK  (obfuscated, needs a signing keystore)
./gradlew assembleRelease
```

Output: `app/build/outputs/apk/debug/app-debug.apk`

### 3 — Install

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### 4 — Enable Live Updates

On first launch, NeoAgent opens the system settings page for **Live Notifications**.
Toggle it on for NeoAgent. This is a one-time step.

> On a stock Android 16 emulator you can also find it under:
> Settings → Apps → NeoAgent → Notifications → Live Notifications

---

## Architecture

```
NeoAgentApp               — registers notification channels on startup
│
├── MainActivity        — launcher (minimal): requests permissions, starts service, finishes
│
├── NeoAgentService       — LifecycleService (foreground, START_STICKY, stopWithTask=false)
│   ├── NeoSocketManager    — Socket.IO connection + cookie-based auth + reconnect
│   └── LiveUpdateManager   — Android 16 Notification.ProgressStyle live updates
│
└── BootReceiver        — restarts service after reboot / app update
```

### Socket events consumed

| Event | Description |
|---|---|
| `run:start` | Task started → show indeterminate notification |
| `run:thinking` | AI generating → update status text |
| `run:stream` | Partial text streaming → throttled update |
| `run:tool_start` | Tool call → switch to determinate progress |
| `run:tool_end` | Tool done → back to indeterminate |
| `run:interim` | Intermediate message from a tool |
| `run:complete` | Task done → green bar, auto-dismiss |
| `run:error` | Task failed → red state, auto-dismiss |

---

## Build config fields

| Field | Default | Description |
|---|---|---|
| `BACKEND_URL` | `http://10.0.2.2:3000` | NeoAgent server URL |
| `AUTH_USERNAME` | `admin` | Login username |
| `AUTH_PASSWORD` | `changeme` | Login password |
| `ACCENT_COLOR` | `#7C4DFF` | Notification accent colour |

> `10.0.2.2` is the Android emulator alias for `localhost` on the host machine.

---

## Network security

`res/xml/network_security_config.xml` allows cleartext HTTP to common LAN ranges
(`192.168.x.x`, `10.0.x.x`, `localhost`) for development.  
Point `BACKEND_URL` at an HTTPS endpoint for production use and remove the
`<domain-config>` block.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| No notifications appear | Open the app → follow the settings prompt to enable Live Notifications |
| "Login failed: HTTP 401" in logcat | Check `AUTH_USERNAME` / `AUTH_PASSWORD` in `local.properties` |
| Service stops after a few minutes | Disable battery optimisation for NeoAgent in system settings |
| Chip text doesn't show | The chip only shows when `setShortCriticalText` is ≤7 visible chars |
