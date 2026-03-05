const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

// List protocols
router.get('/', (req, res) => {
  try {
    const protocols = db.prepare('SELECT id, name, description, content, updated_at FROM protocols WHERE user_id = ? ORDER BY name ASC').all(req.session.userId);
    res.json(protocols);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get single protocol
router.get('/:id', (req, res) => {
  try {
    const p = db.prepare('SELECT * FROM protocols WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!p) return res.status(404).json({ error: 'Not found' });
    res.json(p);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create protocol
router.post('/', (req, res) => {
  try {
    const { name, description, content } = req.body;
    if (!name || !content) return res.status(400).json({ error: 'Name and content are required' });

    const stmt = db.prepare('INSERT INTO protocols (user_id, name, description, content) VALUES (?, ?, ?, ?)');
    const info = stmt.run(req.session.userId, name, description || '', content);
    
    const p = db.prepare('SELECT * FROM protocols WHERE id = ?').get(info.lastInsertRowid);
    res.status(201).json(p);
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      return res.status(400).json({ error: 'Protocol with this name already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// Update protocol
router.put('/:id', (req, res) => {
  try {
    const { name, description, content } = req.body;
    
    // check existence
    const existing = db.prepare('SELECT id FROM protocols WHERE id = ? AND user_id = ?').get(req.params.id, req.session.userId);
    if (!existing) return res.status(404).json({ error: 'Not found' });
    
    const stmt = db.prepare(`
      UPDATE protocols 
      SET name = ?, description = ?, content = ?, updated_at = datetime('now') 
      WHERE id = ? AND user_id = ?
    `);
    
    stmt.run(name, description || '', content, req.params.id, req.session.userId);
    const p = db.prepare('SELECT * FROM protocols WHERE id = ?').get(req.params.id);
    res.json(p);
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE') {
      return res.status(400).json({ error: 'Protocol with this name already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// Delete protocol
router.delete('/:id', (req, res) => {
  try {
    const stmt = db.prepare('DELETE FROM protocols WHERE id = ? AND user_id = ?');
    const info = stmt.run(req.params.id, req.session.userId);
    
    if (info.changes === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
