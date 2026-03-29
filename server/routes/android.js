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

function getAndroidController(req) {
  return req.app.locals.androidController;
}

function handleAndroidAction(action) {
  return async (req, res) => {
    try {
      const controller = getAndroidController(req);
      const result = await action(controller, req);
      res.json(result);
    } catch (err) {
      res.status(500).json({ error: sanitizeError(err) });
    }
  };
}

router.get('/status', handleAndroidAction((controller) => controller.getStatus()));

router.post('/start', handleAndroidAction((controller, req) =>
  controller.requestStartEmulator(req.body || {})));

router.post('/stop', handleAndroidAction((controller) => controller.stopEmulator()));

router.get('/devices', handleAndroidAction(async (controller) => ({
  devices: await controller.listDevices(),
})));

router.post('/screenshot', handleAndroidAction((controller, req) =>
  controller.screenshot(req.body || {})));

router.post('/observe', handleAndroidAction((controller, req) =>
  controller.observe(req.body || {})));

router.post('/ui-dump', handleAndroidAction((controller, req) =>
  controller.dumpUi(req.body || {})));

router.get('/apps', handleAndroidAction((controller, req) =>
  controller.listApps({ includeSystem: req.query.includeSystem === 'true' })));

router.post('/open-app', handleAndroidAction((controller, req) =>
  controller.openApp(req.body || {})));

router.post('/open-intent', handleAndroidAction((controller, req) =>
  controller.openIntent(req.body || {})));

router.post('/tap', handleAndroidAction((controller, req) =>
  controller.tap(req.body || {})));

router.post('/long-press', handleAndroidAction((controller, req) =>
  controller.longPress(req.body || {})));

router.post('/type', handleAndroidAction((controller, req) =>
  controller.type(req.body || {})));

router.post('/swipe', handleAndroidAction((controller, req) =>
  controller.swipe(req.body || {})));

router.post('/press-key', handleAndroidAction((controller, req) =>
  controller.pressKey(req.body || {})));

router.post('/wait-for', handleAndroidAction((controller, req) =>
  controller.waitFor(req.body || {})));

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

router.post('/shell', handleAndroidAction((controller, req) => controller.shell(req.body || {})));

module.exports = router;
