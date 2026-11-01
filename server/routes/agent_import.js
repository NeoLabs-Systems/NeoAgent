'use strict';

// Admin API for bringing OpenClaw or Hermes Agent over from the app
// (server/services/admin/agent_import.js). The import writes into the signed-in
// admin's account.

const express = require('express');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { PARTS } = require('../../lib/importers/sources');
const { listImportSources, runImport } = require('../services/admin/agent_import');
const { httpError } = require('../utils/http_error');
const { jsonHandler } = require('./_helpers/http');

const router = express.Router();
router.use(requireAuth, requireAdmin);

function stringList(value, field) {
  if (!Array.isArray(value) || !value.every((item) => typeof item === 'string')) {
    throw httpError(400, `${field} must be a list of strings`, 'INVALID_IMPORT_REQUEST');
  }
  return value;
}

function parseImportRequest(body) {
  const sourceIds = stringList(body?.sources, 'sources');
  if (!sourceIds.length) throw httpError(400, 'Choose at least one agent to bring over', 'INVALID_IMPORT_REQUEST');
  const parts = stringList(body?.parts ?? PARTS, 'parts');
  const unknown = parts.filter((part) => !PARTS.includes(part));
  if (unknown.length) throw httpError(400, `Unknown parts: ${unknown.join(', ')}`, 'INVALID_IMPORT_REQUEST');
  if (body?.finish !== undefined && typeof body.finish !== 'boolean') {
    throw httpError(400, 'finish must be true or false', 'INVALID_IMPORT_REQUEST');
  }
  return { sourceIds, parts, finish: body?.finish === true };
}

router.get('/sources', jsonHandler(() => listImportSources()));

router.post('/', jsonHandler((req) => runImport(req.session.userId, parseImportRequest(req.body))));

module.exports = router;
