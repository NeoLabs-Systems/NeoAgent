// Package wearable serves the NeoAgent wearables (ESP32 firmware in
// /firmware): the /api/wearable routes, the raw WebSocket gateway that carries
// live voice calls, the registry of connected devices, and the OTA firmware
// manifest read from GitHub releases. The firmware is unchanged and pins the
// protocol, so message names, fields and error shapes are the Node server's.
//
// The live voice runtime is consumed through the Voice interface, which
// voice.Manager satisfies.
package wearable
