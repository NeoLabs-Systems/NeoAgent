package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// Android and desktop tools pass through to their controller
// (integrated_tools/device_tools.js).

var androidMethods = map[string]string{
	"android_start_emulator": "startEmulator",
	"android_stop_emulator":  "stopEmulator",
	"android_list_devices":   "listDevices",
	"android_open_app":       "openApp",
	"android_open_intent":    "openIntent",
	"android_tap":            "tap",
	"android_long_press":     "longPress",
	"android_type":           "type",
	"android_swipe":          "swipe",
	"android_press_key":      "pressKey",
	"android_wait_for":       "waitFor",
	"android_observe":        "observe",
	"android_dump_ui":        "dumpUi",
	"android_screenshot":     "screenshot",
	"android_list_apps":      "listApps",
	"android_install_apk":    "installApk",
	"android_shell":          "shell",
}

// These describe the emulator rather than acting on it and take no arguments.
var androidArgless = map[string]bool{"android_stop_emulator": true, "android_list_devices": true}

// desktopCalls shape each desktop tool's arguments for its controller method.
var desktopCalls = map[string]func(args dyn.Map) (string, dyn.Map){
	"desktop_observe": func(a dyn.Map) (string, dyn.Map) {
		return "observe", dyn.Map{"includeTree": a["includeTree"] == true}
	},
	"desktop_click": func(a dyn.Map) (string, dyn.Map) {
		return "clickPoint", dyn.Map{"x": a["x"], "y": a["y"], "button": a["button"]}
	},
	"desktop_drag": func(a dyn.Map) (string, dyn.Map) {
		return "drag", dyn.Map{"x1": a["x1"], "y1": a["y1"], "x2": a["x2"], "y2": a["y2"], "durationMs": a["durationMs"]}
	},
	"desktop_scroll": func(a dyn.Map) (string, dyn.Map) {
		return "scroll", dyn.Map{"deltaX": a["deltaX"], "deltaY": a["deltaY"]}
	},
	"desktop_type": func(a dyn.Map) (string, dyn.Map) {
		return "typeText", dyn.Map{"text": a["text"], "pressEnter": a["pressEnter"] == true}
	},
	"desktop_press_key": func(a dyn.Map) (string, dyn.Map) {
		return "pressKey", dyn.Map{"key": a["key"]}
	},
	"desktop_launch_app": func(a dyn.Map) (string, dyn.Map) {
		return "launchApp", dyn.Map{"app": a["app"]}
	},
	"desktop_get_tree": func(dyn.Map) (string, dyn.Map) {
		return "getAccessibilityTree", dyn.Map{}
	},
}

func deviceHandlers() map[string]handler {
	out := map[string]handler{}
	for name := range androidMethods {
		out[name] = androidTool
	}
	for name := range desktopCalls {
		out[name] = desktopTool
	}
	return out
}

func androidTool(ctx context.Context, c *call) (any, error) {
	rt := c.b.d.Runtime
	if rt == nil {
		return nil, errorf("Android provider is unavailable. VM runtime is required.")
	}
	controller, err := rt.Android(ctx, c.run.UserID)
	if err != nil {
		return nil, err
	}
	if controller == nil {
		return errResult("Android controller not available"), nil
	}
	args := dyn.Map{}
	if !androidArgless[c.name] {
		for k, v := range c.args {
			args[k] = v
		}
	}
	result, err := controller.Call(ctx, androidMethods[c.name], args)
	if err != nil {
		return nil, err
	}
	if c.name == "android_list_devices" {
		return dyn.Map{"devices": result}, nil
	}
	return result, nil
}

func desktopTool(ctx context.Context, c *call) (any, error) {
	var controller Device
	if rt := c.b.d.Runtime; rt != nil {
		var err error
		if controller, err = rt.Desktop(ctx, c.run.UserID, c.run.DeviceTarget); err != nil {
			return nil, err
		}
	}
	if controller == nil {
		return errResult("Desktop provider not available"), nil
	}
	method, args := desktopCalls[c.name](c.args)
	return controller.Call(ctx, method, args)
}
