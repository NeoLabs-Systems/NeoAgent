'use strict';

const { executeAndroidTool } = require('../../integrated_tools/device_tools');

async function handleAndroidTool(args, ctx) {
  const { ac, signal, toolName } = ctx;
  return await executeAndroidTool(toolName, args, { getController: ac, signal });
}

const handlers = {
  android_start_emulator: handleAndroidTool,

  android_stop_emulator: handleAndroidTool,

  android_list_devices: handleAndroidTool,

  android_open_app: handleAndroidTool,

  android_open_intent: handleAndroidTool,

  android_tap: handleAndroidTool,

  android_long_press: handleAndroidTool,

  android_type: handleAndroidTool,

  android_swipe: handleAndroidTool,

  android_press_key: handleAndroidTool,

  android_wait_for: handleAndroidTool,

  android_observe: handleAndroidTool,

  android_dump_ui: handleAndroidTool,

  android_screenshot: handleAndroidTool,

  android_list_apps: handleAndroidTool,

  android_install_apk: handleAndroidTool,

  android_shell: handleAndroidTool,
};

module.exports = { handlers };
