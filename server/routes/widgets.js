const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { getAgentIdFromRequest, resolveAgentId } = require('../services/agents/manager');

router.use(requireAuth);

function widgetService(req) {
  return req.app?.locals?.widgetService;
}

router.get('/snapshots', (req, res) => {
  try {
    const service = widgetService(req);
    if (!service) {
      return res.status(500).json({ error: 'Widget service unavailable.' });
    }
    const agentId = req.query?.all === 'true'
      ? null
      : resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    res.json(service.listLatestSnapshots(req.session.userId, { agentId }));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.get('/', (req, res) => {
  try {
    const service = widgetService(req);
    if (!service) {
      return res.status(500).json({ error: 'Widget service unavailable.' });
    }
    const agentId = req.query?.all === 'true'
      ? null
      : resolveAgentId(req.session.userId, getAgentIdFromRequest(req));
    res.json(service.listWidgets(req.session.userId, { agentId }));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.post('/', async (req, res) => {
  try {
    const service = widgetService(req);
    if (!service) {
      return res.status(500).json({ error: 'Widget service unavailable.' });
    }
    const widget = await service.createWidget(req.session.userId, req.body || {});
    res.status(201).json(widget);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const service = widgetService(req);
    if (!service) {
      return res.status(500).json({ error: 'Widget service unavailable.' });
    }
    const widget = await service.updateWidget(req.session.userId, req.params.id, req.body || {});
    res.json(widget);
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.delete('/:id', (req, res) => {
  try {
    const service = widgetService(req);
    if (!service) {
      return res.status(500).json({ error: 'Widget service unavailable.' });
    }
    res.json(service.deleteWidget(req.session.userId, req.params.id));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

router.post('/:id/refresh', async (req, res) => {
  try {
    const service = widgetService(req);
    const taskRuntime = req.app?.locals?.taskRuntime;
    if (!service || !taskRuntime) {
      return res.status(500).json({ error: 'Widget refresh unavailable.' });
    }
    const widget = service.getWidget(req.session.userId, req.params.id);
    if (!widget) {
      return res.status(404).json({ error: 'Widget not found.' });
    }
    if (widget.isSystem || !widget.scheduledTaskId) {
      return res.json(await service.refreshWidget(req.session.userId, req.params.id));
    }
    res.json(await taskRuntime.runTaskNow(widget.scheduledTaskId, req.session.userId));
  } catch (err) {
    res.status(400).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
