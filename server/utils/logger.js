'use strict';

/**
 * Intercepts console methods and broadcasts logs via Socket.IO
 * @param {import('socket.io').Server} io 
 */
function setupConsoleInterceptor(io) {
    const logHistory = [];
    const MAX_LOG_HISTORY = 200;

    function broadcastLog(type, args) {
        const msg = Array.from(args).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
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
            if (!socket.request?.session?.userId) return;
            socket.emit('server:log_history', logHistory);
        });
    });

    return logHistory;
}

module.exports = { setupConsoleInterceptor };
