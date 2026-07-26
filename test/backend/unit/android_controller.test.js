'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let AndroidController;
let findBestNode;
let parseUiDump;

before(() => {
  ctx = createTestRuntime();
  ({ AndroidController } = require('../../../server/services/android/controller'));
  ({ findBestNode, parseUiDump } = require('../../../server/services/android/uia'));
});

after(() => teardownTestRuntime(ctx));

function sampleNodes() {
  return [
    {
      text: 'Continue',
      resourceId: 'com.example:id/continue',
      description: 'Continue setup',
      className: 'android.widget.Button',
      packageName: 'com.example',
      clickable: true,
      enabled: true,
      bounds: {
        left: 10,
        top: 20,
        right: 210,
        bottom: 100,
        width: 200,
        height: 80,
        centerX: 110,
        centerY: 60,
      },
    },
  ];
}

test('UI dump parser includes nested container nodes and enforces clickable selectors', () => {
  const xml = [
    '<hierarchy>',
    '<node text="Container" resource-id="container" clickable="false" enabled="true" bounds="[0,0][300,300]">',
    '<node text="Continue" resource-id="continue" clickable="true" enabled="true" bounds="[10,20][210,100]"/>',
    '</node>',
    '</hierarchy>',
  ].join('');
  const nodes = parseUiDump(xml);

  assert.equal(nodes.length, 2);
  assert.equal(findBestNode(nodes, { text: 'Container' }).resourceId, 'container');
  assert.equal(findBestNode(nodes, { text: 'Container', clickable: true }), null);
  assert.equal(findBestNode(nodes, { text: 'Continue', clickable: true }).bounds.centerX, 110);
});

test('selector-based tap resolves the UI node center and returns fresh evidence', async () => {
  const controller = new AndroidController({ userId: '7', sdkDir: ctx.dir });
  const commands = [];
  controller.dumpUi = async () => ({ nodes: sampleNodes() });
  controller.shell = async (value) => {
    commands.push(typeof value === 'string' ? value : value.command);
    return '';
  };
  controller.screenshot = async () => ({ screenshotPath: '/artifacts/after.png' });

  const result = await controller.tap({ resourceId: 'com.example:id/continue', clickable: true });

  assert.deepEqual(commands, ['input tap 110 60']);
  assert.equal(result.target.text, 'Continue');
  assert.equal(result.screenshotPath, '/artifacts/after.png');
});

test('tap rejects partial or missing coordinates instead of touching 0,0', async () => {
  const controller = new AndroidController({ userId: '7', sdkDir: ctx.dir });

  await assert.rejects(controller.tap({ x: 10 }), /Both x and y/);
  await assert.rejects(controller.tap({}), /coordinates or a UI selector/);
});

test('type focuses a selector, clears the field, and types escaped text', async () => {
  const controller = new AndroidController({ userId: '7', sdkDir: ctx.dir });
  const commands = [];
  controller.dumpUi = async () => ({ nodes: sampleNodes() });
  controller.shell = async (value) => {
    commands.push(typeof value === 'string' ? value : value.command);
    return '';
  };

  const result = await controller.type({
    text: 'hello world',
    resourceId: 'com.example:id/continue',
    clear: true,
    pressEnter: true,
  });

  assert.equal(commands[0], 'input tap 110 60');
  assert.match(commands[1], /KEYCODE_DEL/);
  assert.equal(commands[2], "input text 'hello%sworld'");
  assert.equal(commands[3], 'input keyevent KEYCODE_ENTER');
  assert.equal(result.target.resourceId, 'com.example:id/continue');
});

test('waitFor returns the matched node rather than emulator-only readiness', async () => {
  const controller = new AndroidController({ userId: '7', sdkDir: ctx.dir });
  controller.dumpUi = async () => ({ nodes: sampleNodes() });
  controller.screenshot = async () => ({ screenshotPath: '/artifacts/match.png' });

  const result = await controller.waitFor({ text: 'Continue', timeoutMs: 1000 });

  assert.equal(result.found, true);
  assert.equal(result.node.text, 'Continue');
  assert.equal(result.screenshotPath, '/artifacts/match.png');
});

test('startEmulator exists for agent tools and waits for boot completion', async () => {
  const controller = new AndroidController({ userId: '7', sdkDir: ctx.dir });
  const calls = [];
  controller.requestStartEmulator = async (options) => {
    calls.push({ phase: 'request', options });
    return { success: true, pending: true, bootstrapped: false };
  };
  controller.waitForDevice = async (options) => {
    calls.push({ phase: 'wait', options });
    return 'emulator-5554';
  };

  const result = await controller.startEmulator({ headless: false, timeoutMs: 12_345 });

  assert.deepEqual(result, {
    success: true,
    pending: false,
    bootstrapped: true,
    adbSerial: 'emulator-5554',
  });
  assert.equal(calls[0].options.headless, false);
  assert.equal(calls[1].options.timeoutMs, 12_345);
});

test('pressKey rejects shell metacharacters', async () => {
  const controller = new AndroidController({ userId: '7', sdkDir: ctx.dir });
  controller.shell = async () => { throw new Error('shell should not run'); };

  await assert.rejects(controller.pressKey('HOME; reboot'), /Unsupported Android key/);
});

test('Android screenshots reject corrupt ADB output before artifact creation', async () => {
  const controller = new AndroidController({
    userId: '7',
    sdkDir: ctx.dir,
    artifactStore: {
      async createBufferArtifact() {
        throw new Error('artifact creation should not run');
      },
    },
  });
  controller.capturePng = async () => Buffer.from('adb error text');

  await assert.rejects(controller.screenshot(), /not a valid PNG or JPEG/i);
});

test('Android screenshots are written through the bounded artifact path', async () => {
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );
  let artifactOptions = null;
  const controller = new AndroidController({
    userId: '7',
    sdkDir: ctx.dir,
    artifactStore: {
      async createBufferArtifact(_userId, options) {
        artifactOptions = options;
        return { url: '/api/artifacts/android-shot/content' };
      },
    },
  });
  controller.capturePng = async () => png;

  assert.deepEqual(
    await controller.screenshot(),
    { screenshotPath: '/api/artifacts/android-shot/content' },
  );
  assert.equal(artifactOptions.contentType, 'image/png');
  assert.deepEqual(artifactOptions.content, png);
});
