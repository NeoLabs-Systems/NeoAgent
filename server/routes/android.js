'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const router = express.Router();
const { DATA_DIR } = require('../../runtime/paths');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { validateAndroidIntentUrl } = require('../utils/cloud-security');

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

async function getAndroidController(req) {
  const runtimeManager = req.app?.locals?.runtimeManager;
  if (runtimeManager && typeof runtimeManager.getAndroidProviderForUser === 'function') {
    return runtimeManager.getAndroidProviderForUser(req.session?.userId);
  }
  throw new Error('Android controller is unavailable.');
}

function handleAndroidAction(action) {
  return async (req, res) => {
    try {
      const controller = await getAndroidController(req);
      const result = await action(controller, req);
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: sanitizeError(err) });
    }
  };
}

router.get('/status', async (req, res) => {
  try {
    const controller = await getAndroidController(req);
    res.json(await controller.getStatus({ signal: req.signal }));
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/start', handleAndroidAction((controller, req) =>
  controller.requestStartEmulator({ ...(req.body || {}), signal: req.signal })));

router.post('/stop', handleAndroidAction((controller, req) => controller.stopEmulator({ signal: req.signal })));

router.get('/devices', handleAndroidAction(async (controller, req) => ({
  devices: await controller.listDevices({ signal: req.signal }),
})));

router.post('/screenshot', handleAndroidAction((controller, req) =>
  controller.screenshot({ ...(req.body || {}), signal: req.signal })));

router.post('/observe', handleAndroidAction((controller, req) =>
  controller.observe({ ...(req.body || {}), signal: req.signal })));

router.post('/ui-dump', handleAndroidAction((controller, req) =>
  controller.dumpUi({ ...(req.body || {}), signal: req.signal })));

router.get('/apps', handleAndroidAction((controller, req) =>
  controller.listApps({ includeSystem: req.query.includeSystem === 'true', signal: req.signal })));

router.post('/open-app', handleAndroidAction((controller, req) =>
  controller.openApp({ ...(req.body || {}), signal: req.signal })));

router.post('/open-intent', async (req, res) => {
  try {
    const body = req.body || {};
    const intentUrl = body.data || body.url || body.uri;
    if (
      intentUrl
      && typeof intentUrl === 'string'
      && !(await validateAndroidIntentUrl(intentUrl, { signal: req.signal })).allowed
    ) {
      return res.status(403).json({ error: 'This URL is not permitted.' });
    }
    const controller = await getAndroidController(req);
    const result = await controller.openIntent({ ...body, signal: req.signal });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

router.post('/tap', handleAndroidAction((controller, req) =>
  controller.tap({ ...(req.body || {}), signal: req.signal })));

router.post('/long-press', handleAndroidAction((controller, req) =>
  controller.longPress({ ...(req.body || {}), signal: req.signal })));

router.post('/type', handleAndroidAction((controller, req) =>
  controller.type({ ...(req.body || {}), signal: req.signal })));

router.post('/swipe', handleAndroidAction((controller, req) =>
  controller.swipe({ ...(req.body || {}), signal: req.signal })));

router.post('/press-key', handleAndroidAction((controller, req) =>
  controller.pressKey({ ...(req.body || {}), signal: req.signal })));

router.post('/wait-for', handleAndroidAction((controller, req) =>
  controller.waitFor({ ...(req.body || {}), signal: req.signal })));

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
      const controller = await getAndroidController(req);
      const result = await controller.installApk({ apkPath: uploadedApkPath, signal: req.signal });
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

router.post('/shell', handleAndroidAction((controller, req) => controller.shell({
  ...(req.body || {}),
  signal: req.signal,
})));

module.exports = router;
