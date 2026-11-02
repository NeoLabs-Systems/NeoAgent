'use strict';

const QRCode = require('qrcode');

const USAGE = 'Usage: neoagent messaging [list | setup <telegram|whatsapp> [--no-personal] [--token-stdin] | disconnect <platform> | remove <platform> [--yes]]';
const WAIT_FOR_TOKEN_MS = 45 * 1000;
const WAIT_FOR_SCAN_MS = 3 * 60 * 1000;
const POLL_MS = 1000;

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data.trim()));
    process.stdin.on('error', reject);
  });
}

function describe(connection) {
  const parts = [connection.status.replaceAll('_', ' ')];
  if (connection.accountLabel) parts.push(connection.accountLabel);
  parts.push(`${connection.linkedUsers} linked`);
  if (connection.configured && !connection.available) parts.push('hidden from users');
  if (connection.configured && !connection.allowPersonal) parts.push('personal accounts off');
  return parts.join(' · ');
}

// The token is prompted for or piped in, never taken as an argument, so it stays
// out of shell history and process listings.
async function readToken(options, { prompt, ui }) {
  if (options.tokenStdin) return readStdin();
  if (!ui.isInteractive()) {
    throw new Error('Pipe the bot token in with --token-stdin when there is no terminal.');
  }
  return prompt.askSecret('Telegram bot token from @BotFather');
}

// The server applies the change on its own, so this only watches the row it
// writes its progress to. The QR lives there, encrypted, for the same reason.
async function waitForConnection(platform, { store, ui, logOk, logWarn, json, timeoutMs }) {
  const deadline = Date.now() + timeoutMs;
  let shownQr = null;
  while (Date.now() < deadline) {
    const row = store.getConnection(platform);
    if (row?.status === 'connected') {
      if (!json) logOk(`Connected as ${row.account_label || platform}.`);
      return true;
    }
    if (row?.status === 'error' || row?.status === 'logged_out') {
      if (!json) logWarn(`The account could not connect (${row.status_reason || row.status}).`);
      return false;
    }
    const qr = store.readConnectionQr(row);
    if (qr && qr !== shownQr && !json) {
      shownQr = qr;
      ui.print(await QRCode.toString(qr, { type: 'terminal', small: true }));
      ui.print('Scan this in WhatsApp › Linked devices with the shared number.');
    }
    await new Promise((resolve) => setTimeout(resolve, POLL_MS));
  }
  if (!json) {
    logWarn('Saved, but not connected yet. It connects once NeoAgent is running: `neoagent status`.');
  }
  return false;
}

async function setup(platform, options, context) {
  const { store, prompt, ui, logInfo, json } = context;
  store.assertSharedPlatform(platform);
  const input = { enabled: true, reconnect: true };
  if (platform === 'telegram') {
    const existing = store.getConnection(platform);
    if (options.tokenStdin || !existing || ui.isInteractive()) {
      input.botToken = await readToken(options, context);
    }
  }
  if (options.noPersonal) {
    input.allowPersonal = false;
  } else if (ui.isInteractive()) {
    input.allowPersonal = await prompt.confirm('Let people connect their own account instead?', { initial: true });
  }
  store.configureConnection(platform, input, { source: 'cli' });

  const connected = await waitForConnection(platform, {
    ...context,
    timeoutMs: platform === 'whatsapp' ? WAIT_FOR_SCAN_MS : WAIT_FOR_TOKEN_MS,
  });
  if (json) {
    process.stdout.write(`${JSON.stringify({ platform, connected })}\n`);
  } else if (connected) {
    logInfo('People can now link under Settings › Platforms in the app.');
  }
  if (!connected) process.exitCode = 1;
}

async function remove(platform, options, { store, prompt, ui, logOk, json }) {
  store.assertSharedPlatform(platform);
  if (!store.getConnection(platform)) throw new Error(`No shared ${platform} account is set up.`);
  const linked = store.countLinks(platform);
  if (!options.yes) {
    if (!ui.isInteractive()) throw new Error('Re-run with --yes to confirm.');
    const confirmed = await prompt.confirm(
      `Remove the shared ${platform} account and unlink ${linked} ${linked === 1 ? 'person' : 'people'}?`,
      { initial: false },
    );
    if (!confirmed) throw prompt.cancelledError();
  }
  store.removeConnection(platform, { source: 'cli' });
  if (json) process.stdout.write(`${JSON.stringify({ platform, removed: true })}\n`);
  else logOk(`Removed the shared ${platform} account.`);
}

async function cmdMessaging(args, context) {
  const [sub = 'list', platform] = args;
  const options = {
    noPersonal: args.includes('--no-personal'),
    tokenStdin: args.includes('--token-stdin'),
    yes: args.includes('--yes') || args.includes('-y'),
  };
  // Required late: these open the database, which most commands do not need.
  const store = require('../../server/services/messaging/shared_store');
  const { adminOverview } = require('../../server/services/messaging/shared_connections');
  const full = { ...context, store };

  if (sub === 'list') {
    const connections = adminOverview();
    if (context.json) {
      process.stdout.write(`${JSON.stringify({ connections: connections.map(({ qr, ...rest }) => rest) })}\n`);
      return;
    }
    for (const connection of connections) {
      context.ui.item(
        connection.status === 'connected' ? 'ok' : 'info',
        connection.platform,
        connection.configured ? describe(connection) : 'not set up',
      );
    }
    return;
  }
  if (!platform || platform.startsWith('--')) throw new Error(USAGE);
  if (sub === 'setup') return setup(platform, options, full);
  if (sub === 'remove') return remove(platform, options, full);
  if (sub === 'disconnect') {
    store.assertSharedPlatform(platform);
    if (!store.getConnection(platform)) throw new Error(`No shared ${platform} account is set up.`);
    store.configureConnection(platform, { enabled: false }, { source: 'cli' });
    if (context.json) process.stdout.write(`${JSON.stringify({ platform, enabled: false })}\n`);
    else context.logOk(`Disconnected the shared ${platform} account. Links are kept; run setup to reconnect.`);
    return;
  }
  throw new Error(USAGE);
}

module.exports = { cmdMessaging };
