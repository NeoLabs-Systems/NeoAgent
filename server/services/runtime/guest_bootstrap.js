const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');

const VM_ROOT = path.join(DATA_DIR, 'runtime-vms');
const GUEST_BOOTSTRAP_ROOT = path.join(VM_ROOT, 'guest-bootstrap');
const REPO_ROOT = path.resolve(__dirname, '../../..');
const GUEST_PAYLOAD_PROFILES = Object.freeze({
  browser_cli: [
    { source: 'server/guest-agent.browser.package.json', target: 'package.json' },
    { source: 'runtime/env.js', target: 'runtime/env.js' },
    { source: 'runtime/paths.js', target: 'runtime/paths.js' },
    { source: 'server/guest_agent.js', target: 'server/guest_agent.js' },
    { source: 'server/services/cli', target: 'server/services/cli' },
    { source: 'server/services/browser', target: 'server/services/browser' },
  ],
  android: [
    { source: 'server/guest-agent.android.package.json', target: 'package.json' },
    { source: 'runtime/env.js', target: 'runtime/env.js' },
    { source: 'runtime/paths.js', target: 'runtime/paths.js' },
    { source: 'server/guest_agent.js', target: 'server/guest_agent.js' },
    { source: 'server/services/cli', target: 'server/services/cli' },
    { source: 'server/services/android', target: 'server/services/android' },
  ],
});

fs.mkdirSync(GUEST_BOOTSTRAP_ROOT, { recursive: true });

function encodeGuestToken(value) {
  return Buffer.from(String(value || ''), 'utf8').toString('base64');
}

function normalizeRuntimeProfile(runtimeProfile) {
  return runtimeProfile === 'android' ? 'android' : 'browser_cli';
}

function createGuestPayloadArchive(seedDir, runtimeProfile = 'browser_cli') {
  const seedRoot = path.dirname(seedDir);
  const stagingRoot = path.join(seedRoot, 'guest-payload');
  const archivePath = path.join(seedRoot, 'guest-payload.tar.gz');
  const payloadEntries = GUEST_PAYLOAD_PROFILES[normalizeRuntimeProfile(runtimeProfile)];
  fs.rmSync(stagingRoot, { recursive: true, force: true });
  fs.rmSync(archivePath, { force: true });
  fs.mkdirSync(stagingRoot, { recursive: true });

  for (const entry of payloadEntries) {
    const sourcePath = path.join(REPO_ROOT, entry.source);
    const targetPath = path.join(stagingRoot, entry.target);
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    if (fs.statSync(sourcePath).isDirectory()) {
      fs.cpSync(sourcePath, targetPath, { recursive: true, force: true });
    } else {
      fs.copyFileSync(sourcePath, targetPath);
    }
  }

  const tarResult = spawnSync('tar', ['-czf', archivePath, '-C', stagingRoot, '.'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (tarResult.status !== 0 || !fs.existsSync(archivePath)) {
    throw new Error(
      String(tarResult.stderr || tarResult.stdout || tarResult.error?.message || 'Failed to create guest payload archive.')
        .trim(),
    );
  }
  fs.rmSync(stagingRoot, { recursive: true, force: true });
  return archivePath;
}

function createCloudInitScript({
  guestToken,
  guestPayloadPath = '/var/lib/neoagent/guest-payload.tar.gz',
  guestAgentPort = 8421,
  runtimeProfile = 'browser_cli',
}) {
  const normalizedProfile = normalizeRuntimeProfile(runtimeProfile);
  const includeBrowser = normalizedProfile === 'browser_cli';
  const guestUtilityPackages = includeBrowser
    ? 'curl ca-certificates gnupg git rsync unzip xvfb dbus-x11'
    : 'curl ca-certificates gnupg git rsync unzip dbus-x11 adb';
  const guestTokenB64 = encodeGuestToken(guestToken);
  const envFile = '/etc/neoagent/neoagent.env';
  const appDir = '/opt/neoagent';
  const playwrightBrowsersPath = `${appDir}/.playwright-browsers`;
  const bootstrapMarker = '/var/lib/neoagent/bootstrap-complete';
  const browserReadyMarker = '/var/lib/neoagent/browser-runtime-ready';
  const browserDepsMarker = '/var/lib/neoagent/browser-deps-installed';
  const nodeSourceSetupUrl = 'https://deb.nodesource.com/setup_20.x';

  return [
    '#!/usr/bin/env bash',
    'set -uo pipefail', // Removed -e to handle non-critical failures gracefully
    '',
    'export DEBIAN_FRONTEND=noninteractive',
    `APP_DIR=${JSON.stringify(appDir)}`,
    `PLAYWRIGHT_BROWSERS_PATH=${JSON.stringify(playwrightBrowsersPath)}`,
    `BOOTSTRAP_MARKER=${JSON.stringify(bootstrapMarker)}`,
    `BROWSER_READY_MARKER=${JSON.stringify(browserReadyMarker)}`,
    `BROWSER_DEPS_MARKER=${JSON.stringify(browserDepsMarker)}`,
    `ENV_FILE=${JSON.stringify(envFile)}`,
    `GUEST_PAYLOAD_PATH=${JSON.stringify(guestPayloadPath)}`,
    '',
    'mkdir -p /etc/neoagent /var/lib/neoagent "$APP_DIR"',
    '',
    '# Redirect logs to a guest-local file and console',
    'LOG_FILE="/var/log/neoagent-bootstrap.log"',
    'exec > >(tee -a "$LOG_FILE" >/dev/console) 2>&1',
    'echo "NeoAgent guest bootstrap starting..."',
    'rm -f "$BOOTSTRAP_MARKER" "$BROWSER_READY_MARKER"',
    '',
    'function retry_cmd() {',
    '  local n=1',
    '  local max=3',
    '  local delay=5',
    '  while true; do',
    '    "$@" && break || {',
    '      if [[ $n -lt $max ]]; then',
    '        ((n++))',
    '        echo "Command failed. Attempt $n/$max in ${delay}s..."',
    '        sleep $delay',
    '      else',
    '        echo "The command has failed after $n attempts." >&2',
    '        return 1',
    '      fi',
    '    }',
    '  done',
    '}',
    '',
    'if [ ! -f "$GUEST_PAYLOAD_PATH" ]; then',
    '  echo "Error: Guest payload archive is missing at $GUEST_PAYLOAD_PATH." >&2',
    '  exit 1',
    'fi',
    'echo "Extracting guest runtime payload..."',
    'rm -rf "$APP_DIR"',
    'mkdir -p "$APP_DIR"',
    'tar -xzf "$GUEST_PAYLOAD_PATH" -C "$APP_DIR" || { echo "Error: Failed to extract guest runtime payload." >&2; exit 1; }',
    '',
    'if ! command -v node >/dev/null 2>&1 || ! node -e "process.exit(Number(process.versions.node.split(\'.\')[0]) >= 20 ? 0 : 1)"; then',
    '  echo "Installing Node.js..."',
    '  curl -fsSL ' + JSON.stringify(nodeSourceSetupUrl) + ' | bash - || true',
    '  retry_cmd apt-get install -y --no-install-recommends nodejs || { echo "Error: Failed to install Node.js" >&2; exit 1; }',
    'fi',
    '',
    `printf '%s\n' ${JSON.stringify(`NEOAGENT_VM_GUEST_TOKEN_B64=${guestTokenB64}`)} > "$ENV_FILE"`,
    `printf '%s\n' ${JSON.stringify(`NEOAGENT_GUEST_AGENT_PORT=${guestAgentPort}`)} >> "$ENV_FILE"`,
    `printf '%s\n' ${JSON.stringify(`NEOAGENT_GUEST_PROFILE=${normalizedProfile}`)} >> "$ENV_FILE"`,
    'chmod 0600 "$ENV_FILE"',
    '',
    'cd "$APP_DIR"',
    'export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1',
    'export PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH"',
    'if [ ! -d node_modules ] || [ ! -f node_modules/.neoagent-bootstrap-stamp ] || [ package.json -nt node_modules/.neoagent-bootstrap-stamp ]; then',
    '  echo "Installing npm dependencies..."',
    '  retry_cmd npm install --omit=dev --ignore-scripts --prefer-offline --no-audit --no-fund || { echo "Error: npm install failed." >&2; exit 1; }',
    '  mkdir -p node_modules',
    '  date > node_modules/.neoagent-bootstrap-stamp',
    'fi',
    '',
    '',
    'echo "Ensuring guest runtime utilities..."',
    'retry_cmd apt-get update || echo "Warning: apt-get update failed, proceeding with cached lists."',
    `retry_cmd apt-get install -y --no-install-recommends ${guestUtilityPackages} || { echo "Error: Failed to install required guest runtime utilities." >&2; exit 1; }`,
    '',
    'echo "NeoAgent guest runtime payload is ready."',
    '',
    ...(includeBrowser
      ? [
        'echo "Continuing browser runtime provisioning..."',
        'PLAYWRIGHT_BROWSERS_PATH="$APP_DIR/.playwright-browsers"',
        'PLAYWRIGHT_STAMP="$PLAYWRIGHT_BROWSERS_PATH/.chromium-installed"',
        'mkdir -p "$PLAYWRIGHT_BROWSERS_PATH"',
        'if [ ! -f "$BROWSER_DEPS_MARKER" ]; then',
        '  echo "Installing Playwright browser dependencies..."',
        '  PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" retry_cmd npx playwright install-deps chromium || { echo "Error: Playwright dependency install failed." >&2; exit 1; }',
        '  touch "$BROWSER_DEPS_MARKER"',
        'fi',
        'if [ ! -f "$PLAYWRIGHT_STAMP" ] || [ package.json -nt "$PLAYWRIGHT_STAMP" ]; then',
        '  echo "Installing Playwright browsers..."',
        '  PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" retry_cmd npx playwright install chromium || { echo "Error: Playwright browser install failed." >&2; exit 1; }',
        '  date > "$PLAYWRIGHT_STAMP"',
        'fi',
        'touch "$BROWSER_READY_MARKER"',
      ]
      : [
        'rm -f "$BROWSER_READY_MARKER"',
      ]),
    'touch "$BOOTSTRAP_MARKER"',
    'echo "NeoAgent guest bootstrap completed."',
    '',
  ].join('\n');
}

function createCloudInitUserData({
  guestToken,
  guestPayloadBase64 = '',
  guestAgentPort = 8421,
  runtimeMode = 'template',
  runtimeProfile = 'browser_cli',
}) {
  const normalizedProfile = normalizeRuntimeProfile(runtimeProfile);
  const includeBrowser = normalizedProfile === 'browser_cli';
  const guestAgentInnerCommand = includeBrowser
    ? 'set -a; . /etc/neoagent/neoagent.env; set +a; cd /opt/neoagent && env DISPLAY=:99 PLAYWRIGHT_BROWSERS_PATH=/opt/neoagent/.playwright-browsers /usr/bin/env node server/guest_agent.js 2>&1 | tee -a /var/log/neoagent-guest-agent.log >/dev/console'
    : 'set -a; . /etc/neoagent/neoagent.env; set +a; cd /opt/neoagent && /usr/bin/env node server/guest_agent.js 2>&1 | tee -a /var/log/neoagent-guest-agent.log >/dev/console';
  const guestAgentLaunchCommand = `nohup /bin/sh -lc ${JSON.stringify(guestAgentInnerCommand)} </dev/null >/dev/null 2>&1 &`;
  const guestTokenB64 = encodeGuestToken(guestToken);
  const bootstrapScript = createCloudInitScript({
    guestToken,
    guestPayloadPath: '/var/lib/neoagent/guest-payload.tar.gz',
    guestAgentPort,
    runtimeProfile: normalizedProfile,
  });

  if (runtimeMode === 'user') {
    return [
      '#cloud-config',
      'package_update: false',
      'write_files:',
      '  - path: /etc/neoagent/neoagent.env',
      "    permissions: '0600'",
      '    owner: root:root',
      '    content: |',
      `      NEOAGENT_VM_GUEST_TOKEN_B64=${guestTokenB64}`,
      `      NEOAGENT_GUEST_AGENT_PORT=${guestAgentPort}`,
      `      NEOAGENT_GUEST_PROFILE=${normalizedProfile}`,
      ...(includeBrowser
        ? [
          '  - path: /etc/systemd/system/neoagent-xvfb.service',
          "    permissions: '0644'",
          '    owner: root:root',
          '    content: |',
          '      [Unit]',
          '      Description=NeoAgent virtual display',
          '      After=network-online.target',
          '      Wants=network-online.target',
          '',
          '      [Service]',
          '      Type=simple',
          '      ExecStart=/usr/bin/Xvfb :99 -screen 0 1440x900x24 -ac -nolisten tcp',
          '      Restart=always',
          '      RestartSec=2',
          '      StandardOutput=journal+console',
          '      StandardError=journal+console',
          '',
          '      [Install]',
          '      WantedBy=multi-user.target',
        ]
        : []),
      '  - path: /etc/systemd/system/neoagent-guest-agent.service',
      "    permissions: '0644'",
      '    owner: root:root',
      '    content: |',
      '      [Unit]',
      '      Description=NeoAgent guest agent',
      '      After=network-online.target',
      ...(includeBrowser ? ['      After=neoagent-xvfb.service'] : []),
      '      ConditionPathExists=/etc/neoagent/neoagent.env',
      '      Wants=network-online.target',
      '',
      '      [Service]',
      '      Type=simple',
      '      EnvironmentFile=/etc/neoagent/neoagent.env',
      '      ExecStartPre=/bin/mkdir -p /var/lib/neoagent',
      ...(includeBrowser
        ? [
          '      ExecStartPre=/usr/bin/touch /var/lib/neoagent/browser-runtime-ready',
          '      ExecStartPre=/bin/sh -lc \'for _ in $(seq 1 30); do [ -S /tmp/.X11-unix/X99 ] && exit 0; sleep 1; done; exit 1\'',
          '      Environment=DISPLAY=:99',
          '      Environment=PLAYWRIGHT_BROWSERS_PATH=/opt/neoagent/.playwright-browsers',
        ]
        : [
          '      ExecStartPre=/bin/sh -lc \'rm -f /var/lib/neoagent/browser-runtime-ready || true\'',
        ]),
      '      ExecStartPre=/usr/bin/touch /var/lib/neoagent/bootstrap-complete',
      '      WorkingDirectory=/opt/neoagent',
      '      ExecStart=/usr/bin/env node /opt/neoagent/server/guest_agent.js',
      '      Restart=always',
      '      RestartSec=5',
      '      StandardOutput=journal+console',
      '      StandardError=journal+console',
      '',
      '      [Install]',
      '      WantedBy=multi-user.target',
      'runcmd:',
      '  - [bash, -lc, "systemctl daemon-reload"]',
      ...(includeBrowser
        ? [
          '  - [bash, -lc, "systemctl enable neoagent-xvfb.service"]',
          '  - [bash, -lc, "systemctl start neoagent-xvfb.service"]',
        ]
        : []),
      '  - [bash, -lc, "systemctl enable neoagent-guest-agent.service"]',
      '  - [bash, -lc, "systemctl start --no-block neoagent-guest-agent.service"]',
      '',
    ].join('\n');
  }

  return [
    '#cloud-config',
    'package_update: false',
    'write_files:',
    '  - path: /etc/neoagent/neoagent.env',
    "    permissions: '0600'",
    '    owner: root:root',
      '    content: |',
      `      NEOAGENT_VM_GUEST_TOKEN_B64=${guestTokenB64}`,
      `      NEOAGENT_GUEST_AGENT_PORT=${guestAgentPort}`,
      `      NEOAGENT_GUEST_PROFILE=${normalizedProfile}`,
    '  - path: /var/lib/neoagent/guest-payload.tar.gz',
    "    permissions: '0644'",
    '    owner: root:root',
    "    encoding: 'b64'",
    '    content: |',
      `      ${guestPayloadBase64}`,
    '  - path: /usr/local/bin/neoagent-guest-bootstrap.sh',
    "    permissions: '0755'",
    '    owner: root:root',
    '    content: |',
    ...bootstrapScript.split('\n').map((line) => `      ${line}`),
    '  - path: /etc/systemd/system/neoagent-guest-agent.service',
    "    permissions: '0644'",
    '    owner: root:root',
    '    content: |',
    '      [Unit]',
    '      Description=NeoAgent guest agent',
    '      After=network-online.target',
    '      After=cloud-final.service',
    '      After=neoagent-guest-bootstrap.service',
    ...(includeBrowser ? ['      After=neoagent-xvfb.service'] : []),
    '      ConditionPathExists=/etc/neoagent/neoagent.env',
    ...(includeBrowser ? ['      Requires=neoagent-xvfb.service'] : []),
    '      Wants=network-online.target',
    '',
    '      [Service]',
    '      Type=simple',
    '      EnvironmentFile=/etc/neoagent/neoagent.env',
    ...(includeBrowser
      ? [
        '      Environment=DISPLAY=:99',
        '      Environment=PLAYWRIGHT_BROWSERS_PATH=/opt/neoagent/.playwright-browsers',
      ]
      : []),
    '      WorkingDirectory=/opt/neoagent',
    '      ExecStart=/usr/bin/env node /opt/neoagent/server/guest_agent.js',
    '      Restart=always',
    '      RestartSec=5',
    '      StandardOutput=journal+console',
    '      StandardError=journal+console',
    '',
    '      [Install]',
    '      WantedBy=multi-user.target',
    ...(includeBrowser
      ? [
        '  - path: /etc/systemd/system/neoagent-xvfb.service',
        "    permissions: '0644'",
        '    owner: root:root',
        '    content: |',
        '      [Unit]',
        '      Description=NeoAgent virtual display',
        '      After=network-online.target',
        '      Wants=network-online.target',
        '',
        '      [Service]',
        '      Type=simple',
        '      ExecStart=/usr/bin/Xvfb :99 -screen 0 1440x900x24 -ac -nolisten tcp',
        '      Restart=always',
        '      RestartSec=2',
        '      StandardOutput=journal+console',
        '      StandardError=journal+console',
        '',
        '      [Install]',
        '      WantedBy=multi-user.target',
      ]
      : []),
    '  - path: /etc/systemd/system/neoagent-guest-bootstrap.service',
    "    permissions: '0644'",
    '    owner: root:root',
    '    content: |',
    '      [Unit]',
    '      Description=NeoAgent guest bootstrap',
    '      After=network-online.target',
    '      Wants=network-online.target',
    '',
    '      [Service]',
    '      Type=oneshot',
    '      ExecStart=/usr/local/bin/neoagent-guest-bootstrap.sh',
    '      RemainAfterExit=yes',
    '',
    '      [Install]',
    '      WantedBy=multi-user.target',
    'runcmd:',
    '  - [bash, -lc, "systemctl daemon-reload"]',
    ...(includeBrowser
      ? [
        '  - [bash, -lc, "systemctl enable neoagent-xvfb.service"]',
        '  - [bash, -lc, "systemctl start neoagent-xvfb.service"]',
      ]
      : []),
    '  - [bash, -lc, "/usr/local/bin/neoagent-guest-bootstrap.sh"]',
    `  - [bash, -lc, ${JSON.stringify(guestAgentLaunchCommand)}]`,
    '',
  ].join('\n');
}

function createCloudInitMetaData({ instanceId, localHostName }) {
  return [
    `instance-id: ${instanceId}`,
    `local-hostname: ${localHostName}`,
    '',
  ].join('\n');
}

function resolveCloudInitIdentity(userRoot) {
  const relativePath = path.relative(VM_ROOT, path.resolve(userRoot || ''));
  const normalized = relativePath
    .split(path.sep)
    .filter(Boolean)
    .map((segment) => segment.replace(/[^a-z0-9_-]+/gi, '-').replace(/^-+|-+$/g, '').slice(0, 32))
    .filter(Boolean)
    .join('-');
  const scope = normalized || 'default';
  return {
    instanceId: `neoagent-${scope}`,
    localHostName: `neoagent-${scope}`,
  };
}

function commandExists(command) {
  const probe = spawnSync(
    process.platform === 'win32' ? 'where' : 'bash',
    process.platform === 'win32' ? [command] : ['-lc', `command -v "${command}"`],
    { stdio: 'ignore' },
  );
  return probe.status === 0;
}

function parseDiskutilMountPoint(output) {
  const match = String(output || '').match(/Mount Point:\s+(.+)/);
  return match ? match[1].trim() : null;
}

function copySeedFilesToVolume(volumePath, sourceDir) {
  for (const entry of ['user-data', 'meta-data', 'startup.nsh']) {
    const sourcePath = path.join(sourceDir, entry);
    const targetPath = path.join(volumePath, entry);
    fs.copyFileSync(sourcePath, targetPath);
  }
}

function createFatSeedImage(sourceDir, imagePath) {
  if (process.platform === 'win32') {
    throw new Error('Creating a FAT seed image is not supported on Windows yet.');
  }

  const hdiutilAvailable = commandExists('hdiutil');
  const newfsMsdosPath = commandExists('/sbin/newfs_msdos') ? '/sbin/newfs_msdos' : (commandExists('newfs_msdos') ? 'newfs_msdos' : null);
  const diskutilAvailable = commandExists('diskutil');
  if (!hdiutilAvailable || !newfsMsdosPath || !diskutilAvailable) {
    throw new Error('Required disk image tools are not available.');
  }

  fs.mkdirSync(path.dirname(imagePath), { recursive: true });
  fs.rmSync(imagePath, { force: true });
  fs.writeFileSync(imagePath, Buffer.alloc(32 * 1024 * 1024));

  let device = null;
  try {
    const attachResult = spawnSync('hdiutil', ['attach', '-nomount', imagePath], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    if (attachResult.status !== 0) {
      throw new Error(
        String(attachResult.stderr || attachResult.stdout || attachResult.error?.message || 'Failed to attach FAT seed image.')
          .trim(),
      );
    }

    device = String(attachResult.stdout || '').trim().split('\n').find(Boolean)?.split(/\s+/)[0] || null;
    if (!device) {
      throw new Error('Failed to resolve the temporary FAT seed device.');
    }
    const rawDevice = device.replace('/dev/disk', '/dev/rdisk');

    const formatResult = spawnSync(newfsMsdosPath, ['-v', 'CIDATA', rawDevice], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    if (formatResult.status !== 0) {
      throw new Error(
        String(formatResult.stderr || formatResult.stdout || formatResult.error?.message || 'Failed to format FAT seed image.')
          .trim(),
      );
    }

    const mountResult = spawnSync('diskutil', ['mount', device], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    if (mountResult.status !== 0) {
      throw new Error(
        String(mountResult.stderr || mountResult.stdout || mountResult.error?.message || 'Failed to mount FAT seed image.')
          .trim(),
      );
    }

    const mountPoint = parseDiskutilMountPoint(mountResult.stdout)
      || parseDiskutilMountPoint(spawnSync('diskutil', ['info', device], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
      }).stdout)
      || `/Volumes/CIDATA`;

    if (!fs.existsSync(mountPoint)) {
      throw new Error(`Mounted FAT seed volume is missing at ${mountPoint}.`);
    }

    copySeedFilesToVolume(mountPoint, sourceDir);
    return imagePath;
  } finally {
    if (device) {
      try {
        spawnSync('diskutil', ['unmount', 'force', device], { stdio: 'ignore' });
      } catch {}
      try {
        spawnSync('hdiutil', ['detach', device], { stdio: 'ignore' });
      } catch {}
    }
  }
}

function createSeedIso(sourceDir, isoPath) {
  const candidates = [
    {
      command: 'xorriso',
      args: ['-as', 'mkisofs', '-output', isoPath, '-volid', 'CIDATA', '-joliet', '-rock', sourceDir],
    },
    {
      command: 'cloud-localds',
      args: [isoPath, path.join(sourceDir, 'user-data'), path.join(sourceDir, 'meta-data')],
    },
    {
      command: 'hdiutil',
      args: ['makehybrid', '-ov', '-o', isoPath, '-iso', '-joliet', '-iso-volume-name', 'CIDATA', '-joliet-volume-name', 'CIDATA', sourceDir],
    },
    {
      command: 'mkisofs',
      args: ['-o', isoPath, '-V', 'CIDATA', '-J', '-r', sourceDir],
    },
  ];

  let lastError = null;
  for (const candidate of candidates) {
    if (!commandExists(candidate.command)) {
      continue;
    }

    const result = spawnSync(candidate.command, candidate.args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    if (result.status === 0 && fs.existsSync(isoPath)) {
      return isoPath;
    }
    lastError = new Error(
      String(result.stderr || result.stdout || result.error?.message || `exit status ${result.status ?? 'unknown'}`).trim() || `Failed to create seed ISO with ${candidate.command}.`
    );
  }

  throw new Error(`Unable to create cloud-init seed ISO: ${lastError ? lastError.message : 'no supported ISO writer was found.'}`);
}

function ensureGuestBootstrapSeed({
  userRoot,
  guestToken,
  guestAgentPort = 8421,
  guestArch = 'x64',
  runtimeMode = 'template',
  runtimeProfile = 'browser_cli',
}) {
  const seedRoot = path.join(userRoot, 'cloud-init');
  const seedDir = path.join(seedRoot, 'seed');
  const seedImagePath = path.join(seedRoot, 'cidata.img');
  const isoPath = path.join(seedRoot, 'cidata.iso');
  fs.mkdirSync(seedDir, { recursive: true });

  const userDataPath = path.join(seedDir, 'user-data');
  const metaDataPath = path.join(seedDir, 'meta-data');
  const startupNshPath = path.join(seedDir, 'startup.nsh');
  const guestPayloadBase64 = runtimeMode === 'user'
    ? ''
    : fs.readFileSync(createGuestPayloadArchive(seedDir, runtimeProfile)).toString('base64');
  const userData = createCloudInitUserData({
    guestToken,
    guestPayloadBase64,
    guestAgentPort,
    runtimeMode,
    runtimeProfile,
  });
  const identity = resolveCloudInitIdentity(userRoot);
  const metaData = createCloudInitMetaData(identity);
  const startupNsh = guestArch === 'arm64'
    ? [
      '@echo -off',
      'map -r',
      'for %d in fs0 fs1 fs2 fs3 fs4 fs5',
      '  if exist %d:\\EFI\\ubuntu\\shimaa64.efi then',
      '    %d:\\EFI\\ubuntu\\shimaa64.efi',
      '  endif',
      'endfor',
      '# Fallback',
      '\\EFI\\ubuntu\\shimaa64.efi',
      '\\EFI\\ubuntu\\grubaa64.efi',
    ].join('\r\n')
    : [
      '@echo -off',
      'map -r',
      'fs0:',
      '\\EFI\\ubuntu\\shimx64.efi',
      '\\EFI\\ubuntu\\grubx64.efi',
      '\\EFI\\BOOT\\BOOTX64.EFI',
    ].join('\r\n');

  fs.writeFileSync(userDataPath, userData);
  fs.writeFileSync(metaDataPath, metaData);
  fs.writeFileSync(startupNshPath, startupNsh);
  let createdSeedPath = null;
  try {
    createdSeedPath = createFatSeedImage(seedDir, seedImagePath);
  } catch (error) {
    createdSeedPath = createSeedIso(seedDir, isoPath);
  }

  return {
    seedRoot,
    seedDir,
    seedImagePath: createdSeedPath,
    isoPath: createdSeedPath === isoPath ? isoPath : null,
    userDataPath,
    metaDataPath,
    startupNshPath,
  };
}

module.exports = {
  createCloudInitMetaData,
  createCloudInitUserData,
  createCloudInitScript,
  createSeedIso,
  ensureGuestBootstrapSeed,
  GUEST_BOOTSTRAP_ROOT,
};
