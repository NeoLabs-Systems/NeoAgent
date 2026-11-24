'use strict';

// Android control tools: schemas plus the metadata the harness reads.

function buildAndroidUiMatchProperties(extra = {}) {
  return {
    x: { type: 'number', description: 'Absolute X coordinate' },
    y: { type: 'number', description: 'Absolute Y coordinate' },
    text: { type: 'string', description: 'Visible text to match in the UI dump' },
    resourceId: { type: 'string', description: 'Android resource-id to match' },
    description: { type: 'string', description: 'content-desc / accessibility label to match' },
    className: { type: 'string', description: 'Optional class name filter' },
    packageName: { type: 'string', description: 'Optional package filter' },
    clickable: { type: 'boolean', description: 'Prefer clickable elements' },
    ...extra,
  };
}

module.exports = [
  {
    name: 'android_start_emulator',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'slow', repeatable: true,
    capabilities: ['android', 'emulator'],
    prerequisites: ['android'],
    description: 'Bootstrap Android tools if needed and start the managed Android emulator.',
    parameters: {
      type: 'object',
      properties: {
        headless: { type: 'boolean', description: 'Run the emulator headless (default true)' },
        timeoutMs: { type: 'number', description: 'Boot timeout in milliseconds (default 240000)' }
      }
    }
  },
  {
    name: 'android_stop_emulator',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'emulator'],
    prerequisites: ['android'],
    description: 'Stop the managed Android emulator.',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'android_list_devices',
    group: 'android', access: 'read', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'devices'],
    prerequisites: ['android'],
    description: 'List ADB-connected Android devices and emulators.',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'android_open_app',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'apps'],
    prerequisites: ['android'],
    policy: { category: 'android_privileged' },
    description: 'Open an installed Android app by package name, optionally with a specific activity.',
    parameters: {
      type: 'object',
      properties: {
        packageName: { type: 'string', description: 'Android package name, e.g. com.google.android.apps.maps' },
        activity: { type: 'string', description: 'Optional activity name to launch' }
      },
      required: ['packageName']
    }
  },
  {
    name: 'android_open_intent',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'intent'],
    prerequisites: ['android'],
    policy: { category: 'android_privileged' },
    description: 'Open an Android intent for deep links, navigation, messaging, or app-specific actions.',
    parameters: {
      type: 'object',
      properties: {
        action: { type: 'string', description: 'Intent action, e.g. android.intent.action.VIEW' },
        dataUri: { type: 'string', description: 'Intent data URI, e.g. geo:0,0?q=coffee or smsto:+1234567890' },
        packageName: { type: 'string', description: 'Optional package name to target' },
        component: { type: 'string', description: 'Optional fully qualified component name' },
        mimeType: { type: 'string', description: 'Optional MIME type' },
        extras: { type: 'object', description: 'Optional string extras added via --es' }
      }
    }
  },
  {
    name: 'android_tap',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'tap'],
    prerequisites: ['android'],
    description: 'Tap the Android screen at coordinates or by matching a UI element from the current UI dump.',
    parameters: {
      type: 'object',
      properties: buildAndroidUiMatchProperties()
    }
  },
  {
    name: 'android_long_press',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'tap'],
    prerequisites: ['android'],
    description: 'Long-press an Android UI element or screen coordinate. Useful for context menus, drag handles, rearranging icons, and long-click actions.',
    parameters: {
      type: 'object',
      properties: buildAndroidUiMatchProperties({
        durationMs: { type: 'number', description: 'Press duration in milliseconds (default 650)' }
      })
    }
  },
  {
    name: 'android_type',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'input'],
    prerequisites: ['android'],
    description: 'Type text into the focused Android field, optionally tapping a matched element first.',
    parameters: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'Text to type' },
        textSelector: { type: 'string', description: 'Visible text of the field to focus first' },
        resourceId: { type: 'string', description: 'resource-id of the field to focus first' },
        description: { type: 'string', description: 'content-desc of the field to focus first' },
        className: { type: 'string', description: 'Optional class filter when focusing an element' },
        clear: { type: 'boolean', description: 'Attempt to clear before typing' },
        pressEnter: { type: 'boolean', description: 'Press Enter after typing' }
      },
      required: ['text']
    }
  },
  {
    name: 'android_swipe',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'swipe'],
    prerequisites: ['android'],
    description: 'Swipe across the Android screen using absolute coordinates.',
    parameters: {
      type: 'object',
      properties: {
        x1: { type: 'number', description: 'Start X coordinate' },
        y1: { type: 'number', description: 'Start Y coordinate' },
        x2: { type: 'number', description: 'End X coordinate' },
        y2: { type: 'number', description: 'End Y coordinate' },
        durationMs: { type: 'number', description: 'Swipe duration in milliseconds (default 300)' }
      },
      required: ['x1', 'y1', 'x2', 'y2']
    }
  },
  {
    name: 'android_press_key',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'keyboard'],
    prerequisites: ['android'],
    description: 'Send an Android key event such as home, back, enter, menu, app_switch, or a numeric key code.',
    parameters: {
      type: 'object',
      properties: {
        key: { type: 'string', description: 'Named key or numeric Android key code' }
      },
      required: ['key']
    }
  },
  {
    name: 'android_wait_for',
    group: 'android', access: 'read', stateScope: 'android', latencyClass: 'slow', repeatable: true,
    capabilities: ['android', 'wait'],
    prerequisites: ['android'],
    description: 'Poll Android UI dumps until a matching element appears.',
    parameters: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'Visible text to wait for' },
        resourceId: { type: 'string', description: 'resource-id to wait for' },
        description: { type: 'string', description: 'content-desc to wait for' },
        className: { type: 'string', description: 'Optional class filter' },
        packageName: { type: 'string', description: 'Optional package filter' },
        clickable: { type: 'boolean', description: 'Require the matched element to be clickable' },
        timeoutMs: { type: 'number', description: 'Timeout in milliseconds (default 20000)' },
        intervalMs: { type: 'number', description: 'Polling interval in milliseconds (default 1500)' },
        screenshot: { type: 'boolean', description: 'Capture a screenshot after a match (default true)' }
      }
    }
  },
  {
    name: 'android_observe',
    resultShape: 'device_ui',
    group: 'android', access: 'read', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'screen'],
    prerequisites: ['android'],
    description: 'Capture the current Android screen end-to-end: fresh screenshot, UI dump path, and a preview of visible UI nodes.',
    parameters: {
      type: 'object',
      properties: {
        includeNodes: { type: 'boolean', description: 'Include a preview of parsed UI nodes (default true)' }
      }
    }
  },
  {
    name: 'android_dump_ui',
    resultShape: 'device_ui',
    group: 'android', access: 'read', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'ui'],
    prerequisites: ['android'],
    description: 'Capture the current Android UIAutomator XML dump and return a preview of the nodes.',
    parameters: {
      type: 'object',
      properties: {
        includeNodes: { type: 'boolean', description: 'Include a preview of the parsed nodes (default true)' }
      }
    }
  },
  {
    name: 'android_screenshot',
    group: 'android', access: 'read', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'screenshot'],
    prerequisites: ['android'],
    description: 'Capture a screenshot from the active Android device or emulator.',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'android_list_apps',
    resultShape: 'device_apps',
    group: 'android', access: 'read', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'apps'],
    prerequisites: ['android'],
    description: 'List installed Android app package names.',
    parameters: {
      type: 'object',
      properties: {
        includeSystem: { type: 'boolean', description: 'Include system apps (default false)' }
      }
    }
  },
  {
    name: 'android_install_apk',
    group: 'android', access: 'write', sideEffect: 'device', stateScope: 'android', latencyClass: 'slow', repeatable: true,
    capabilities: ['android', 'install'],
    prerequisites: ['android'],
    policy: { category: 'android_privileged' },
    description: 'Install or replace an APK or universal .apks bundle on the Android emulator.',
    parameters: {
      type: 'object',
      properties: {
        apkPath: { type: 'string', description: 'Absolute path to an .apk file or universal .apks bundle on disk' }
      },
      required: ['apkPath']
    }
  },
  {
    name: 'android_shell',
    resultShape: 'device_shell',
    group: 'android', access: 'dynamic_shell', sideEffect: 'device', stateScope: 'android', latencyClass: 'local', repeatable: true,
    capabilities: ['android', 'shell'],
    prerequisites: ['android'],
    policy: { category: 'android_privileged' },
    description: 'Run an adb shell command on the active Android device or emulator. Use this when a needed phone action is not covered by a higher-level Android tool.',
    parameters: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'Shell command to run on-device, without the leading "adb shell"' },
        timeoutMs: { type: 'number', description: 'Timeout in milliseconds (default 20000)' },
        screenshot: { type: 'boolean', description: 'Capture a screenshot after the command if it changes the UI (default false)' }
      },
      required: ['command']
    }
  },
];
