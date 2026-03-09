'use strict';

const crypto = require('crypto');

/**
 * Sets up Telnyx voice webhook route
 * @param {import('express').Application} app 
 */
function setupTelnyxWebhook(app) {
    const tokenMiddleware = (req, res, next) => {
        const expected = process.env.TELNYX_WEBHOOK_TOKEN;
        if (expected) {
            const provided = req.query.token || '';
            const a = Buffer.from(provided.padEnd(expected.length));
            const b = Buffer.from(expected);
            if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
                console.warn('[Telnyx webhook] Rejected request with invalid or missing token');
                return res.status(403).send('Forbidden');
            }
        }
        next();
    };

    app.post('/api/telnyx/webhook', tokenMiddleware, async (req, res) => {
        res.status(200).send('OK');
        const manager = app.locals.messagingManager;
        if (manager) {
            await manager.handleTelnyxWebhook(req.body).catch(err =>
                console.error('[Telnyx webhook]', err.message)
            );
        }
    });
}

module.exports = { setupTelnyxWebhook };
