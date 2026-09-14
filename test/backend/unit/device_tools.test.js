'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const {
  ANDROID_TOOL_METHODS,
  DESKTOP_TOOL_HANDLERS,
  executeAndroidTool,
  executeDesktopTool,
} = require('../../../server/services/ai/integrated_tools/device_tools');

// A plain object, not a Proxy: a Proxy would also answer to `then`, and the
// awaited result would be mistaken for a pending thenable.
const CONTROLLER_METHODS = [
  ...Object.values(ANDROID_TOOL_METHODS),
  'observe', 'clickPoint', 'drag', 'scroll', 'typeText', 'pressKey',
  'launchApp', 'getAccessibilityTree',
];

function recordingController(returnValue = { ok: true }) {
  const calls = [];
  const controller = {};
  for (const method of CONTROLLER_METHODS) {
    controller[method] = (...callArgs) => {
      calls.push({ method, callArgs });
      return returnValue;
    };
  }
  return { calls, controller };
}

const SIGNAL = new AbortController().signal;

describe('android tool dispatch', () => {
  test('each tool calls its own controller method and forwards the signal', async () => {
    for (const [toolName, method] of Object.entries(ANDROID_TOOL_METHODS)) {
      const { calls, controller } = recordingController();
      await executeAndroidTool(toolName, { some: 'arg' }, {
        getController: () => controller,
        signal: SIGNAL,
      });
      assert.equal(calls.length, 1, `${toolName} should make one controller call`);
      assert.equal(calls[0].method, method, `${toolName} maps to ${method}`);
      assert.equal(calls[0].callArgs[0].signal, SIGNAL, `${toolName} forwards the signal`);
    }
  });

  test('acting tools forward the model arguments', async () => {
    const { calls, controller } = recordingController();
    await executeAndroidTool('android_tap', { x: 10, y: 20 }, {
      getController: () => controller,
      signal: SIGNAL,
    });
    assert.equal(calls[0].callArgs[0].x, 10);
    assert.equal(calls[0].callArgs[0].y, 20);
  });

  test('describing tools take no model arguments', async () => {
    for (const toolName of ['android_stop_emulator', 'android_list_devices']) {
      const { calls, controller } = recordingController([]);
      await executeAndroidTool(toolName, { stray: 'value' }, {
        getController: () => controller,
        signal: SIGNAL,
      });
      assert.deepEqual(Object.keys(calls[0].callArgs[0]), ['signal'], toolName);
    }
  });

  test('listing devices wraps the controller result', async () => {
    const { controller } = recordingController(['emulator-5554']);
    const result = await executeAndroidTool('android_list_devices', {}, {
      getController: () => controller,
      signal: SIGNAL,
    });
    assert.deepEqual(result, { devices: ['emulator-5554'] });
  });

  test('a missing controller is reported rather than thrown', async () => {
    const result = await executeAndroidTool('android_tap', {}, {
      getController: () => null,
      signal: SIGNAL,
    });
    assert.deepEqual(result, { error: 'Android controller not available' });
  });
});

describe('desktop tool dispatch', () => {
  test('every desktop tool reaches its controller with the signal', async () => {
    for (const toolName of Object.keys(DESKTOP_TOOL_HANDLERS)) {
      const { calls, controller } = recordingController();
      await executeDesktopTool(toolName, { x: 1, y: 2, text: 'hi', key: 'Enter', app: 'files' }, {
        getController: () => controller,
        signal: SIGNAL,
      });
      assert.equal(calls.length, 1, `${toolName} should make one controller call`);
      const passedSignal = calls[0].callArgs.some(
        (arg) => arg && typeof arg === 'object' && arg.signal === SIGNAL,
      );
      assert.ok(passedSignal, `${toolName} forwards the signal`);
    }
  });

  test('clicking passes coordinates positionally and the button as an option', async () => {
    const { calls, controller } = recordingController();
    await executeDesktopTool('desktop_click', { x: 12, y: 34, button: 'right' }, {
      getController: () => controller,
      signal: SIGNAL,
    });
    assert.equal(calls[0].method, 'clickPoint');
    assert.deepEqual(calls[0].callArgs.slice(0, 2), [12, 34]);
    assert.equal(calls[0].callArgs[2].button, 'right');
  });

  test('observing only requests the tree when asked', async () => {
    for (const [input, expected] of [[true, true], [false, false], [undefined, false]]) {
      const { calls, controller } = recordingController();
      await executeDesktopTool('desktop_observe', { includeTree: input }, {
        getController: () => controller,
        signal: SIGNAL,
      });
      assert.equal(calls[0].callArgs[0].includeTree, expected);
    }
  });

  test('a missing provider is reported rather than thrown', async () => {
    const result = await executeDesktopTool('desktop_observe', {}, {
      getController: () => null,
      signal: SIGNAL,
    });
    assert.deepEqual(result, { error: 'Desktop provider not available' });
  });
});
