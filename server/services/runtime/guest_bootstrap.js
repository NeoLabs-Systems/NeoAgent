const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');

const VM_ROOT = path.join(DATA_DIR, 'runtime-vms');
const GUEST_BOOTSTRAP_ROOT = path.join(VM_ROOT, 'guest-bootstrap');

fs.mkdirSync(GUEST_BOOTSTRAP_ROOT, { recursive: true });

function encodeGuestToken(value) {
  return Buffer.from(String(value || ''), 'utf8').toString('base64');
}

function createCloudInitScript({
  guestToken,
  hostShareMount,
  hostDataMount = '/mnt/neoagent-data',
  guestAgentPort = 8421,
}) {
  const guestTokenB64 = encodeGuestToken(guestToken);
  const envFile = '/etc/neoagent/neoagent.env';
  const appDir = '/opt/neoagent';
  const bootstrapMarker = '/var/lib/neoagent/bootstrap-complete';
  const nodeSourceSetupUrl = 'https://deb.nodesource.com/setup_20.x';

  return [
    '#!/usr/bin/env bash',
    'set -uo pipefail', // Removed -e to handle non-critical failures gracefully
    '',
    'export DEBIAN_FRONTEND=noninteractive',
    `HOST_SHARE_MOUNT=${JSON.stringify(hostShareMount)}`,
    `HOST_DATA_MOUNT=${JSON.stringify(hostDataMount)}`,
    'HOST_SHARE_TAG=neoagent-host',
    'HOST_SHARE_TAG_FALLBACK=neoagent-host-pci',
    'HOST_DATA_TAG=neoagent-data',
    'HOST_DATA_TAG_FALLBACK=neoagent-data-pci',
    `APP_DIR=${JSON.stringify(appDir)}`,
    `BOOTSTRAP_MARKER=${JSON.stringify(bootstrapMarker)}`,
    `ENV_FILE=${JSON.stringify(envFile)}`,
    '',
    'mkdir -p /etc/neoagent /var/lib/neoagent "$HOST_SHARE_MOUNT" "$HOST_DATA_MOUNT" "$APP_DIR"',
    '',
    '# Ensure the 9p virtio filesystem driver is loaded',
    'modprobe 9p 2>/dev/null || true',
    'modprobe 9pnet_virtio 2>/dev/null || true',
    '',
    'function mount_9p_tag() {',
    '  local tag="$1"',
    '  local target="$2"',
    '  local mode="$3"',
    '  mount -t 9p -o "trans=virtio,version=9p2000.L,msize=262144,${mode}" "$tag" "$target" >/dev/null 2>&1',
    '}',
    '',
    'if ! mount_9p_tag "$HOST_SHARE_TAG" "$HOST_SHARE_MOUNT" ro; then',
    '  if mount_9p_tag "$HOST_SHARE_TAG_FALLBACK" "$HOST_SHARE_MOUNT" ro; then',
    '    HOST_SHARE_TAG="$HOST_SHARE_TAG_FALLBACK"',
    '  fi',
    'fi',
    'if ! mount_9p_tag "$HOST_DATA_TAG" "$HOST_DATA_MOUNT" rw; then',
    '  if mount_9p_tag "$HOST_DATA_TAG_FALLBACK" "$HOST_DATA_MOUNT" rw; then',
    '    HOST_DATA_TAG="$HOST_DATA_TAG_FALLBACK"',
    '  fi',
    'fi',
    '',
    'if ! grep -qs "${HOST_SHARE_MOUNT}" /etc/fstab; then',
    '  echo "${HOST_SHARE_TAG} ${HOST_SHARE_MOUNT} 9p trans=virtio,version=9p2000.L,msize=262144,ro 0 0" >> /etc/fstab',
    'fi',
    'if ! grep -qs "${HOST_DATA_MOUNT}" /etc/fstab; then',
    '  echo "${HOST_DATA_TAG} ${HOST_DATA_MOUNT} 9p trans=virtio,version=9p2000.L,msize=262144,rw 0 0" >> /etc/fstab',
    'fi',
    '',
    'mount -a >/dev/null 2>&1 || true',
    '',
    '# Redirect logs to both host-writable share and console',
    'LOG_FILE="${HOST_DATA_MOUNT}/bootstrap.log"',
    'exec > >(tee -a "$LOG_FILE" >/dev/console) 2>&1',
    'echo "NeoAgent guest bootstrap starting..."',
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
    'echo "Updating package lists..."',
    'retry_cmd apt-get update || echo "Warning: apt-get update failed, proceeding with cached lists."',
    '',
    'echo "Installing dependencies..."',
    'retry_cmd apt-get install -y --no-install-recommends \\',
    '  curl ca-certificates gnupg openjdk-17-jre-headless git rsync build-essential \\',
    '  python3 unzip libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 libcups2 \\',
    '  libx11-xcb1 libgtk-3-0 libnss3 libnspr4 libxcomposite1 libxdamage1 \\',
    '  libxrandr2 libxkbcommon0 libasound2t64 libgbm1 libdrm2 libdbus-1-3 \\',
    '  libpango-1.0-0 libpangocairo-1.0-0 libxshmfence1 || echo "Warning: Some dependencies failed to install."',
    '',
    'if [ -d "$HOST_SHARE_MOUNT" ]; then',
    '  echo "Syncing guest agent sources..."',
    '  SYNC_PATHS=(',
    '    server/guest-agent.package.json:package.json',
    '    runtime/env.js',
    '    runtime/paths.js',
    '    server/guest_agent.js',
    '    server/services/cli',
    '    server/services/browser',
    '    server/services/android',
    '  )',
    '  for relPath in "${SYNC_PATHS[@]}"; do',
    '    sourceRelPath="${relPath%%:*}"',
    '    targetRelPath="${relPath##*:}"',
    '    sourcePath="$HOST_SHARE_MOUNT/$sourceRelPath"',
    '    targetPath="$APP_DIR/$targetRelPath"',
    '    if [ -e "$sourcePath" ]; then',
    '      mkdir -p "$(dirname "$targetPath")"',
    '      if [ -d "$sourcePath" ]; then',
    '        mkdir -p "$targetPath"',
    '        rsync -a --delete "$sourcePath"/ "$targetPath"/',
    '      else',
    '        rsync -a "$sourcePath" "$targetPath"',
    '      fi',
    '    else',
    '      echo "Warning: Optional source path missing: $relPath"',
    '    fi',
    '  done',
    'else',
    '  echo "Error: Host repo share is not available. Bootstrap cannot continue." >&2',
    '  exit 1',
    'fi',
    '',
    'if ! command -v node >/dev/null 2>&1 || ! node -e "process.exit(Number(process.versions.node.split(\'.\')[0]) >= 20 ? 0 : 1)"; then',
    '  echo "Installing Node.js..."',
    '  curl -fsSL ' + JSON.stringify(nodeSourceSetupUrl) + ' | bash - || true',
    '  retry_cmd apt-get install -y --no-install-recommends nodejs || { echo "Error: Failed to install Node.js" >&2; exit 1; }',
    'fi',
    '',
    `printf '%s\n' ${JSON.stringify(`NEOAGENT_VM_GUEST_TOKEN_B64=${guestTokenB64}`)} > "$ENV_FILE"`,
    `printf '%s\n' ${JSON.stringify(`NEOAGENT_GUEST_AGENT_PORT=${guestAgentPort}`)} >> "$ENV_FILE"`,
    'chmod 0600 "$ENV_FILE"',
    '',
    'cd "$APP_DIR"',
    'if [ ! -d node_modules ] || [ ! -f node_modules/.neoagent-bootstrap-stamp ] || [ package.json -nt node_modules/.neoagent-bootstrap-stamp ]; then',
    '  echo "Installing npm dependencies..."',
    '  export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1',
    '  retry_cmd npm install --omit=dev --no-audit --no-fund || echo "Warning: npm install failed."',
    '  mkdir -p node_modules',
    '  date > node_modules/.neoagent-bootstrap-stamp',
    'fi',
    '',
    '# Install Playwright browser binaries',
    'PLAYWRIGHT_BROWSERS_PATH="$APP_DIR/.playwright-browsers"',
    'PLAYWRIGHT_STAMP="$PLAYWRIGHT_BROWSERS_PATH/.chromium-installed"',
    'if [ ! -f "$PLAYWRIGHT_STAMP" ]; then',
    '  echo "Installing Playwright browsers..."',
    '  mkdir -p "$PLAYWRIGHT_BROWSERS_PATH"',
    '  PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" npx playwright install chromium --with-deps || \\',
    '    PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH" node ./node_modules/playwright-chromium/install.js || true',
    '  date > "$PLAYWRIGHT_STAMP"',
    'fi',
    '',
    'systemctl daemon-reload',
    'systemctl enable neoagent-guest-agent.service || true',
    'systemctl restart neoagent-guest-agent.service || true',
    'touch "$BOOTSTRAP_MARKER"',
    'echo "NeoAgent guest bootstrap completed."',
    '',
  ].join('\n');
}

function createCloudInitUserData({
  guestToken,
  hostShareMount = '/mnt/neoagent-host',
  hostDataMount = '/mnt/neoagent-data',
  guestAgentPort = 8421,
}) {
  const guestTokenB64 = encodeGuestToken(guestToken);
  const bootstrapScript = createCloudInitScript({
    guestToken,
    hostShareMount,
    hostDataMount,
    guestAgentPort,
  });

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
    '      Wants=network-online.target',
    '',
    '      [Service]',
    '      Type=simple',
    '      EnvironmentFile=/etc/neoagent/neoagent.env',
    '      Environment=PLAYWRIGHT_BROWSERS_PATH=/opt/neoagent/.playwright-browsers',
    '      WorkingDirectory=/opt/neoagent',
    '      ExecStart=/usr/bin/env node /opt/neoagent/server/guest_agent.js',
    '      Restart=always',
    '      RestartSec=5',
    '',
    '      [Install]',
    '      WantedBy=multi-user.target',
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
    '  - [bash, -lc, "systemctl enable neoagent-guest-bootstrap.service"]',
    '  - [bash, -lc, "systemctl start neoagent-guest-bootstrap.service"]',
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
  hostShareMount = '/mnt/neoagent-host',
  guestAgentPort = 8421,
  guestArch = 'x64',
}) {
  const seedRoot = path.join(userRoot, 'cloud-init');
  const seedDir = path.join(seedRoot, 'seed');
  const seedImagePath = path.join(seedRoot, 'cidata.img');
  const isoPath = path.join(seedRoot, 'cidata.iso');
  fs.mkdirSync(seedDir, { recursive: true });

  const userDataPath = path.join(seedDir, 'user-data');
  const metaDataPath = path.join(seedDir, 'meta-data');
  const startupNshPath = path.join(seedDir, 'startup.nsh');
  const userData = createCloudInitUserData({ guestToken, hostShareMount, guestAgentPort });
  const metaData = createCloudInitMetaData({
    instanceId: `neoagent-${path.basename(userRoot)}`,
    localHostName: `neoagent-${path.basename(userRoot)}`,
  });
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
    hostShareMount,
  };
}

module.exports = {
  createCloudInitMetaData,
  createCloudInitUserData,
  createSeedIso,
  ensureGuestBootstrapSeed,
  GUEST_BOOTSTRAP_ROOT,
};
