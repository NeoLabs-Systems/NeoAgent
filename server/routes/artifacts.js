const express = require('express');
const path = require('path');
const { requireAuth } = require('../middleware/auth');
const { ARTIFACTS_ROOT } = require('../services/artifacts/store');

const router = express.Router();

router.use(requireAuth);

router.get('/:id/content', (req, res) => {
  const artifactStore = req.app?.locals?.artifactStore;
  if (!artifactStore) {
    return res.status(503).json({ error: 'Artifact store not available' });
  }

  const artifact = artifactStore.getArtifactForUser(req.session.userId, req.params.id);
  if (!artifact) {
    return res.status(404).json({ error: 'Artifact not found' });
  }

  if (artifact.content_type) {
    res.type(artifact.content_type);
  }
  res.setHeader('Cache-Control', 'private, max-age=60');
  const baseDir = path.resolve(ARTIFACTS_ROOT);
  const absolutePath = path.resolve(artifact.storage_path);
  const relativePath = path.relative(baseDir, absolutePath);
  if (!relativePath || relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
    return res.status(404).json({ error: 'Artifact not found' });
  }
  return res.sendFile(relativePath, { root: baseDir }, (err) => {
    if (!err) {
      return;
    }
    console.error('[Artifacts] sendFile error:', err);
    if (res.headersSent) {
      return;
    }
    if (err.code === 'ENOENT' || err.code === 'EACCES') {
      res.status(404).json({ error: 'File not found' });
      return;
    }
    res.status(500).json({ error: 'Failed to load artifact' });
  });
});

module.exports = router;
