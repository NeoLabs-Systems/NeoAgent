'use strict';

// Long-term memory tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'memory_save',
    selection: 'default',
    resultShape: 'status',
    group: 'memory', access: 'write', sideEffect: 'memory', stateScope: 'memory', latencyClass: 'local', untrusted: false,
    capabilities: ['memory', 'remember', 'save'],
    policy: { safe: true },
    whenToUse: ['a durable fact or preference worth keeping across conversations'],
    whenNotToUse: ['run receipts or temporary task state'],
    description: 'Save ONE specific, self-contained fact to long-term semantic memory. RULES: (1) One discrete fact per call — if you have 10 facts, call this 10 times. (2) The ENTIRE value must be IN the content string itself — never write a pointer/reference like "user shared a profile" or "see chat history for details". That is useless. (3) Content must be a complete statement a stranger could read cold and understand, at most 150 characters. (4) Only save durable facts, preferences, or stable project context — never save recent task runs, task statuses, execution receipts, or other transient operational logs. GOOD: "XYZ lives in" / "XYZ prefers dark mode". BAD: "User pasted a profile dump" / "XYZ shared lots of details — see chat history" / "XYZ gave a big list of projects" / "Recent task run: backup completed".',
    parameters: {
      type: 'object',
      properties: {
        content: { type: 'string', maxLength: 150, description: 'The complete, self-contained fact, at most 150 characters. Must be readable standalone — no references to "above", "the dump", or "chat history". Write as a clear declarative sentence.' },
        category: { type: 'string', enum: ['user_fact', 'preference', 'personality', 'episodic', 'procedural'], description: 'user_fact: facts about the user (job, location, hardware...), preference: likes/dislikes/settings, personality: how to interact with them, episodic: events/tasks/learnings, procedural: reusable workflows or repeatable tool-use procedures' },
        importance: { type: 'number', description: 'Importance 1-10. 1=trivial, 5=default, 8+=critical. High-importance memories rank higher in recall.' },
        source: { type: 'string', enum: ['user_stated', 'tool_observed', 'inference'], description: 'Where the fact comes from. user_stated: the user said it in this conversation. tool_observed: a tool result in this run showed it. inference: your own conclusion, stored as an unconfirmed assumption. Leave it out if unsure; it is then treated as unverified.' },
        replaces: { type: 'array', items: { type: 'string' }, description: 'Ids of memories this fact replaces, from memory_recall or memory_list. They stop being recalled as current but stay in the history.' }
      },
      required: ['content']
    }
  },
  {
    name: 'memory_recall',
    selection: 'default',
    group: 'memory', access: 'read', stateScope: 'memory', latencyClass: 'local',
    capabilities: ['memory', 'recall', 'remember', 'history'],
    policy: { safe: true },
    whenToUse: ['something the user told you earlier that is not in the current context'],
    whenNotToUse: ['the fact is already in this conversation or the recalled context', 'general knowledge'],
    description: 'Search long-term memory for relevant information. Uses semantic similarity — describe what you are looking for in natural language. If the first search misses, try again with other wording, names, or related terms. Each result says its provenance: verified (the user said it or a tool showed it), retrieved (stored from elsewhere, may be out of date), or assumption (inferred, never confirmed). With include_history, current=false marks a fact that has been replaced.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'What to search for. Natural language query like "user food preferences" or "python script for file watching"' },
        limit: { type: 'number', description: 'Max results to return (default 6)' },
        as_of: { type: 'string', description: 'ISO date. Recall what was true at that time instead of now, e.g. where the user lived in 2024.' },
        include_history: { type: 'boolean', description: 'Also return facts that have since been replaced, to see how something changed.' }
      },
      required: ['query']
    }
  },
  {
    name: 'memory_list',
    group: 'memory', access: 'read', stateScope: 'memory', latencyClass: 'local',
    capabilities: ['memory', 'list'],
    policy: { safe: true },
    description: 'Page through every stored long-term memory, most important first. Use it to review memory as a whole, e.g. to find duplicates, outdated facts, or useless entries; use memory_recall to look something up.',
    parameters: {
      type: 'object',
      properties: {
        offset: { type: 'number', description: 'How many memories to skip (default 0). Use next_offset from the previous page.' },
        limit: { type: 'number', description: 'Page size (default 30, max 40)' }
      }
    }
  },
  {
    name: 'memory_forget',
    resultShape: 'status',
    group: 'memory', access: 'write', sideEffect: 'memory', stateScope: 'memory', latencyClass: 'local',
    capabilities: ['memory', 'forget', 'delete'],
    description: 'Archive long-term memories by id so they are no longer recalled. Use for duplicates, outdated or wrong facts, and entries with no lasting value. To correct a fact, save the corrected version with memory_save and name the old one in replaces, which keeps the history.',
    parameters: {
      type: 'object',
      properties: {
        ids: { type: 'array', items: { type: 'string' }, description: 'Ids of the memories to archive, from memory_list or memory_recall' }
      },
      required: ['ids']
    }
  },
  {
    name: 'session_search',
    group: 'memory', access: 'read', stateScope: 'memory', latencyClass: 'local',
    capabilities: ['memory', 'conversation', 'history', 'search'],
    policy: { safe: true },
    whenToUse: ['find what was said in past conversations'],
    description: 'Search past runs and message threads for commands, decisions, file paths, or context from earlier conversations.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'What to search for in prior sessions.' },
        limit: { type: 'number', description: 'How many matching sessions to return (default 6).' }
      },
      required: ['query']
    }
  },
  {
    name: 'memory_update_core',
    persistent: true,
    resultShape: 'status',
    group: 'memory', access: 'write', sideEffect: 'memory', stateScope: 'memory', latencyClass: 'local', untrusted: false,
    capabilities: ['memory', 'profile'],
    policy: { safe: true },
    description: 'Update core memory — always-injected facts that appear in every prompt. Use for critical always-relevant info: user\'s name, their main job, key standing preferences, how they want you to behave. Keep each entry concise.',
    parameters: {
      type: 'object',
      properties: {
        key: { type: 'string', enum: ['user_profile', 'preferences', 'ai_personality'], description: 'user_profile: who the user is, preferences: standing likes/dislikes, ai_personality: short freeform notes for how this agent should usually behave and write with this user (not scripts)' },
        value: { type: 'string', description: 'Value to set. Keep it concise — this is injected into every single prompt.' }
      },
      required: ['key', 'value']
    }
  },
  {
    name: 'memory_write',
    resultShape: 'status',
    group: 'memory', access: 'write', sideEffect: 'memory', stateScope: 'memory', latencyClass: 'local',
    capabilities: ['memory', 'notes'],
    description: 'Write to the daily log or agent-managed API keys.',
    parameters: {
      type: 'object',
      properties: {
        content: { type: 'string', description: 'Content to write/append' },
        target: { type: 'string', enum: ['daily', 'api_keys'], description: 'Where to write: daily (today log) or api_keys (API_KEYS.json)' },
        mode: { type: 'string', enum: ['append', 'replace'], description: 'append or replace (default append)' }
      },
      required: ['content', 'target']
    }
  },
  {
    name: 'memory_read',
    resultShape: 'status',
    group: 'memory', access: 'read', stateScope: 'memory', latencyClass: 'local',
    capabilities: ['memory', 'notes'],
    policy: { safe: true },
    description: 'Read daily logs or agent-managed API key names.',
    parameters: {
      type: 'object',
      properties: {
        target: { type: 'string', enum: ['daily', 'api_keys', 'all_daily'], description: 'Which memory to read' },
        date: { type: 'string', description: 'Date for daily log (YYYY-MM-DD)' }
      },
      required: ['target']
    }
  },
];
