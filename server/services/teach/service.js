'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const db = require('../../db/database');
const { DATA_DIR, ensurePrivateDirectory, ensurePrivateFile } = require('../../../runtime/paths');
const { createServiceLogger } = require('../../utils/logger');
const { sanitizeSkillName } = require('../ai/learning');
const { analyzeImageForUser } = require('../ai/imageAnalysis');

const logger = createServiceLogger('TeachMode');
const TEMP_ROOT = path.join(DATA_DIR, 'teach-sessions');
const MAX_EVENTS = 1000;
const MAX_SCREENSHOTS = 40;
const SESSION_TTL_MS = 30 * 60 * 1000;

function normalizeString(value, maximum = 500) {
  return String(value || '').trim().slice(0, maximum);
}

function normalizeStringList(value, maximumItems = 20, maximumLength = 500) {
  return Array.isArray(value)
    ? value.map((item) => normalizeString(item, maximumLength)).filter(Boolean).slice(0, maximumItems)
    : [];
}

function normalizeSynthesis(value, fallbackName, goal) {
  const source = value && typeof value === 'object' ? value : {};
  const steps = Array.isArray(source.steps)
    ? source.steps.map((step) => {
      if (typeof step === 'string') return normalizeString(step, 1000);
      if (!step || typeof step !== 'object') return '';
      return normalizeString(step.instruction || step.action || step.description, 1000);
    }).filter(Boolean).slice(0, 30)
    : [];
  return {
    name: sanitizeSkillName(source.name || fallbackName),
    description: normalizeString(source.description || `Workflow taught for: ${goal}`, 300),
    inputs: normalizeStringList(source.inputs, 20, 300),
    steps,
    successCriteria: normalizeStringList(source.successCriteria || source.success_criteria, 20, 500),
    recovery: normalizeStringList(source.recovery || source.recoveryStrategies, 20, 500),
    askUserWhen: normalizeStringList(source.askUserWhen || source.ask_user_when, 20, 500),
  };
}

function buildSkillInstructions(goal, synthesis) {
  const lines = [
    `# ${synthesis.name}`,
    '',
    '## Purpose',
    synthesis.description,
    '',
    '## Taught Goal',
    goal,
  ];
  if (synthesis.inputs.length > 0) {
    lines.push('', '## Required Inputs', ...synthesis.inputs.map((item) => `- ${item}`));
  }
  lines.push(
    '',
    '## Adaptive Procedure',
    'Inspect the current computer state before every action. Use semantic labels, visible state, DOM or accessibility information, and tool results; do not replay recorded coordinates.',
    ...synthesis.steps.map((step, index) => `${index + 1}. ${step}`),
  );
  if (synthesis.successCriteria.length > 0) {
    lines.push('', '## Success Criteria', ...synthesis.successCriteria.map((item) => `- ${item}`));
  }
  if (synthesis.recovery.length > 0) {
    lines.push('', '## Recovery', ...synthesis.recovery.map((item) => `- ${item}`));
  }
  if (synthesis.askUserWhen.length > 0) {
    lines.push('', '## Ask The User When', ...synthesis.askUserWhen.map((item) => `- ${item}`));
  }
  lines.push(
    '',
    '## Execution Contract',
    '- Execute through the normal NeoAgent agent loop and preserve all approval and security rules.',
    '- Re-evaluate the plan when the application state differs from the demonstration.',
    '- Verify the outcome instead of assuming an action succeeded.',
  );
  return lines.join('\n');
}

function encryptJson(key, value) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(value), 'utf8'),
    cipher.final(),
  ]);
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
}

function decryptJson(key, content) {
  const iv = content.subarray(0, 12);
  const tag = content.subarray(12, 28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return JSON.parse(Buffer.concat([
    decipher.update(content.subarray(28)),
    decipher.final(),
  ]).toString('utf8'));
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function buildSynthesisTimeline(events) {
  const source = Array.isArray(events) ? events : [];
  const maximum = 120;
  const indexes = source.length <= maximum
    ? source.map((_, index) => index)
    : Array.from({ length: maximum }, (_, index) => Math.round(index * (source.length - 1) / (maximum - 1)));
  return [...new Set(indexes)].map((index) => {
    const event = source[index] || {};
    const context = event.context || {};
    return {
      sequence: event.sequence,
      type: event.type,
      atMs: event.atMs,
      ...(event.key ? { key: event.key, modifiers: event.modifiers || {} } : {}),
      ...(event.detail ? { detail: normalizeString(event.detail, 300) } : {}),
      context: {
        activeWindow: context.activeWindow || null,
        accessibility: Array.isArray(context.accessibility)
          ? context.accessibility.slice(0, 30)
          : [],
        shellEvents: Array.isArray(context.shellEvents) ? context.shellEvents.slice(-10) : [],
        files: Array.isArray(context.files) ? context.files.slice(0, 30) : [],
        browser: context.browser
          ? {
            pageInfo: context.browser.pageInfo || null,
            content: normalizeString(context.browser.content, 1000),
            elements: Array.isArray(context.browser.elements)
              ? context.browser.elements.slice(0, 30)
              : [],
          }
          : null,
      },
    };
  });
}

function parseEvaluationResult(value) {
  const raw = value?.result ?? value;
  if (typeof raw !== 'string') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

class TeachService {
  constructor(options = {}) {
    this.runtimeManager = options.runtimeManager;
    this.agentEngine = options.agentEngine;
    this.skillRunner = options.skillRunner;
    this.imageAnalyzer = options.imageAnalyzer || analyzeImageForUser;
    this.io = options.io || null;
    this.sessions = new Map();
    ensurePrivateDirectory(TEMP_ROOT);
    for (const entry of fs.readdirSync(TEMP_ROOT)) {
      fs.rmSync(path.join(TEMP_ROOT, entry), { recursive: true, force: true });
    }
    this.cleanupTimer = setInterval(() => this.#cleanupExpired(), 60 * 1000);
    this.cleanupTimer.unref?.();
  }

  async start(userId, input = {}) {
    const key = String(userId || '').trim();
    const goal = normalizeString(input.goal, 1000);
    if (!key || !goal) {
      const error = new Error('A short Teach Mode goal is required.');
      error.status = 400;
      throw error;
    }
    const existing = this.getActiveSession(key);
    if (existing) {
      const error = new Error('Teach Mode is already recording for this computer.');
      error.status = 409;
      error.code = 'TEACH_ALREADY_RECORDING';
      throw error;
    }
    const id = crypto.randomUUID();
    this.runtimeManager.acquireControl(key, 'teach', id);
    const session = {
      id,
      userId: key,
      agentId: normalizeString(input.agentId, 128) || null,
      goal,
      status: 'recording',
      startedAt: Date.now(),
      updatedAt: Date.now(),
      events: [],
      screenshotCount: 0,
      lastScreenshotAt: 0,
      key: crypto.randomBytes(32),
      abortController: new AbortController(),
      lastFileState: new Map(),
      lastShellEventAt: 0,
      filePath: path.join(TEMP_ROOT, `${id}.teach`),
    };
    this.sessions.set(id, session);
    this.#persist(session);
    try {
      const [screenshot, context] = await Promise.all([
        this.#captureScreenshot(session),
        this.#captureSemanticContext(session),
      ]);
      session.events.push({
        sequence: 1,
        type: 'initial-state',
        atMs: 0,
        ...(screenshot ? { screenshot } : {}),
        context: this.#compactContext(session, context, true),
      });
      if (screenshot) session.screenshotCount = 1;
      this.#persist(session);
    } catch (error) {
      logger.warn('Unable to capture the initial Teach Mode state.', error.message);
    }
    this.#emit(session);
    return this.serialize(session);
  }

  getActiveSession(userId) {
    const key = String(userId || '').trim();
    return Array.from(this.sessions.values()).find(
      (session) => session.userId === key && ['recording', 'synthesizing'].includes(session.status),
    ) || null;
  }

  serialize(session) {
    return {
      id: session.id,
      goal: session.goal,
      status: session.status,
      startedAt: new Date(session.startedAt).toISOString(),
      eventCount: session.events.length,
      screenshotCount: session.screenshotCount,
      timeline: session.events.slice(-12).map((event) => ({
        sequence: event.sequence,
        type: event.type,
        atMs: event.atMs,
      })),
    };
  }

  async record(userId, event = {}) {
    const session = this.getActiveSession(userId);
    if (!session || session.status !== 'recording') return { recording: false };
    this.runtimeManager.acquireControl(session.userId, 'teach', session.id);
    if (session.events.length >= MAX_EVENTS) {
      return { recording: true, truncated: true, eventCount: session.events.length };
    }
    const type = normalizeString(event.type, 64);
    if (!['pointer', 'key', 'text-input', 'navigation', 'window', 'command', 'file'].includes(type)) {
      return { recording: true, ignored: true, eventCount: session.events.length };
    }
    const normalized = {
      sequence: session.events.length + 1,
      type,
      atMs: Date.now() - session.startedAt,
    };
    if (type === 'pointer') {
      normalized.position = {
        x: Number.isFinite(Number(event.x)) ? Math.round(Number(event.x)) : null,
        y: Number.isFinite(Number(event.y)) ? Math.round(Number(event.y)) : null,
      };
      normalized.button = Number.isFinite(Number(event.button)) ? Number(event.button) : 0;
    } else if (type === 'key') {
      normalized.key = normalizeString(event.key, 64);
      normalized.modifiers = {
        alt: event.modifiers?.alt === true,
        ctrl: event.modifiers?.ctrl === true,
        meta: event.modifiers?.meta === true,
        shift: event.modifiers?.shift === true,
      };
    } else if (type === 'text-input') {
      normalized.value = '[runtime input]';
    } else {
      normalized.detail = normalizeString(event.detail, 500);
    }
    session.events.push(normalized);
    session.updatedAt = Date.now();
    if (
      ['pointer', 'key'].includes(type)
      && session.screenshotCount < MAX_SCREENSHOTS
      && Date.now() - session.lastScreenshotAt >= 1000
    ) {
      session.lastScreenshotAt = Date.now();
      try {
        await delay(250);
        const screenshot = await this.#captureScreenshot(session);
        if (screenshot) {
          normalized.screenshot = screenshot;
          session.screenshotCount += 1;
        }
      } catch (error) {
        logger.warn('Unable to capture a Teach Mode frame.', error.message);
      }
    }
    if (['pointer', 'key', 'navigation', 'window', 'command', 'file'].includes(type)) {
      try {
        normalized.context = this.#compactContext(
          session,
          await this.#captureSemanticContext(session),
          false,
        );
      } catch (error) {
        logger.warn('Unable to capture Teach Mode semantic context.', error.message);
      }
    }
    this.#persist(session);
    this.#emit(session);
    return { recording: true, eventCount: session.events.length };
  }

  async #captureScreenshot(session) {
    try {
      const guest = await this.runtimeManager.requestComputer(
        session.userId,
        'GET',
        '/teach/context',
        undefined,
        { timeoutMs: 10000 },
      );
      if (guest?.sensitiveInputActive === true) return null;
    } catch {}
    try {
      const browser = await this.runtimeManager.getBrowserProviderForUser(session.userId);
      const sensitive = await browser.evaluate(`(() => Array.from(document.querySelectorAll('input,textarea,[contenteditable="true"]')).some((element) => {
        const style = getComputedStyle(element);
        const visible = style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
        const type = String(element.getAttribute('type') || '').toLowerCase();
        const autocomplete = String(element.getAttribute('autocomplete') || '').toLowerCase();
        return visible && (type === 'password' || autocomplete === 'current-password' || autocomplete === 'new-password');
      }))()`);
      if (parseEvaluationResult(sensitive) === true) return null;
    } catch {}
    const result = await this.runtimeManager.requestComputer(
      session.userId,
      'POST',
      '/desktop/screenshot',
      {},
      { timeoutMs: 30000 },
    );
    const guestPath = String(result?.path || '').trim();
    if (!guestPath) return null;
    const file = await this.runtimeManager.requestComputer(
      session.userId,
      'POST',
      '/files/read',
      { path: guestPath, encoding: 'base64', delete_after_read: true },
      { timeoutMs: 30000, maxResponseBytes: 8 * 1024 * 1024 },
    );
    const content = String(file?.content || '');
    return content.length <= 6 * 1024 * 1024 ? content : null;
  }

  async stop(userId, sessionId) {
    const session = this.sessions.get(String(sessionId || ''));
    if (!session || session.userId !== String(userId || '').trim()) {
      const error = new Error('Teach Mode session was not found.');
      error.status = 404;
      throw error;
    }
    if (session.status !== 'recording') {
      const error = new Error('Teach Mode session is not recording.');
      error.status = 409;
      throw error;
    }
    this.runtimeManager.acquireControl(session.userId, 'teach', session.id);
    session.status = 'synthesizing';
    session.updatedAt = Date.now();
    this.#persist(session);
    this.#emit(session);
    try {
      const context = await this.#captureSemanticContext(session);
      const finalScreenshot = await this.#captureScreenshot(session);
      session.events.push({
        sequence: session.events.length + 1,
        type: 'final-state',
        atMs: Date.now() - session.startedAt,
        ...(finalScreenshot ? { screenshot: finalScreenshot } : {}),
        context: this.#compactContext(session, context, false),
      });
      if (finalScreenshot) session.screenshotCount += 1;
      this.#persist(session);
      const visualFrames = await this.#describeScreenshots(session);
      const proposedSynthesis = await this.#synthesize(session, context, visualFrames);
      const synthesis = await this.#validateSynthesis(session, proposedSynthesis);
      if (session.abortController.signal.aborted) throw session.abortController.signal.reason;
      if (synthesis.steps.length === 0) throw new Error('The demonstration did not contain a reusable procedure.');
      const metadata = {
        category: 'taught',
        enabled: true,
        source: 'teach',
        auto_created: true,
        required_capabilities: ['computer'],
        taught_at: new Date().toISOString(),
        teach_provenance: {
          goal: session.goal,
          recorder: 'semantic-v1',
          sourceEventCount: session.events.length,
        },
      };
      const existing = db.prepare(
        'SELECT name, metadata FROM skills WHERE user_id = ? AND name = ?',
      ).get(session.userId, synthesis.name);
      let updateExisting = false;
      if (existing) {
        let existingMetadata = {};
        try { existingMetadata = JSON.parse(existing.metadata || '{}'); } catch {}
        updateExisting = existingMetadata?.source === 'teach'
          && existingMetadata?.teach_provenance?.goal === session.goal;
        if (!updateExisting) {
          const baseName = synthesis.name;
          let sequence = 2;
          while (db.prepare(
            'SELECT 1 FROM skills WHERE user_id = ? AND name = ?',
          ).get(session.userId, `${baseName}-${sequence}`)) sequence += 1;
          synthesis.name = `${baseName}-${sequence}`;
        }
      }
      const instructions = buildSkillInstructions(session.goal, synthesis);
      const result = updateExisting
        ? this.skillRunner.updateSkill(session.userId, synthesis.name, {
          description: synthesis.description,
          instructions,
          metadata,
        })
        : this.skillRunner.createSkill(
          session.userId,
          synthesis.name,
          synthesis.description,
          instructions,
          metadata,
        );
      if (!result?.success) throw new Error(result?.error || 'Skill creation failed.');
      this.#createSkillVersion(session.userId, synthesis.name);
      session.status = 'completed';
      this.#emit(session, { skill: synthesis.name });
      return { success: true, skill: synthesis.name, description: synthesis.description };
    } catch (error) {
      if (!['cancelled', 'expired'].includes(session.status)) {
        session.status = 'error';
        this.#emit(session, { error: normalizeString(error.message, 500) });
      }
      throw error;
    } finally {
      this.#purge(session);
    }
  }

  async #captureSemanticContext(session) {
    const context = {
      activeWindow: null,
      accessibility: [],
      shellEvents: [],
      files: [],
      browser: null,
    };
    try {
      const status = await this.runtimeManager.requestComputer(
        session.userId,
        'GET',
        '/teach/context',
        undefined,
        { timeoutMs: 10000 },
      );
      context.activeWindow = normalizeString(status?.activeWindow, 300) || null;
      context.accessibility = Array.isArray(status?.accessibility)
        ? status.accessibility.slice(0, 300)
        : [];
      context.shellEvents = Array.isArray(status?.shellEvents)
        ? status.shellEvents.slice(-50)
        : [];
      context.files = Array.isArray(status?.files) ? status.files.slice(0, 500) : [];
    } catch {}
    try {
      const browser = await this.runtimeManager.getBrowserProviderForUser(session.userId);
      const [pageInfo, extracted, dom] = await Promise.all([
        browser.getPageInfo(),
        browser.extractContent({ maxChars: 12000 }),
        browser.evaluate(`(() => Array.from(document.querySelectorAll('a,button,input,select,textarea,[role],[contenteditable="true"]')).filter((element) => {
          const style = getComputedStyle(element);
          return style.display !== 'none' && style.visibility !== 'hidden' && element.getClientRects().length > 0;
        }).slice(0, 300).map((element) => ({
          tag: element.tagName.toLowerCase(),
          role: element.getAttribute('role'),
          name: element.getAttribute('aria-label') || element.getAttribute('title') || element.getAttribute('placeholder') || String(element.innerText || '').trim().slice(0, 200),
          inputType: element.tagName === 'INPUT' ? String(element.getAttribute('type') || 'text').toLowerCase() : null,
          disabled: Boolean(element.disabled),
        })))()`),
      ]);
      context.browser = {
        pageInfo,
        content: normalizeString(extracted?.text || extracted?.content || extracted?.result, 12000),
        elements: (() => {
          const parsed = parseEvaluationResult(dom);
          return Array.isArray(parsed) ? parsed.slice(0, 300) : [];
        })(),
      };
    } catch {}
    return context;
  }

  #compactContext(session, context, initialize) {
    const files = [];
    const nextFileState = new Map();
    for (const file of Array.isArray(context.files) ? context.files : []) {
      const key = normalizeString(file?.path, 500);
      if (!key) continue;
      const signature = `${Number(file?.size || 0)}:${normalizeString(file?.modifiedAt, 64)}`;
      nextFileState.set(key, signature);
      if (!initialize && session.lastFileState.get(key) !== signature) {
        files.push({ path: key, size: Number(file?.size || 0), modifiedAt: file?.modifiedAt || null });
      }
    }
    if (!initialize) {
      for (const key of session.lastFileState.keys()) {
        if (!nextFileState.has(key)) files.push({ path: key, deleted: true });
      }
    }
    session.lastFileState = nextFileState;

    const shellEvents = (Array.isArray(context.shellEvents) ? context.shellEvents : [])
      .filter((event) => Number(event?.at || 0) > session.lastShellEventAt)
      .slice(-20);
    for (const event of shellEvents) {
      session.lastShellEventAt = Math.max(session.lastShellEventAt, Number(event?.at || 0));
    }
    if (initialize) shellEvents.length = 0;

    return {
      activeWindow: context.activeWindow || null,
      accessibility: Array.isArray(context.accessibility)
        ? context.accessibility.slice(0, 120)
        : [],
      shellEvents,
      files: files.slice(0, 100),
      browser: context.browser
        ? {
          pageInfo: context.browser.pageInfo || null,
          content: normalizeString(context.browser.content, 4000),
          elements: Array.isArray(context.browser.elements)
            ? context.browser.elements.slice(0, 120)
            : [],
        }
        : null,
    };
  }

  async #describeScreenshots(session) {
    const frames = session.events.filter((event) => event.screenshot);
    if (frames.length === 0) return [];
    const selectedIndexes = [...new Set([0, Math.floor((frames.length - 1) / 2), frames.length - 1])];
    const descriptions = [];
    for (const index of selectedIndexes) {
      const frame = frames[index];
      try {
        const result = await this.imageAnalyzer({
          userId: session.userId,
          agentId: session.agentId,
          imageBase64: frame.screenshot,
          mimeType: 'image/png',
          question: [
            'Describe this Linux desktop workflow frame for adaptive skill synthesis.',
            'Identify the visible application, semantic UI state, relevant controls, and evidence of progress or success.',
            'Do not infer or transcribe passwords, credentials, clipboard contents, or other secrets.',
          ].join(' '),
          signal: session.abortController.signal,
        });
        const description = normalizeString(result?.description, 2000);
        if (description) descriptions.push({
          type: frame.type,
          atMs: frame.atMs,
          description,
        });
      } catch (error) {
        if (session.abortController.signal.aborted) throw error;
        logger.warn('Teach Mode visual frame analysis was unavailable.', error.message);
        break;
      }
    }
    return descriptions;
  }

  async #synthesize(session, context, visualFrames) {
    const timeline = buildSynthesisTimeline(session.events);
    const fallbackName = sanitizeSkillName(session.goal);
    const response = await this.agentEngine.inferStructured({
      userId: session.userId,
      agentId: session.agentId,
      purpose: 'general',
      system: [
        'You convert a demonstrated Linux computer workflow into an adaptive NeoAgent skill.',
        'Return JSON only with name, description, inputs, steps, successCriteria, recovery, and askUserWhen.',
        'Steps must describe goals and semantic UI targets, never screen coordinates, brittle selectors, literal passwords, or macro replay.',
        'The later agent must inspect current state, adapt through its normal loop, verify outcomes, and ask only when judgment or authorization is required.',
      ].join(' '),
      prompt: JSON.stringify({
        goal: session.goal,
        timeline,
        activeWindow: context.activeWindow,
        browser: context.browser,
        visualFrames,
      }),
      maxTokens: 1800,
      signal: session.abortController.signal,
      fallback: {
        name: fallbackName,
        description: `Adaptive workflow for ${session.goal}`,
        inputs: [],
        steps: [],
        successCriteria: [],
        recovery: [],
        askUserWhen: [],
      },
    });
    return normalizeSynthesis(response.parsed, fallbackName, session.goal);
  }

  async #validateSynthesis(session, proposed) {
    const response = await this.agentEngine.inferStructured({
      userId: session.userId,
      agentId: session.agentId,
      purpose: 'general',
      system: [
        'You validate and repair a skill synthesized from a Linux computer demonstration.',
        'Return JSON only with approved and revised. revised must contain name, description, inputs, steps, successCriteria, recovery, and askUserWhen.',
        'Approve only an adaptive workflow that uses semantic state and the normal agent loop.',
        'The skill must contain no recorded coordinates, rigid macro replay, brittle timing, literal secrets, passwords, clipboard data, or unconditional destructive actions.',
        'Repair issues in revised when possible. Set approved false when the demonstration is insufficient to make a safe reusable skill.',
      ].join(' '),
      prompt: JSON.stringify({ goal: session.goal, proposed }),
      maxTokens: 1800,
      signal: session.abortController.signal,
      fallback: { approved: false, revised: proposed },
    });
    if (response.parsed?.approved !== true) {
      const error = new Error('The demonstrated workflow could not be validated as a safe adaptive skill.');
      error.code = 'TEACH_VALIDATION_FAILED';
      throw error;
    }
    return normalizeSynthesis(
      response.parsed.revised,
      proposed.name,
      session.goal,
    );
  }

  #createSkillVersion(userId, skillName) {
    const skill = db.prepare(
      'SELECT id, file_path, metadata FROM skills WHERE user_id = ? AND name = ?',
    ).get(userId, skillName);
    if (!skill) return;
    const content = fs.readFileSync(skill.file_path, 'utf8');
    const previous = db.prepare(
      'SELECT MAX(version) AS version FROM agent_skill_versions WHERE skill_id = ?',
    ).get(String(skill.id));
    const version = Math.max(0, Number(previous?.version || 0)) + 1;
    db.prepare(
      `INSERT INTO agent_skill_versions (
        id, skill_id, version, name, content_md, metadata_json, validated_at, status
      ) VALUES (?, ?, ?, ?, ?, ?, datetime('now'), 'validated')`,
    ).run(
      crypto.randomUUID(),
      String(skill.id),
      version,
      skillName,
      content,
      skill.metadata || '{}',
    );
  }

  cancel(userId, sessionId) {
    const session = this.sessions.get(String(sessionId || ''));
    if (!session || session.userId !== String(userId || '').trim()) return false;
    session.status = 'cancelled';
    session.abortController.abort(new Error('Teach Mode was cancelled.'));
    this.#emit(session);
    this.#purge(session);
    return true;
  }

  #persist(session) {
    const content = encryptJson(session.key, {
      id: session.id,
      userId: session.userId,
      agentId: session.agentId,
      goal: session.goal,
      status: session.status,
      startedAt: session.startedAt,
      updatedAt: session.updatedAt,
      events: session.events,
    });
    const temporary = `${session.filePath}.${process.pid}.tmp`;
    fs.writeFileSync(temporary, content, { mode: 0o600 });
    fs.renameSync(temporary, session.filePath);
    ensurePrivateFile(session.filePath);
  }

  #emit(session, extra = {}) {
    this.io?.to(`user:${session.userId}`).emit('teach:status', {
      ...this.serialize(session),
      ...extra,
    });
  }

  #purge(session) {
    this.runtimeManager.releaseControl(session.userId, session.id);
    fs.rmSync(session.filePath, { force: true });
    session.events.length = 0;
    session.key.fill(0);
    this.sessions.delete(session.id);
  }

  #cleanupExpired() {
    const now = Date.now();
    for (const session of this.sessions.values()) {
      if (now - session.updatedAt > SESSION_TTL_MS) {
        session.status = 'expired';
        session.abortController.abort(new Error('Teach Mode recording expired.'));
        this.#emit(session);
        this.#purge(session);
      }
    }
  }

  shutdown() {
    clearInterval(this.cleanupTimer);
    for (const session of Array.from(this.sessions.values())) {
      session.abortController.abort(new Error('Teach Mode service stopped.'));
      this.#purge(session);
    }
  }
}

module.exports = {
  TEMP_ROOT,
  TeachService,
  buildSynthesisTimeline,
  buildSkillInstructions,
  decryptJson,
  encryptJson,
  normalizeSynthesis,
};
