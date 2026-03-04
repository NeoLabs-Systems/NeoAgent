const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');

router.use(requireAuth);

// List agent runs
router.get('/', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200);
  const offset = parseInt(req.query.offset) || 0;
  const runs = db.prepare('SELECT * FROM agent_runs WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?')
    .all(req.session.userId, limit, offset);
  const total = db.prepare('SELECT COUNT(*) as count FROM agent_runs WHERE user_id = ?').get(req.session.userId).count;
  res.json({ runs, total, limit, offset });
});

// Chat history (web + social messages merged)
router.get('/chat-history', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 100, 500);
  const userId = req.session.userId;

  const webMsgs = db.prepare(`
    SELECT id, role, content, 'web' AS platform, NULL AS sender_name, created_at, agent_run_id AS run_id
    FROM conversation_history WHERE user_id = ? ORDER BY created_at DESC LIMIT ?
  `).all(userId, limit);

  const socialMsgs = db.prepare(`
    SELECT id, role, content, platform,
      json_extract(metadata, '$.senderName') AS sender_name, created_at, run_id
    FROM messages WHERE user_id = ? AND platform != 'web'
    ORDER BY created_at DESC LIMIT ?
  `).all(userId, limit);

  // Normalize SQL datetime ('YYYY-MM-DD HH:MM:SS', treated as local) and ISO-Z strings to ms
  const toMs = (s) => {
    if (!s) return 0;
    const normalized = s.includes('T') ? s : s.replace(' ', 'T') + 'Z';
    return new Date(normalized).getTime();
  };

  const all = [...webMsgs, ...socialMsgs]
    .sort((a, b) => toMs(a.created_at) - toMs(b.created_at))
    .slice(-limit);

  res.json({ messages: all });
});

// Create new agent run
router.post('/', async (req, res) => {
  try {
    const { task, options } = req.body;
    if (!task || typeof task !== 'string') return res.status(400).json({ error: 'Task must be a non-empty string' });
    if (task.length > 50000) return res.status(400).json({ error: 'Task exceeds maximum length of 50,000 characters' });

    const engine = req.app.locals.agentEngine;
    const result = await engine.run(req.session.userId, task, options || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Get specific run
router.get('/:id', (req, res) => {
  const run = db.prepare('SELECT * FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!run) return res.status(404).json({ error: 'Run not found' });

  const steps = db.prepare('SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC').all(run.id);
  const history = db.prepare('SELECT * FROM conversation_history WHERE agent_run_id = ? ORDER BY created_at ASC').all(run.id);

  res.json({ run, steps, history });
});

// Get detailed steps for a run (for activity history replay)
router.get('/:id/steps', (req, res) => {
  const run = db.prepare('SELECT * FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!run) return res.status(404).json({ error: 'Run not found' });

  const steps = db.prepare('SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC').all(run.id);
  const response = db.prepare(
    `SELECT content FROM conversation_history WHERE user_id = ? AND agent_run_id = ? AND role = 'assistant' ORDER BY created_at DESC LIMIT 1`
  ).get(req.session.userId, run.id);

  res.json({ run, steps, response: response?.content || null });
});

// Abort a run
router.post('/:id/abort', (req, res) => {
  try {
    const engine = req.app.locals.agentEngine;
    engine.abort(req.params.id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

// Delete a run
router.delete('/:id', (req, res) => {
  const run = db.prepare('SELECT id FROM agent_runs WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
  if (!run) return res.status(404).json({ error: 'Run not found' });

  db.prepare('DELETE FROM agent_steps WHERE run_id = ?').run(run.id);
  db.prepare('DELETE FROM conversation_history WHERE agent_run_id = ?').run(run.id);
  db.prepare('DELETE FROM agent_runs WHERE id = ?').run(run.id);
  res.json({ success: true });
});

// Multi-step task
router.post('/multi-step', async (req, res) => {
  try {
    const { task, steps, options } = req.body;
    if (!task) return res.status(400).json({ error: 'Task is required' });

    const multiStep = req.app.locals.multiStep;
    const result = await multiStep.create(req.session.userId, task, steps || [], options || {});
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: sanitizeError(err) });
  }
});

module.exports = router;
