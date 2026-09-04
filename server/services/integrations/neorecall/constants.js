'use strict';

const PROVIDER_KEY = 'neorecall';
const APP = Object.freeze({
  id: 'recall',
  label: 'Recall',
  description: 'Search personal memories and their transcript evidence in a connected NeoRecall account.',
});
const SCOPES = Object.freeze(['search:read', 'memories:read', 'recordings:read']);
const TOOLS = Object.freeze([
  {
    name: 'neorecall_search',
    access: 'read',
    description: 'Search personal NeoRecall memories, mini-memories, daily summaries, and transcript evidence with local hybrid retrieval. Use for open-ended recall of past events, discussions, people, facts, tasks, or promises. Does not invoke NeoRecall Ask or another LLM.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Natural-language or keyword search query.' },
        kinds: {
          type: 'array',
          items: { type: 'string', enum: ['segment', 'memory', 'mini_memory', 'daily_summary'] },
          description: 'Optional result kinds to include.',
        },
        limit: { type: 'number', description: 'Maximum results from 1 to 100.' },
      },
      required: ['query'],
    },
  },
  {
    name: 'neorecall_list_memories',
    access: 'read',
    description: 'List typed episodic NeoRecall memories, optionally filtered by date window (from/to), type, or topic. Use when reconstructing what happened across a day or period.',
    parameters: {
      type: 'object',
      properties: {
        type: { type: 'string' }, topic: { type: 'string' }, from: { type: 'string' },
        to: { type: 'string' }, pinned: { type: 'boolean' }, archived: { type: 'boolean' }, limit: { type: 'number' },
      },
    },
  },
  {
    name: 'neorecall_get_memory',
    access: 'read',
    description: 'Get one NeoRecall memory with mini-memories, entities, topics, and exact transcript evidence links.',
    parameters: {
      type: 'object', properties: { memory_id: { type: 'string' } }, required: ['memory_id'],
    },
  },
  {
    name: 'neorecall_list_mini_memories',
    access: 'read',
    description: 'List atomic NeoRecall facts, events, people, relationships, tasks, and promises.',
    parameters: {
      type: 'object',
      properties: {
        kind: { type: 'string', enum: ['fact', 'event', 'location', 'person', 'relationship', 'task', 'promise'] },
        status: { type: 'string', enum: ['open', 'completed', 'cancelled'] }, limit: { type: 'number' },
      },
    },
  },
  {
    name: 'neorecall_list_daily_summaries',
    access: 'read',
    description: 'List NeoRecall daily summaries for a date range. Prefer this first for questions about what happened today, yesterday, or on a specific calendar day.',
    parameters: {
      type: 'object',
      properties: {
        from: { type: 'string', description: 'Inclusive local date YYYY-MM-DD.' },
        to: { type: 'string', description: 'Inclusive local date YYYY-MM-DD.' },
        limit: { type: 'number' },
      },
    },
  },
  {
    name: 'neorecall_list_conversations',
    access: 'read',
    description: 'List NeoRecall transcript conversations for a time range, including titles/summaries and memory-processing state. Use for who the user talked with today or recently.',
    parameters: {
      type: 'object', properties: { state: { type: 'string' }, from: { type: 'string' }, to: { type: 'string' }, limit: { type: 'number' } },
    },
  },
  {
    name: 'neorecall_get_conversation',
    access: 'read',
    description: 'Get one NeoRecall conversation with ordered original-language transcript segments and speaker assignments.',
    parameters: {
      type: 'object', properties: { conversation_id: { type: 'string' } }, required: ['conversation_id'],
    },
  },
].map((tool) => Object.freeze({ ...tool, appId: APP.id })));

module.exports = { APP, PROVIDER_KEY, SCOPES, TOOLS };
