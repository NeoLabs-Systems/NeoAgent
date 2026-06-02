'use strict';

const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

const router = express.Router();

const MAX_PATH_LENGTH = 2048;
const MAX_EDIT_BYTES = 1024 * 1024;

router.use(requireAuth);

function badRequest(message) {
  const error = new Error(message);
  error.status = 400;
  return error;
}

function parseWorkspacePath(value, fallback = '.') {
  const normalized = String(value ?? fallback).trim();
  if (normalized.length > MAX_PATH_LENGTH) {
    throw badRequest('path is too long.');
  }
  return normalized || fallback;
}

function getWorkspace(req) {
  const workspace = req.app?.locals?.workspaceManager;
  if (!workspace) {
    const error = new Error('Workspace service is unavailable.');
    error.status = 503;
    throw error;
  }
  return workspace;
}

function handleWorkspaceAction(req, res, action) {
  try {
    const result = action(getWorkspace(req));
    return res.json(result);
  } catch (err) {
    return res.status(err.status || 500).json({ error: sanitizeError(err), code: err.code || null });
  }
}

router.get('/files', (req, res) => handleWorkspaceAction(req, res, (workspace) =>
  workspace.listExplorerDirectory(req.session.userId, {
    path: parseWorkspacePath(req.query?.path, '.'),
  })));

router.get('/files/content', (req, res) => handleWorkspaceAction(req, res, (workspace) =>
  workspace.readExplorerFile(req.session.userId, {
    path: parseWorkspacePath(req.query?.path, ''),
    maxBytes: MAX_EDIT_BYTES,
  })));

router.put('/files/content', (req, res) => handleWorkspaceAction(req, res, (workspace) => {
  const content = String(req.body?.content ?? '');
  if (Buffer.byteLength(content, 'utf8') > MAX_EDIT_BYTES) {
    throw badRequest('content is too large.');
  }
  return workspace.writeExplorerFile(req.session.userId, {
    path: parseWorkspacePath(req.body?.path, ''),
    content,
  });
}));

router.get('/files/download', (req, res) => {
  try {
    const workspace = getWorkspace(req);
    const file = workspace.getExplorerDownload(req.session.userId, {
      path: parseWorkspacePath(req.query?.path, ''),
    });
    res.setHeader('Cache-Control', 'private, no-store');
    return res.download(file.absolutePath, file.filename, (err) => {
      if (!err || res.headersSent) return;
      const status = err.code === 'ENOENT' || err.code === 'EACCES' ? 404 : 500;
      res.status(status).json({ error: status === 404 ? 'File not found' : 'Failed to download file' });
    });
  } catch (err) {
    return res.status(err.status || 500).json({ error: sanitizeError(err), code: err.code || null });
  }
});

module.exports = router;
