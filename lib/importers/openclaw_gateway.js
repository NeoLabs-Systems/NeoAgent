'use strict';

// What OpenClaw's gateway runs, read for the importer: automations (cron
// jobs) and chat channels with their allowlists.

const os = require('os');
const path = require('path');
const {
  MESSAGING_PLATFORMS,
  expandHome,
  fromSlashModel,
  queryAll,
  readText,
  resolveSecret,
} = require('./common');
const { intervalToCron, toFiveFieldCron } = require('./schedules');

// Automations live in state/openclaw.sqlite (2026) or cron/jobs.json
// (before). Jobs OpenClaw manages itself (heartbeat, memory dreaming) carry a
// declaration key and are left behind.
function collectTasks(home, stateDb, agents, skipped) {
  let jobs = queryAll(stateDb, 'SELECT job_json FROM cron_jobs ORDER BY sort_order').map((row) => {
    try {
      return JSON.parse(row.job_json);
    } catch {
      return null;
    }
  }).filter(Boolean);
  if (jobs.length === 0) {
    const legacy = readText(path.join(home, 'cron', 'jobs.json'));
    try {
      const parsed = legacy ? JSON.parse(legacy) : null;
      jobs = Array.isArray(parsed) ? parsed : (parsed?.jobs || []);
    } catch {}
  }

  const defaultAgent = agents.find((agent) => agent.isDefault)?.key;
  const tasks = [];
  const seen = new Map();
  for (const job of jobs) {
    if (job.declarationKey || job.payload?.kind === 'heartbeat') continue;
    const name = String(job.displayName || job.name || 'Automation').trim();
    const prompt = promptFor(job.payload);
    if (!prompt) {
      const reason = job.payload?.kind === 'command'
        ? 'runs a shell command on this computer; NeoAgent\'s agent works on its own computer'
        : `"${job.payload?.kind || 'unknown'}" jobs have no NeoAgent equivalent`;
      skipped.push({ kind: 'Automation', name, reason, detail: { schedule: job.schedule, ...job.payload } });
      continue;
    }
    const trigger = triggerFor(job.schedule);
    if (!trigger) {
      skipped.push({ kind: 'Automation', name, reason: 'its schedule could not be read' });
      continue;
    }
    if (trigger.mode === 'one_time' && Date.parse(trigger.runAt) < Date.now()) {
      skipped.push({ kind: 'Automation', name, reason: 'a one-time job whose time has passed' });
      continue;
    }
    // The same job saved twice: keep one, with whichever chat target was set.
    const identity = `${name}|${prompt}|${trigger.cronExpression || trigger.runAt}`;
    const channel = job.delivery?.channel;
    const duplicate = seen.get(identity);
    if (duplicate) {
      if (duplicate.notify && !duplicate.notify.to && job.delivery?.to) duplicate.notify.to = job.delivery.to;
      continue;
    }
    const task = {
      name,
      agentKey: job.agentId || defaultAgent,
      prompt,
      trigger,
      enabled: job.enabled !== false,
      tz: job.schedule?.tz || null,
      notify: MESSAGING_PLATFORMS.has(channel) ? { platform: channel, to: job.delivery?.to || null } : null,
      model: fromSlashModel(job.payload?.model),
      note: trigger.note || null,
    };
    seen.set(identity, task);
    tasks.push(task);
  }
  return tasks;
}

function promptFor(payload = {}) {
  const text = payload.kind === 'agentTurn' ? payload.message : (payload.kind === 'systemEvent' ? payload.text : null);
  return String(text || '').trim() || null;
}

function triggerFor(schedule = {}) {
  if (schedule.kind === 'cron' && schedule.expr) {
    const converted = toFiveFieldCron(schedule.expr);
    if (!converted) return null;
    return { mode: 'recurring', cronExpression: converted.cron, note: converted.exact ? null : 'sub-minute timing rounded to the minute' };
  }
  if (schedule.kind === 'every' && schedule.everyMs) {
    const converted = intervalToCron(schedule.everyMs);
    return { mode: 'recurring', cronExpression: converted.cron, note: converted.exact ? null : 'interval rounded to the nearest cron step' };
  }
  if (schedule.kind === 'at' && schedule.at) {
    const runAt = new Date(schedule.at);
    return Number.isNaN(runAt.getTime()) ? null : { mode: 'one_time', runAt: runAt.toISOString() };
  }
  return null;
}

function collectChannels(home, config, env, stateDb, skipped) {
  const pairing = {};
  for (const row of queryAll(stateDb, 'SELECT channel_key, entry FROM channel_pairing_allow_entries ORDER BY sort_order')) {
    const platform = String(row.channel_key).split(/[:/]/)[0];
    (pairing[platform] = pairing[platform] || []).push(String(row.entry));
  }
  for (const platform of ['telegram', 'discord', 'whatsapp']) {
    for (const file of [`${platform}-allowFrom.json`, `${platform}-default-allowFrom.json`]) {
      const text = readText(path.join(home, 'credentials', file));
      try {
        const parsed = text ? JSON.parse(text) : null;
        const list = Array.isArray(parsed) ? parsed : parsed?.allowFrom;
        if (Array.isArray(list)) (pairing[platform] = pairing[platform] || []).push(...list.map(String));
      } catch {}
    }
  }

  const channels = [];
  const source = config.channels || {};
  const accountOf = (cfg) => {
    if (!cfg || typeof cfg !== 'object') return {};
    const accounts = Object.values(cfg.accounts || {}).filter((value) => value && typeof value === 'object');
    if (accounts.length > 1) skipped.push({ kind: 'Channel', name: 'extra accounts', reason: 'NeoAgent connects one account per platform; the first one was used' });
    return { ...(accounts[0] || {}), ...cfg };
  };
  const allowOf = (cfg, platform) => [...new Set([
    ...(Array.isArray(cfg.allowFrom) ? cfg.allowFrom : []),
    ...(Array.isArray(cfg.dm?.allowFrom) ? cfg.dm.allowFrom : []),
    ...(pairing[platform] || []),
  ].map((value) => String(value).trim()).filter((value) => value && value !== '*'))];

  const telegram = accountOf(source.telegram);
  const telegramToken = resolveSecret(telegram.botToken, env)
    || (telegram.tokenFile ? (readText(expandHome(telegram.tokenFile, os.homedir())) || '').trim() : null)
    || env.TELEGRAM_BOT_TOKEN;
  if (telegramToken && telegram.enabled !== false) {
    channels.push({ platform: 'telegram', config: { botToken: telegramToken }, allow: allowOf(telegram, 'telegram') });
  }

  const discord = accountOf(source.discord);
  const discordToken = resolveSecret(discord.token || discord.botToken, env) || env.DISCORD_BOT_TOKEN;
  if (discordToken && discord.enabled !== false) {
    channels.push({ platform: 'discord', config: { token: discordToken }, allow: allowOf(discord, 'discord') });
  }

  const whatsapp = accountOf(source.whatsapp);
  if (source.whatsapp && whatsapp.enabled !== false) {
    channels.push({ platform: 'whatsapp', config: null, allow: allowOf(whatsapp, 'whatsapp') });
    skipped.push({ kind: 'Channel', name: 'WhatsApp', reason: 'WhatsApp links to one app at a time; scan the QR code in NeoAgent (allowed numbers were kept)' });
  }

  if (source.slack && source.slack.enabled !== false) {
    skipped.push({ kind: 'Channel', name: 'Slack', reason: 'NeoAgent receives Slack events by webhook instead of socket mode; set it up under Integrations' });
  }
  for (const name of Object.keys(source)) {
    if (!MESSAGING_PLATFORMS.has(name) && source[name] && source[name].enabled !== false && typeof source[name] === 'object') {
      skipped.push({ kind: 'Channel', name, reason: 'not supported by NeoAgent' });
    }
  }
  return channels;
}

module.exports = {
  collectChannels,
  collectTasks,
};
