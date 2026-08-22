'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');

function parseJson(value, fallback) {
  try {
    const parsed = JSON.parse(value || '');
    return parsed ?? fallback;
  } catch {
    return fallback;
  }
}

class SkillLearningRepository {
  recordActivity(userId, agentId, increment, threshold) {
    const scope = String(agentId || '');
    const transaction = db.transaction(() => {
      db.prepare(
        `INSERT INTO skill_learning_state (user_id, agent_scope, activity_score)
         VALUES (?, ?, ?)
         ON CONFLICT(user_id, agent_scope) DO UPDATE SET
           activity_score = activity_score + excluded.activity_score,
           updated_at = datetime('now')`,
      ).run(userId, scope, Math.max(1, Number(increment) || 1));
      const row = db.prepare(
        'SELECT activity_score FROM skill_learning_state WHERE user_id = ? AND agent_scope = ?',
      ).get(userId, scope);
      const score = Number(row?.activity_score || 0);
      if (score >= threshold) {
        db.prepare(
          `UPDATE skill_learning_state SET activity_score = 0, updated_at = datetime('now')
           WHERE user_id = ? AND agent_scope = ?`,
        ).run(userId, scope);
      }
      return score;
    });
    return transaction();
  }

  listCandidates(userId, limit = 20) {
    return db.prepare(
      `SELECT workflow_key, title, summary, observation_count, latest_run_id
       FROM skill_learning_candidates
       WHERE user_id = ? AND status = 'observing'
       ORDER BY updated_at DESC LIMIT ?`,
    ).all(userId, limit).map((row) => ({
      workflowKey: row.workflow_key,
      title: row.title,
      summary: row.summary,
      observationCount: Number(row.observation_count || 0),
      latestRunId: row.latest_run_id,
    }));
  }

  observeCandidate({ userId, workflowKey, title, summary, runId }) {
    const transaction = db.transaction(() => {
      const current = db.prepare(
        `SELECT id, observation_count, evidence_json, status, skill_name
         FROM skill_learning_candidates
         WHERE user_id = ? AND workflow_key = ?`,
      ).get(userId, workflowKey);
      const evidence = parseJson(current?.evidence_json, []);
      const alreadyObserved = evidence.some((item) => item?.runId === runId);
      const nextEvidence = [
        ...evidence.filter((item) => item?.runId !== runId),
        { runId, summary },
      ].slice(-8);
      if (current) {
        db.prepare(
          `UPDATE skill_learning_candidates
           SET title = ?, summary = ?, observation_count = ?,
               latest_run_id = ?, evidence_json = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
        ).run(
          title,
          summary,
          Number(current.observation_count || 0) + (alreadyObserved ? 0 : 1),
          runId,
          JSON.stringify(nextEvidence),
          current.id,
        );
      } else {
        db.prepare(
          `INSERT INTO skill_learning_candidates (
            id, user_id, workflow_key, title, summary, latest_run_id, evidence_json
          ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        ).run(
          randomUUID(),
          userId,
          workflowKey,
          title,
          summary,
          runId,
          JSON.stringify(nextEvidence),
        );
      }
      return db.prepare(
        `SELECT workflow_key, title, summary, observation_count, evidence_json, status, skill_name
         FROM skill_learning_candidates WHERE user_id = ? AND workflow_key = ?`,
      ).get(userId, workflowKey);
    });
    const row = transaction();
    return {
      workflowKey: row.workflow_key,
      title: row.title,
      summary: row.summary,
      observationCount: Number(row.observation_count || 0),
      evidence: parseJson(row.evidence_json, []),
      status: row.status,
      skillName: row.skill_name,
    };
  }

  promoteCandidate(userId, workflowKey, skillName) {
    db.prepare(
      `UPDATE skill_learning_candidates
       SET status = 'promoted', skill_name = ?, updated_at = datetime('now')
       WHERE user_id = ? AND workflow_key = ?`,
    ).run(skillName, userId, workflowKey);
  }

  recordEvaluation({ versionId, runId = null, score = null, outcome, notes }) {
    if (!versionId) return null;
    const id = randomUUID();
    db.prepare(
      `INSERT INTO agent_skill_evaluations (
        id, skill_version_id, run_id, score, outcome, notes
      ) VALUES (?, ?, ?, ?, ?, ?)`,
    ).run(id, versionId, runId, score, outcome, notes || '');
    return id;
  }
}

module.exports = { SkillLearningRepository };
