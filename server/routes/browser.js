const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// Get browser status
router.get('/status', (req, res) => {
  const bc = req.app.locals.browserController;
  res.json({
    launched: bc.isLaunched(),
    pages: bc.getPageCount(),
    headless: bc.headless
  });
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
    const result = await bc.click(selector, { text });
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
    const result = await bc.fill(selector, value);
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
