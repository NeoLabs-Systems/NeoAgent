'use strict';

// Android and desktop tools are thin pass-throughs to their controller: resolve
// the controller, shape the arguments, call one method. Keeping them as tables
// means adding a tool is one entry rather than another copy of the same
// resolve-guard-call block in the main dispatch switch.

// Every Android tool forwards the model's arguments verbatim, so the table only
// needs the controller method each tool maps to.
const ANDROID_TOOL_METHODS = {
  android_start_emulator: 'startEmulator',
  android_stop_emulator: 'stopEmulator',
  android_list_devices: 'listDevices',
  android_open_app: 'openApp',
  android_open_intent: 'openIntent',
  android_tap: 'tap',
  android_long_press: 'longPress',
  android_type: 'type',
  android_swipe: 'swipe',
  android_press_key: 'pressKey',
  android_wait_for: 'waitFor',
  android_observe: 'observe',
  android_dump_ui: 'dumpUi',
  android_screenshot: 'screenshot',
  android_list_apps: 'listApps',
  android_install_apk: 'installApk',
  android_shell: 'shell',
};

// android_list_devices is the one tool whose result is wrapped rather than
// returned as-is.
const ANDROID_RESULT_WRAPPERS = {
  android_list_devices: (devices) => ({ devices }),
};

// These two describe the emulator rather than acting on it, and take no model
// arguments.
const ANDROID_ARGLESS_TOOLS = new Set([
  'android_stop_emulator',
  'android_list_devices',
]);

// Desktop tools each shape their own arguments, so the table holds a call.
const DESKTOP_TOOL_HANDLERS = {
  desktop_observe: (controller, args, signal) => controller.observe({
    includeTree: args.includeTree === true,
    signal,
  }),
  desktop_click: (controller, args, signal) => controller.clickPoint(args.x, args.y, {
    button: args.button,
    signal,
  }),
  desktop_drag: (controller, args, signal) => controller.drag({
    x1: args.x1,
    y1: args.y1,
    x2: args.x2,
    y2: args.y2,
    durationMs: args.durationMs,
    signal,
  }),
  desktop_scroll: (controller, args, signal) => controller.scroll({
    deltaX: args.deltaX,
    deltaY: args.deltaY,
    signal,
  }),
  desktop_type: (controller, args, signal) => controller.typeText(args.text, {
    pressEnter: args.pressEnter === true,
    signal,
  }),
  desktop_press_key: (controller, args, signal) => controller.pressKey(args.key, { signal }),
  desktop_launch_app: (controller, args, signal) => controller.launchApp({
    app: args.app,
    signal,
  }),
  desktop_get_tree: (controller, _args, signal) => controller.getAccessibilityTree({ signal }),
};

function isAndroidTool(toolName) {
  return Object.hasOwn(ANDROID_TOOL_METHODS, toolName);
}

function isDesktopTool(toolName) {
  return Object.hasOwn(DESKTOP_TOOL_HANDLERS, toolName);
}

async function executeAndroidTool(toolName, args, { getController, signal }) {
  const controller = await getController();
  if (!controller) return { error: 'Android controller not available' };
  const method = ANDROID_TOOL_METHODS[toolName];
  const callArgs = ANDROID_ARGLESS_TOOLS.has(toolName)
    ? { signal }
    : { ...(args || {}), signal };
  const result = await controller[method](callArgs);
  const wrap = ANDROID_RESULT_WRAPPERS[toolName];
  return wrap ? wrap(result) : result;
}

async function executeDesktopTool(toolName, args, { getController, signal }) {
  const controller = await getController();
  if (!controller) return { error: 'Desktop provider not available' };
  return DESKTOP_TOOL_HANDLERS[toolName](controller, args || {}, signal);
}

module.exports = {
  ANDROID_TOOL_METHODS,
  DESKTOP_TOOL_HANDLERS,
  executeAndroidTool,
  executeDesktopTool,
  isAndroidTool,
  isDesktopTool,
};
