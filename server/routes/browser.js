const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { validateCloudUrl } = require('../utils/cloud-security');
const { getRuntimeValidation } = require('../services/runtime/validation');

router.use(requireAuth);

async function getBrowserController(req) {
  const runtimeManager = req.app?.locals?.runtimeManager;
  if (runtimeManager && typeof runtimeManager.getBrowserProviderForUser === 'function') {
    const start = Date.now();
    const runtimeController = await runtimeManager.getBrowserProviderForUser(req.session?.userId);
    const duration = Date.now() - start;
    if (duration > 1000) {
      console.log(`[HTTP] Browser controller acquired for user ${req.session?.userId} in ${duration}ms`);
    }
    if (runtimeController) {
      return runtimeController;
    }
  }
  throw new Error('Browser controller is unavailable. VM runtime is required.');
}

function getBrowserStatusSnapshot(req) {
  const runtimeValidation = getRuntimeValidation(req.app?.locals?.runtimeManager);
  const ready = Boolean(runtimeValidation?.ready);
  return {
    launched: false,
    pages: 0,
    headless: true,
    pageInfo: null,
    bootstrapped: false,
    canBootstrap: ready,
    runtimeReady: ready,
    lastStartError: ready ? null : (runtimeValidation?.issues?.[0] || 'VM runtime is not ready.'),
  };
}

// Get browser status
router.get('/status', async (req, res) => {
  try {
    const runtimeManager = req.app?.locals?.runtimeManager;
    if (!runtimeManager?.hasVmForUser?.(req.session?.userId, 'browser')) {
      res.json(getBrowserStatusSnapshot(req));
      return;
    }
    if (!await runtimeManager?.isGuestAgentReadyForUser?.(req.session?.userId, 6000, 'browser')) {
      res.json(getBrowserStatusSnapshot(req));
      return;
    }
    const bc = await getBrowserController(req);
    const pageInfo = await bc.getPageInfo();
    res.json({
      launched: await Promise.resolve(bc.isLaunched()),
      pages: await Promise.resolve(bc.getPageCount()),
      headless: bc.headless,
      pageInfo,
      bootstrapped: true,
      canBootstrap: true,
      runtimeReady: true,
      lastStartError: null,
    });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.get('/cookies', async (req, res) => {
  try {
    const bc = await getBrowserController(req);
    if (typeof bc.getCookies !== 'function') {
      return res.status(501).json({ error: 'Cookie export is unavailable for this browser provider.' });
    }
    const result = await bc.getCookies();
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Launch browser
router.post('/launch', async (req, res) => {
  try {
    const bc = await getBrowserController(req);
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

    const bc = await getBrowserController(req);

    if (bc.providerType === 'vm' && !validateCloudUrl(url).allowed) {
      return res.status(403).json({ error: 'This URL is not permitted.' });
    }

    const result = await bc.navigate(url, { waitUntil: waitFor || 'domcontentloaded' });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Take screenshot
router.post('/screenshot', async (req, res) => {
  try {
    const bc = await getBrowserController(req);
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
    const bc = await getBrowserController(req);
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
    const bc = await getBrowserController(req);
    const result = await bc.clickPoint(x, y, req.body?.screenshot !== false);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/mouse-move', async (req, res) => {
  try {
    const { x, y } = req.body || {};
    if (!Number.isFinite(Number(x)) || !Number.isFinite(Number(y))) {
      return res.status(400).json({ error: 'x and y required' });
    }
    const bc = await getBrowserController(req);
    const result = await bc.hoverPoint(x, y, req.body || {});
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

    const bc = await getBrowserController(req);
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
    const bc = await getBrowserController(req);
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
    const bc = await getBrowserController(req);
    const result = await bc.pressKey(key, req.body?.screenshot !== false);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/scroll', async (req, res) => {
  try {
    const bc = await getBrowserController(req);
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
    const bc = await getBrowserController(req);
    const result = await bc.extractContent(req.body || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Execute JavaScript
router.post('/execute', async (req, res) => {
  try {
    const executeEnabled = String(process.env.NEOAGENT_ENABLE_BROWSER_EXECUTE_ENDPOINT || '').trim().toLowerCase() === 'true';
    if (!executeEnabled) {
      return res.status(403).json({ error: 'Browser execute endpoint is disabled by default.' });
    }

    const { code } = req.body;
    if (!code) return res.status(400).json({ error: 'code required' });
    if (String(code).length > 10000) {
      return res.status(400).json({ error: 'code exceeds maximum length (10000)' });
    }

    const bc = await getBrowserController(req);
    const result = await bc.executeJS(code);
    res.json({ result });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Close browser
router.post('/close', async (req, res) => {
  try {
    const bc = await getBrowserController(req);
    await bc.closeBrowser();
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
