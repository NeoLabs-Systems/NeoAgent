const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

router.get('/status', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.getStatus());
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/start', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.requestStartEmulator(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/stop', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.stopEmulator());
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/devices', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json({ devices: await controller.listDevices() });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/screenshot', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.screenshot(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/ui-dump', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.dumpUi(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/apps', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.listApps({
      includeSystem: req.query.includeSystem === 'true',
    }));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/open-app', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.openApp(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/open-intent', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.openIntent(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/tap', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.tap(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/type', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.type(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/swipe', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.swipe(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/press-key', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.pressKey(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/wait-for', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.waitFor(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
