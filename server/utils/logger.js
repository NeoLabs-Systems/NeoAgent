'use strict';

const fs   = require('fs');
const path = require('path');

const SENSITIVE_KEY_RE = /(?:^|_|-)(?:token|secret|password|api[_-]?key|authorization|cookie|session(?:id)?|sid)(?:$|_|-)/i;

function redactSecrets(input) {
    let text = String(input || '');
    if (!text) return text;

    text = text
        .replace(/\b(Bearer\s+)[A-Za-z0-9._~+\/-]+=*/gi, '$1[redacted]')
        .replace(/([?&](?:token|access_token|refresh_token|api[_-]?key|secret|password|authorization|cookie|session|sid)=)([^&#\s]+)/gi, '$1[redacted]')
        .replace(/\b(token|access_token|refresh_token|authorization|api[_-]?key|secret|password|cookie|session(?:id)?|sid)\b\s*[:=]\s*("[^"]*"|'[^']*'|[^,\s;]+)/gi, '$1=[redacted]');

    return text;
}

function sanitizeUrl(value) {
    return redactSecrets(String(value || ''));
}

function isSensitiveKey(key) {
    return SENSITIVE_KEY_RE.test(String(key || ''));
}

function serializeValue(value, seen = new WeakSet()) {
    if (value instanceof Error) {
        return JSON.stringify({
            name: value.name,
            message: redactSecrets(value.message),
            stack: redactSecrets(value.stack),
            code: value.code,
            cause: value.cause instanceof Error
                ? { name: value.cause.name, message: redactSecrets(value.cause.message), stack: redactSecrets(value.cause.stack) }
                : value.cause
        });
    }

    if (typeof value === 'bigint') {
        return value.toString();
    }

    if (typeof value === 'function') {
        return `[Function ${value.name || 'anonymous'}]`;
    }

    if (!value || typeof value !== 'object') {
        return redactSecrets(String(value));
    }

    if (seen.has(value)) {
        return '[Circular]';
    }

    seen.add(value);

    try {
        return JSON.stringify(value, (key, nestedValue) => {
            if (isSensitiveKey(key)) {
                return '[redacted]';
            }
            if (nestedValue instanceof Error) {
                return {
                    name: nestedValue.name,
                    message: redactSecrets(nestedValue.message),
                    stack: redactSecrets(nestedValue.stack),
                    code: nestedValue.code
                };
            }
            if (typeof nestedValue === 'bigint') {
                return nestedValue.toString();
            }
            if (typeof nestedValue === 'string') {
                return redactSecrets(nestedValue);
            }
            return nestedValue;
        });
    } catch (err) {
        return `[Unserializable object: ${redactSecrets(err.message)}]`;
    } finally {
        seen.delete(value);
    }
}

function formatLogArgs(args) {
    return Array.from(args).map((value) => serializeValue(value)).join(' ');
}

function logRequestSummary(level, req, message, extra = null) {
    const prefix = `[HTTP] ${req.method} ${sanitizeUrl(req.originalUrl || req.url)}`;
    const summary = {
        ip: req.ip,
        userId: req.session?.userId || null,
        userAgent: req.get?.('user-agent') || null,
        ...extra
    };
    console[level](redactSecrets(`${prefix} ${message}`), summary);
}

function getLogFile() {
    try {
        const { DATA_DIR } = require('../../runtime/paths');
        return path.join(DATA_DIR, 'server-logs.jsonl');
    } catch {
        return path.join(require('os').homedir(), '.neoagent', 'data', 'server-logs.jsonl');
    }
}

function loadPersistedLogs(logFile) {
    try {
        const raw = fs.readFileSync(logFile, 'utf8');
        const entries = [];
        for (const line of raw.split('\n')) {
            if (!line.trim()) continue;
            try { entries.push(JSON.parse(line)); } catch {}
        }
        return entries.slice(-1000);
    } catch {
        return [];
    }
}

/**
 * Intercepts console methods and broadcasts logs via Socket.IO.
 * Persists up to 1000 entries to disk across server restarts.
 * @param {import('socket.io').Server} io
 */
function setupConsoleInterceptor(io) {
    const MAX_LOG_HISTORY = 1000;
    const TRIM_AT = 1100;
    const logFile = getLogFile();
    const allowLogHistoryRequests = String(process.env.NEOAGENT_ENABLE_LOG_HISTORY_REQUESTS || '').trim().toLowerCase() === 'true';

    try { fs.mkdirSync(path.dirname(logFile), { recursive: true }); } catch {}
    const logHistory = loadPersistedLogs(logFile);

    function broadcastLog(type, args) {
        const msg = formatLogArgs(args);
        const logEntry = { type, message: msg, timestamp: new Date().toISOString() };
        logHistory.push(logEntry);

        try { fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n'); } catch {}

        if (logHistory.length > TRIM_AT) {
            logHistory.splice(0, logHistory.length - MAX_LOG_HISTORY);
            try {
                fs.writeFileSync(logFile, logHistory.map(e => JSON.stringify(e)).join('\n') + '\n');
            } catch {}
        }

        for (const [, socket] of io.sockets.sockets) {
            const uid = socket.request?.session?.userId;
            if (uid) socket.emit('server:log', logEntry);
        }
    }

    const originalConsole = {
        log: console.log,
        error: console.error,
        warn: console.warn,
        info: console.info
    };

    console.log = function (...args) { originalConsole.log.apply(console, args); broadcastLog('log', args); };
    console.error = function (...args) { originalConsole.error.apply(console, args); broadcastLog('error', args); };
    console.warn = function (...args) { originalConsole.warn.apply(console, args); broadcastLog('warn', args); };
    console.info = function (...args) { originalConsole.info.apply(console, args); broadcastLog('info', args); };

    io.on('connection', (socket) => {
        socket.on('client:request_logs', () => {
            if (!allowLogHistoryRequests) return;
            if (!socket.request?.session?.userId) return;
            socket.emit('server:log_history', logHistory);
        });
    });

    return logHistory;
}

module.exports = {
    formatLogArgs,
    logRequestSummary,
    setupConsoleInterceptor
};
