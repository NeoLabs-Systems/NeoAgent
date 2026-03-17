/**
 * Security utilities — shared helpers for input validation and output sanitization.
 */

const HOME = process.env.HOME || process.env.USERPROFILE || '';
const PROJECT_ROOT = require('path').join(__dirname, '../..');

/**
 * Strip internal filesystem paths and module stack frames from an error message
 * before sending it to a client. Prevents leaking absolute paths, internal
 * directory structure, or dependency internals in API responses.
 */
function sanitizeError(err) {
  if (!err) return 'An unexpected error occurred';
  const raw = typeof err === 'string' ? err : err.message || String(err);

  let msg = raw;

  // Replace home directory path with ~
  if (HOME) {
    msg = msg.split(HOME).join('~');
  }

  // Replace project root path with [app]
  if (PROJECT_ROOT) {
    msg = msg.split(PROJECT_ROOT).join('[app]');
  }

  // Strip node_modules paths
  msg = msg.replace(/[^\s'"]+node_modules[^\s'"]+/g, '[module]');

  // Strip remaining absolute Unix paths (leave relative paths intact)
  msg = msg.replace(/\/[a-zA-Z0-9._-]+(?:\/[a-zA-Z0-9._-]+){2,}/g, '[path]');

  // Strip Windows absolute paths
  msg = msg.replace(/[A-Za-z]:\\[^\s'"]+/g, '[path]');

  return msg.trim() || 'An unexpected error occurred';
}

/**
 * Validate that a value is a plain string within an allowed length range.
 */
function validateString(value, { maxLength = 50000, name = 'value' } = {}) {
  if (typeof value !== 'string') throw new Error(`${name} must be a string`);
  if (value.length === 0) throw new Error(`${name} must not be empty`);
  if (value.length > maxLength) throw new Error(`${name} exceeds maximum length of ${maxLength} characters`);
  return value;
}

/**
 * Returns true if the string looks like it contains a prompt injection attempt.
 * This is a heuristic for logging/alerting — NOT a hard block (context window still applies).
 *
 * Covers: classic override phrases, jailbreak personas (DAN, AIM, etc.), roleplay unlocks,
 * structural tag injection, credential fishing, and multi-language variants.
 */
function detectPromptInjection(text) {
  if (typeof text !== 'string') return false;
  const patterns = [
    // Classic override
    /ignore\s+(all\s+)?previous\s+instructions/i,
    /disregard\s+(all\s+)?(prior|previous|your)\s+instructions/i,
    /override\s+(previous|prior|all|your)\s+instructions/i,
    /forget\s+(all\s+)?(previous|prior|your)\s+(instructions|context|training|rules|guidelines)/i,
    /do\s+not\s+follow\s+(your\s+)?(previous\s+)?instructions/i,

    // Persona jailbreaks
    /you\s+are\s+now\s+(DAN|GPT-?Dan|jailbreak|AIM|STAN|DUDE|AntiGPT|BasedGPT|DevMode)/i,
    /\bDAN\s+mode\b/i,
    /\bjailbreak\s+mode\b/i,
    /\bdev(eloper)?\s+mode\b/i,
    /act\s+as\s+if\s+you\s+have\s+no\s+(rules|restrictions|guidelines|filters|limits)/i,
    /pretend\s+(that\s+)?(you\s+(have\s+no|are\s+not|don't\s+have)|there\s+are\s+no)\s+(rules|restrictions|guidelines|filters|ethics)/i,
    /your\s+true\s+self\b/i,
    /your\s+real\s+(instructions|self|purpose|directives)/i,
    /hidden\s+(mode|instructions|directives|personality)/i,
    /(guidelines|restrictions|rules)\s+were\s+(just\s+a\s+)?test/i,

    // Structural tag injection
    /\[SYSTEM\]/i,
    /###\s*(SYSTEM|OVERRIDE|NEW\s+INSTRUCTIONS|ADMIN|ROOT)/i,
    /<\/?system>/i,
    /<\/?instructions?>/i,
    /<\/?prompt>/i,
    /\{system\}/i,

    // Credential / prompt fishing
    /reveal\s+(your\s+)?(system\s+)?(prompt|instructions|configuration|secret|key|token)/i,
    /print\s+(your\s+)?(system\s+)?(prompt|instructions)/i,
    /what\s+(is|are)\s+your\s+(system\s+)?(prompt|instructions|directives)/i,
    /show\s+(me\s+)?(your\s+)?(system\s+)?(prompt|instructions|full\s+context)/i,
    /output\s+(your\s+)?(system\s+)?(prompt|instructions|initial\s+prompt)/i,
    /repeat\s+(everything|all|your\s+instructions)\s+(above|before|prior)/i,
    /send\s+(me\s+)?(your|the)\s+(system\s+)?(prompt|instructions|api[\s_-]?key)/i,

    // Role/context manipulation
    /you\s+are\s+no\s+longer\s+(an?\s+)?(AI|assistant|language\s+model)/i,
    /from\s+now\s+on\s+you\s+(will|must|should|are\s+to)\s+.{0,60}(ignore|bypass|disregard)/i,
    /new\s+(role|persona|instructions|context|prompt)\s*:/i,
    /\[new\s+(instructions?|context|system)\]/i,
    /end\s+of\s+system\s+prompt/i,
    /---+\s*(instructions|system|new prompt)/i,

    // Credential exfiltration
    /(email|send|forward|transmit|share|leak|dump|export)\s+.{0,60}(api[\s_-]?key|secret|token|password|credential|\.env)/i,
  ];
  return patterns.some(p => p.test(text));
}

module.exports = { sanitizeError, validateString, detectPromptInjection };
