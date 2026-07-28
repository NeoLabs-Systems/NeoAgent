'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const {
  APP_DIR,
  ENV_FILE,
  LOG_DIR,
  PID_FILE,
  RUNTIME_HOME,
  ensureRuntimeDirs,
} = require('../../runtime/paths');
const { writeAtomicFile } = require('./atomic_file');

const SERVICE_LABEL = 'com.neoagent';
const WINDOWS_TASK_NAME = 'NeoAgent';

function escapeXml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function quoteSystemdValue(value) {
  return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function renderLaunchAgent(template, values) {
  return String(template)
    .replace(/__NODE_BIN__/g, escapeXml(values.nodeBin))
    .replace(/__APP_DIR__/g, escapeXml(values.appDir))
    .replace(/__HOME__/g, escapeXml(values.homeDir))
    .replace(/__RUNTIME_HOME__/g, escapeXml(values.runtimeHome))
    .replace(/__LOG_DIR__/g, escapeXml(values.logDir));
}

function renderSystemdUnit({
  appDir,
  envFile,
  logDir,
  nodeBin,
}) {
  const serverEntry = path.join(appDir, 'server', 'index.js');
  return [
    '[Unit]',
    'Description=NeoAgent — Proactive personal AI agent',
    'After=network.target',
    '',
    '[Service]',
    'Type=simple',
    `WorkingDirectory=${quoteSystemdValue(appDir)}`,
    `ExecStart=${quoteSystemdValue(nodeBin)} ${quoteSystemdValue(serverEntry)}`,
    'Restart=always',
    'RestartSec=10',
    `EnvironmentFile=-${quoteSystemdValue(envFile)}`,
    'Environment=NODE_ENV=production',
    `StandardOutput=${quoteSystemdValue(`append:${path.join(logDir, 'neoagent.log')}`)}`,
    `StandardError=${quoteSystemdValue(`append:${path.join(logDir, 'neoagent.error.log')}`)}`,
    '',
    '[Install]',
    'WantedBy=default.target',
    '',
  ].join('\n');
}

function createServiceAdapters({
  appDir = APP_DIR,
  envFile = ENV_FILE,
  logDir = LOG_DIR,
  pidFile = PID_FILE,
  runtimeHome = RUNTIME_HOME,
  plistSource = path.join(APP_DIR, 'com.neoagent.plist'),
  plistDestination = path.join(
    os.homedir(),
    'Library',
    'LaunchAgents',
    'com.neoagent.plist',
  ),
  systemdUnit = path.join(
    os.homedir(),
    '.config',
    'systemd',
    'user',
    'neoagent.service',
  ),
  commandExists,
  launchctlDomain,
  launchctlServiceTarget,
  logOk,
  logWarn,
  runOrThrow,
  runQuiet,
} = {}) {
  function startFallback() {
    ensureRuntimeDirs();
    const out = fs.openSync(path.join(logDir, 'neoagent.log'), 'a');
    const err = fs.openSync(path.join(logDir, 'neoagent.error.log'), 'a');
    const child = spawn(
      process.execPath,
      [path.join(appDir, 'server', 'index.js')],
      {
        cwd: appDir,
        detached: true,
        stdio: ['ignore', out, err],
      },
    );
    child.unref();
    writeAtomicFile(pidFile, String(child.pid));
    logOk(`Started detached process (pid ${child.pid})`);
  }

  function installMacService() {
    ensureRuntimeDirs();
    if (!fs.existsSync(plistSource)) {
      throw new Error(`Missing plist template at ${plistSource}`);
    }
    writeAtomicFile(
      plistDestination,
      renderLaunchAgent(fs.readFileSync(plistSource, 'utf8'), {
        nodeBin: process.execPath,
        appDir,
        homeDir: os.homedir(),
        runtimeHome,
        logDir,
      }),
    );

    const domain = launchctlDomain();
    if (domain) {
      runQuiet('launchctl', ['bootout', domain, plistDestination]);
      const bootstrap = runQuiet(
        'launchctl',
        ['bootstrap', domain, plistDestination],
      );
      if (bootstrap.status !== 0) {
        runQuiet('launchctl', ['unload', plistDestination]);
        runOrThrow('launchctl', ['load', plistDestination]);
      } else {
        runQuiet('launchctl', ['enable', launchctlServiceTarget()]);
        runQuiet('launchctl', ['kickstart', '-k', launchctlServiceTarget()]);
      }
    } else {
      runQuiet('launchctl', ['unload', plistDestination]);
      runOrThrow('launchctl', ['load', plistDestination]);
    }
    logOk(`launchd service loaded (${SERVICE_LABEL})`);
  }

  function installLinuxService() {
    ensureRuntimeDirs();
    writeAtomicFile(systemdUnit, renderSystemdUnit({
      appDir,
      envFile,
      logDir,
      nodeBin: process.execPath,
    }));
    runOrThrow('systemctl', ['--user', 'daemon-reload']);
    runOrThrow('systemctl', ['--user', 'enable', 'neoagent']);
    runOrThrow('systemctl', ['--user', 'start', 'neoagent']);
    runOrThrow('systemctl', ['--user', 'is-active', '--quiet', 'neoagent']);
    logOk('systemd user service installed and started');
  }

  function installWindowsService() {
    ensureRuntimeDirs();
    if (!commandExists('schtasks')) {
      logWarn(
        'Windows Task Scheduler is unavailable; using the background-process fallback.',
      );
      startFallback();
      return;
    }
    const taskCommand = `"${process.execPath}" "${path.join(appDir, 'server', 'index.js')}"`;
    const result = runQuiet('schtasks', [
      '/Create',
      '/TN',
      WINDOWS_TASK_NAME,
      '/TR',
      taskCommand,
      '/SC',
      'ONLOGON',
      '/RL',
      'LIMITED',
      '/F',
    ]);
    if (result.status !== 0) {
      logWarn(
        'Windows per-user autostart could not be registered; using the background-process fallback.',
      );
      startFallback();
      return;
    }
    startFallback();
    logOk('Windows per-user autostart registered');
  }

  function install(platform) {
    if (platform === 'macos' && commandExists('launchctl')) {
      installMacService();
      return;
    }
    if (platform === 'linux' && commandExists('systemctl')) {
      try {
        installLinuxService();
        return;
      } catch (error) {
        logWarn(
          `systemd setup failed (${error.message}); falling back to detached process`,
        );
      }
    } else if (platform === 'windows') {
      installWindowsService();
      return;
    }
    startFallback();
  }

  return Object.freeze({
    install,
    installLinuxService,
    installMacService,
    installWindowsService,
    startFallback,
  });
}

module.exports = {
  createServiceAdapters,
  renderLaunchAgent,
  renderSystemdUnit,
};
