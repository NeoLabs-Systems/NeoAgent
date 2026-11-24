'use strict';

const os = require('os');
const { buildBehaviorSystemPrompt } = require('../behavior/system_prompt');
const { getUserTimeZone } = require('../account/timezone');
const { formatUtcOffset, serverTimeZone, utcOffsetMinutes } = require('../../utils/timezone');
const { promptVersion, renderFragment, selectStableFragments } = require('./prompts/registry');

const PROMPT_CACHE_TTL = 30_000;
const PROMPT_CACHE_MAX = 500;
const promptCache = new Map();

function evictExpiredPromptCache() {
  const now = Date.now();
  for (const [key, entry] of promptCache.entries()) {
    if (now >= entry.expiresAt) promptCache.delete(key);
  }
  if (promptCache.size > PROMPT_CACHE_MAX) {
    const excess = promptCache.size - PROMPT_CACHE_MAX;
    let deleted = 0;
    for (const key of promptCache.keys()) {
      if (deleted >= excess) break;
      promptCache.delete(key);
      deleted++;
    }
  }
}

function invalidateSystemPromptCache(userId, agentId = null) {
  const prefix = `${String(userId || 'global')}:${String(agentId || 'main')}:`;
  for (const key of promptCache.keys()) {
    if (key.startsWith(prefix)) promptCache.delete(key);
  }
}

function clampSection(text, maxChars) {
  const str = String(text || '').trim();
  if (!str) return '';
  if (str.length <= maxChars) return str;
  return `${str.slice(0, maxChars)}\n...[trimmed]`;
}

function buildRuntimeDetails() {
  return [
    `platform=${process.platform}`,
    `os=${os.type()} ${os.release()}`,
    `arch=${process.arch}`,
    `shell=${process.env.SHELL || '/bin/bash'}`,
    `cwd=${process.cwd()}`
  ].join('\n');
}

function formatCurrentLocalDateTime(timeZone, now = new Date()) {
  const localDateTime = new Intl.DateTimeFormat('sv-SE', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(now).replace(' ', 'T');

  const weekday = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'long'
  }).format(now);

  const tzName = new Intl.DateTimeFormat('en-US', {
    timeZone,
    timeZoneName: 'long'
  }).formatToParts(now).find((part) => part.type === 'timeZoneName')?.value || timeZone;

  const utcOffset = formatUtcOffset(utcOffsetMinutes(timeZone, now));

  return `${weekday} ${localDateTime} (${timeZone}, ${tzName}, UTC${utcOffset})`;
}

async function buildSystemPromptSections(userId, context = {}, memoryManager) {
  const agentId = context.agentId || null;
  const triggerSource = context.triggerSource || 'web';
  const cacheKey = [
    String(userId || 'global'),
    String(agentId || 'main'),
    triggerSource,
    context.memoryAudience || 'owner',
    context.source || 'none',
    context.chatId || 'none',
    context.latencyProfile || 'default',
    context.deviceTarget || 'none',
    context.workspaceRoot || 'default',
  ].join(':');
  const now = Date.now();
  const cached = promptCache.get(cacheKey);
  const hasExtraContext = Boolean(context.additionalContext || context.includeRuntimeDetails);
  if (!hasExtraContext && cached && now < cached.expiresAt) {
    return cached.sections;
  }

  const behaviorPrompt = await buildBehaviorSystemPrompt({
    userId,
    agentId,
    triggerSource,
    context,
    memoryManager,
  });
  const fragments = selectStableFragments({ triggerSource });
  const stable = [
    ...fragments.map((fragment) => fragment.text),
    ...behaviorPrompt.stable,
  ];
  // Public threads get neither the owner's timezone nor host details.
  const userTimeZone = context.publicAudience ? null : getUserTimeZone(userId);
  const dynamic = [
    userTimeZone
      ? `Current time in the user's timezone: ${formatCurrentLocalDateTime(userTimeZone)}. Times the user mentions are in this timezone unless they say otherwise.`
      : `Current server clock: ${formatCurrentLocalDateTime(serverTimeZone())}. Use it for date arithmetic only; it does not establish the user's location or timezone.`,
    ...behaviorPrompt.dynamic,
  ];
  if (!context.publicAudience && (context.includeRuntimeDetails || context.additionalContext)) {
    dynamic.push(`Runtime details:\n${buildRuntimeDetails()}`);
  }

  const memCtx = await memoryManager.buildContext(userId, {
    agentId,
    audience: context.memoryAudience || 'owner',
  });
  const compactMemory = clampSection(memCtx, 1600);
  if (compactMemory) {
    dynamic.push(compactMemory);
  }

  if (context.additionalContext) {
    dynamic.push(`Additional context:\n${clampSection(context.additionalContext, 1800)}`);
  }


  const sections = {
    stable: stable.filter(Boolean).join('\n\n'),
    dynamic: dynamic.filter(Boolean).join('\n\n'),
    promptVersion: promptVersion(fragments),
  };

  if (!hasExtraContext) {
    evictExpiredPromptCache();
    promptCache.set(cacheKey, { sections, expiresAt: now + PROMPT_CACHE_TTL });
  }

  return sections;
}

async function buildSystemPrompt(userId, context = {}, memoryManager) {
  const sections = await buildSystemPromptSections(userId, context, memoryManager);
  return [sections.stable, sections.dynamic].filter(Boolean).join('\n\n');
}

module.exports = {
  buildSystemPrompt,
  buildSystemPromptSections,
  invalidateSystemPromptCache,
};
