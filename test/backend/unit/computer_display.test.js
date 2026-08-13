'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  COMPUTER_DISPLAY_HEIGHT,
  COMPUTER_DISPLAY_WIDTH,
  buildComputerDisplayPage,
  computerDisplayMode,
} = require('../../../server/services/runtime/computer_display');
const {
  getGuestDesktopHomeFiles,
  getGuestDesktopSkelFiles,
  getGuestDesktopSystemFiles,
  renderDesktopFileCommands,
} = require('../../../server/services/runtime/guest_desktop');
const { createCloudInitUserData } = require('../../../server/services/runtime/guest_bootstrap');

test('computer display is a 16:9 720p desktop', () => {
  assert.equal(COMPUTER_DISPLAY_WIDTH, 1280);
  assert.equal(COMPUTER_DISPLAY_HEIGHT, 720);
  assert.equal(computerDisplayMode(), '1280x720');
  assert.equal(COMPUTER_DISPLAY_WIDTH / COMPUTER_DISPLAY_HEIGHT, 16 / 9);
});

test('noVNC page scales the 16:9 desktop without resizing the guest', () => {
  const page = buildComputerDisplayPage({
    websocketPath: '/api/computer/display-ws?token=abc',
    viewOnly: false,
  });
  assert.match(page, /scaleViewport = true/);
  assert.match(page, /resizeSession = false/);
  assert.match(page, /showDotCursor = true/);
  assert.match(page, /viewOnly = false/);
  assert.match(page, /\/api\/computer\/display-ws\?token=abc/);
  assert.match(buildComputerDisplayPage({
    websocketPath: '/api/computer/display-ws?token=abc',
    viewOnly: true,
  }), /viewOnly = true/);
});

test('guest desktop ships a Chromebook-style shelf without nested heredocs', () => {
  const systemFiles = getGuestDesktopSystemFiles();
  const paths = systemFiles.map((file) => file.path);
  assert.ok(paths.includes('/etc/xdg/tint2/tint2rc'));
  assert.ok(paths.includes('/etc/xdg/openbox/rc.xml'));
  assert.ok(paths.includes('/usr/local/bin/neoagent-display-setup'));
  const tint2 = systemFiles.find((file) => file.path === '/etc/xdg/tint2/tint2rc').content;
  assert.match(tint2, /panel_position = bottom center horizontal/);
  assert.match(tint2, /neoagent-chromium\.desktop/);
  const setup = systemFiles.find((file) => file.path === '/usr/local/bin/neoagent-display-setup').content;
  assert.match(setup, /1280x720/);
  const commands = renderDesktopFileCommands([
    ...systemFiles,
    ...getGuestDesktopSkelFiles(),
  ]).join('\n');
  assert.doesNotMatch(commands, /<<'EOF'\n[\s\S]*<<'EOF'/);
  assert.ok(getGuestDesktopHomeFiles().some((file) => file.path.endsWith('/Desktop/Chromium.desktop')));
});

test('desktop file commands cannot terminate their own heredoc early', () => {
  const commands = renderDesktopFileCommands([{
    path: '/tmp/nested-script',
    content: '#!/bin/sh\nNEOAGENT_FILE_0\nprintf ready\n',
    mode: '0755',
  }]);

  assert.match(commands[1], /NEOAGENT_FILE_0_/);
  assert.equal(commands.filter((line) => line === 'NEOAGENT_FILE_0_').length, 1);
});

test('user computers receive the desktop polish after the home disk is mounted', () => {
  const userData = createCloudInitUserData({
    guestToken: 'test-token',
    runtimeMode: 'user',
    runtimeProfile: 'browser_cli',
  });
  assert.match(userData, /path: \/etc\/xdg\/tint2\/tint2rc/);
  assert.match(userData, /path: \/usr\/share\/neoagent\/desktop-skel\/Desktop\/Chromium\.desktop/);
  assert.match(userData, /\/usr\/local\/bin\/neoagent-apply-desktop-home/);
});
