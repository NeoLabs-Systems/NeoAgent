'use strict';

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

/**
 * Intercepts console methods and broadcasts logs via Socket.IO
 * @param {import('socket.io').Server} io 
 */
function setupConsoleInterceptor(io) {
    const logHistory = [];
    const MAX_LOG_HISTORY = 200;
    const allowLogHistoryRequests = String(process.env.NEOAGENT_ENABLE_LOG_HISTORY_REQUESTS || '').trim().toLowerCase() === 'true';

    function broadcastLog(type, args) {
        const msg = formatLogArgs(args);
        const logEntry = { type, message: msg, timestamp: new Date().toISOString() };
        logHistory.push(logEntry);
        if (logHistory.length > MAX_LOG_HISTORY) logHistory.shift();

        // Broadcast only to authenticated user rooms
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
