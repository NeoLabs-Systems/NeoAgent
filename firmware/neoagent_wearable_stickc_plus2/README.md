# NeoAgent on M5StickC PLUS2

This ESP-IDF target uses Wi-Fi and the existing wearable pairing and live voice
protocol. It targets the **StickC PLUS2** (ESP32-PICO-V3-02, 8 MB flash and
2 MB PSRAM), not the earlier StickC or StickC PLUS.

## Build and flash

Install ESP-IDF 5.4 with the `esp32` target, load its environment, and run:

```sh
cd firmware/neoagent_wearable_stickc_plus2
idf.py build
idf.py flash monitor
```

If multiple serial devices are connected, select the StickC's port with the
`-p` option. The first build downloads the ESP WebSocket client, cJSON and LVGL
through the ESP-IDF component manager. The existing ESP32-S3 wearable target
remains a separate build.

## Setup

On first boot, join the `NeoAgent Setup` Wi-Fi network shown on the StickC and
open `http://192.168.4.1` on the phone. Select a 2.4 GHz network and enter the
NeoAgent server URL. The device restarts and displays a pairing code; scan it
with NeoAgent and approve the login. It remembers the Wi-Fi and session.

Hold the front **A** button while speaking and release to send. The answer
appears on screen; the built-in buzzer sounds when a reply is complete. The
PLUS2 has no built-in vibration motor. Press side **B** to scroll up or **C**
to scroll down through a long answer. Hold **B** for three seconds to erase the saved network and session and
return to setup. If the saved Wi-Fi is unavailable at boot, the device opens the
setup hotspot so the network can be changed.

The backlight turns off after 30 seconds of inactivity, the microphone is
stopped between turns, Wi-Fi power saving is enabled while idle, and an idle
call closes after one minute. After two idle minutes the device enters deep
sleep; press A to wake it and wait for it to reconnect before speaking. During
display standby before deep sleep, A wakes and starts a turn, while B and C wake and
scroll. Running tasks keep the device awake. The device displays replies
rather than playing speech audio.

The display font supports Latin characters including German umlauts and ß,
as well as common punctuation. Other writing systems and emoji are not yet
covered by the built-in font.
