const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// Get browser status
router.get('/status', async (req, res) => {
  try {
    const bc = req.app.locals.browserController;
    const pageInfo = await bc.getPageInfo();
    res.json({
      launched: bc.isLaunched(),
      pages: bc.getPageCount(),
      headless: bc.headless,
      pageInfo,
    });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Launch browser
router.post('/launch', async (req, res) => {
  try {
    const bc = req.app.locals.browserController;
    await bc.launch(req.body || {});
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Navigate to URL
router.post('/navigate', async (req, res) => {
  try {
    const { url, waitFor } = req.body;
    if (!url) return res.status(400).json({ error: 'url required' });

    const bc = req.app.locals.browserController;
    const result = await bc.navigate(url, { waitUntil: waitFor || 'domcontentloaded' });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Take screenshot
router.post('/screenshot', async (req, res) => {
  try {
    const bc = req.app.locals.browserController;
    const result = await bc.screenshot(req.body || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Click element
router.post('/click', async (req, res) => {
  try {
    const { selector, text } = req.body;
    const bc = req.app.locals.browserController;
    const result = await bc.click(selector, text, req.body?.screenshot !== false);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/click-point', async (req, res) => {
  try {
    const { x, y } = req.body || {};
    if (!Number.isFinite(Number(x)) || !Number.isFinite(Number(y))) {
      return res.status(400).json({ error: 'x and y required' });
    }
    const bc = req.app.locals.browserController;
    const result = await bc.clickPoint(x, y, req.body?.screenshot !== false);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Fill form field
router.post('/fill', async (req, res) => {
  try {
    const { selector, value } = req.body;
    if (!selector || value === undefined) return res.status(400).json({ error: 'selector and value required' });

    const bc = req.app.locals.browserController;
    const result = await bc.type(selector, String(value), {
      clear: req.body?.clear !== false,
      pressEnter: req.body?.pressEnter === true,
      screenshot: req.body?.screenshot !== false,
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/type-text', async (req, res) => {
  try {
    const { text } = req.body || {};
    const bc = req.app.locals.browserController;
    const result = await bc.typeText(String(text || ''), {
      pressEnter: req.body?.pressEnter === true,
      screenshot: req.body?.screenshot !== false,
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/press-key', async (req, res) => {
  try {
    const { key } = req.body || {};
    if (!key) return res.status(400).json({ error: 'key required' });
    const bc = req.app.locals.browserController;
    const result = await bc.pressKey(key, req.body?.screenshot !== false);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/scroll', async (req, res) => {
  try {
    const bc = req.app.locals.browserController;
    const result = await bc.scroll(
      req.body?.deltaX ?? 0,
      req.body?.deltaY ?? 0,
      req.body?.screenshot !== false,
    );
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Extract content
router.post('/extract', async (req, res) => {
  try {
    const bc = req.app.locals.browserController;
    const result = await bc.extractContent(req.body || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Execute JavaScript
router.post('/execute', async (req, res) => {
  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ error: 'code required' });

    const bc = req.app.locals.browserController;
    const result = await bc.executeJS(code);
    res.json({ result });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Close browser
router.post('/close', async (req, res) => {
  try {
    const bc = req.app.locals.browserController;
    await bc.closeBrowser();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
