const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const router = express.Router();
const { DATA_DIR } = require('../../runtime/paths');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

const androidApkUploadDir = path.join(DATA_DIR, 'uploads', 'android-apks');
fs.mkdirSync(androidApkUploadDir, { recursive: true });
const INSTALLABLE_ANDROID_PACKAGE_EXTENSIONS = new Set(['.apk', '.apks']);

const androidApkUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, androidApkUploadDir),
    filename: (_req, file, cb) => {
      const extension = path.extname(file.originalname || '').toLowerCase();
      const stem = path.basename(file.originalname || 'upload', extension)
        .replace(/[^a-z0-9._-]+/gi, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 64) || 'upload';
      cb(
        null,
        `${Date.now()}-${Math.random().toString(16).slice(2)}-${stem}${extension || '.apk'}`
      );
    },
  }),
  fileFilter: (_req, file, cb) => {
    const extension = path.extname(String(file.originalname || '')).toLowerCase();
    if (!INSTALLABLE_ANDROID_PACKAGE_EXTENSIONS.has(extension)) {
      cb(new Error('Only .apk or .apks files can be installed.'));
      return;
    }
    cb(null, true);
  },
  limits: {
    fileSize: 512 * 1024 * 1024,
    files: 1,
  },
});

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

router.post('/observe', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.observe(req.body || {}));
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

router.post('/long-press', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.longPress(req.body || {}));
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

router.post('/install-apk', (req, res) => {
  androidApkUpload.single('apk')(req, res, async (uploadError) => {
    if (uploadError) {
      const message =
        uploadError instanceof multer.MulterError &&
          uploadError.code === 'LIMIT_FILE_SIZE'
        ? 'Android app upload is too large. Limit is 512MB.'
        : sanitizeError(uploadError);
      res.status(400).json({ error: message });
      return;
    }

    const uploadedApkPath = req.file?.path;
    if (!uploadedApkPath) {
      res.status(400).json({ error: 'No APK or APK bundle was uploaded.' });
      return;
    }

    try {
      const controller = req.app.locals.androidController;
      const result = await controller.installApk({ apkPath: uploadedApkPath });
      res.json({
        ...result,
        filename: req.file.originalname,
        size: req.file.size,
      });
    } catch (err) {
      res.status(500).json({ error: sanitizeError(err) });
    } finally {
      fs.promises.unlink(uploadedApkPath).catch(() => {});
    }
  });
});

router.post('/shell', async (req, res) => {
  try {
    const controller = req.app.locals.androidController;
    res.json(await controller.shell(req.body || {}));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
