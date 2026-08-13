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
  guestDesktopRepairCommand,
  guestLightDmConfig,
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
  assert.ok(!paths.includes('/etc/X11/xorg.conf.d/10-neoagent-display.conf'));
  assert.ok(paths.includes('/etc/lightdm/lightdm.conf.d/50-neoagent.conf'));
  assert.ok(paths.includes('/etc/systemd/system/neoagent-desktop-seat.service'));
  const lightdm = systemFiles.find((file) => file.path.endsWith('50-neoagent.conf')).content;
  assert.match(lightdm, /xserver-command=X -nolisten tcp vt1/);
  assert.doesNotMatch(lightdm, /-core/);
  assert.match(lightdm, /autologin-session=openbox/);
  assert.equal(lightdm, guestLightDmConfig());
  const tint2 = systemFiles.find((file) => file.path === '/etc/xdg/tint2/tint2rc').content;
  assert.match(tint2, /panel_position = bottom center horizontal/);
  assert.match(tint2, /neoagent-chromium\.desktop/);
  const setup = systemFiles.find((file) => file.path === '/usr/local/bin/neoagent-display-setup').content;
  const ensure = systemFiles.find((file) => file.path === '/usr/local/bin/neoagent-ensure-desktop').content;
  assert.match(setup, /1280x720/);
  assert.match(ensure, /rm -f \/etc\/X11\/xorg\.conf\.d\/10-neoagent-display\.conf/);
  assert.match(ensure, /xdpyinfo/);
  assert.match(ensure, /Driver "fbdev"/);
  assert.match(ensure, /getty@tty1/);
  assert.match(ensure, /chvt 1/);
  assert.doesNotMatch(ensure, /chvt 7/);
  assert.match(guestDesktopRepairCommand(), /xdpyinfo/);
  assert.match(guestDesktopRepairCommand(), /\/dev\/fb0/);
  assert.match(guestDesktopRepairCommand(), /getty@tty1/);
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
