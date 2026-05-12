const { CATEGORIES } = require('./manager');

const EXPORT_VERSION = 1;
const EXPORT_START = `[NEOAGENT_MEMORY_EXPORT_V${EXPORT_VERSION}]`;
const EXPORT_END = `[/NEOAGENT_MEMORY_EXPORT_V${EXPORT_VERSION}]`;

class MemoryTransferError extends Error {
  constructor(message) {
    super(message);
    this.name = 'MemoryTransferError';
  }
}

function buildMemoryTransferPrompt() {
  const categories = CATEGORIES.join(', ');
  return [
    'You are preparing a NeoAgent memory export that will be pasted back into NeoAgent.',
    'Reply ONLY with the template below. Do not add commentary.',
    'Use natural language inside each value/content block.',
    'Never include API keys, secrets, or credentials.',
    'If a section is empty, leave its block empty but keep the heading.',
    'Replace placeholder text inside <...> with real content.',
    '',
    EXPORT_START,
    '## Behavior Notes',
    '<<<',
    '<assistant behavior notes>',
    '>>>',
    '## Core Memory',
    '- key: user_profile',
    '  value: <<<',
    '  <natural language summary of the user>',
    '  >>>',
    '- key: preferences',
    '  value: <<<',
    '  <natural language preferences>',
    '  >>>',
    '- key: ai_personality',
    '  value: <<<',
    '  <assistant personality guidance>',
    '  >>>',
    '## Semantic Memories',
    '- content: <<<',
    '  <memory in natural language>',
    '  >>>',
    `  category: ${categories}`,
    '  importance: 5',
    '  archived: false',
    '## Daily Logs',
    '- date: YYYY-MM-DD',
    '  content: <<<',
    '  <daily log text>',
    '  >>>',
    EXPORT_END,
  ].join('\n');
}

function normalizeText(value) {
  return String(value || '').trim();
}

function extractExportBody(text) {
  const raw = String(text || '');
  const startIndex = raw.indexOf(EXPORT_START);
  if (startIndex === -1) {
    throw new MemoryTransferError(
      `Export text is missing the ${EXPORT_START} marker.`,
    );
  }
  const endIndex = raw.indexOf(EXPORT_END, startIndex + EXPORT_START.length);
  if (endIndex === -1) {
    throw new MemoryTransferError(
      `Export text is missing the ${EXPORT_END} marker.`,
    );
  }
  const body = raw.slice(startIndex + EXPORT_START.length, endIndex).trim();
  if (!body) {
    throw new MemoryTransferError('Export text is empty.');
  }
  return body;
}

function extractSections(body) {
  const lines = body.split(/\r?\n/);
  const sections = {
    behaviorNotes: [],
    coreMemory: [],
    semanticMemories: [],
    dailyLogs: [],
  };
  const headerMap = {
    'behavior notes': 'behaviorNotes',
    'core memory': 'coreMemory',
    'semantic memories': 'semanticMemories',
    'daily logs': 'dailyLogs',
  };
  let currentKey = null;
  for (const line of lines) {
    const headerMatch = line.match(/^##\s*(.+)\s*$/);
    if (headerMatch) {
      const label = headerMatch[1].trim().toLowerCase();
      currentKey = headerMap[label] || null;
      continue;
    }
    if (currentKey) {
      sections[currentKey].push(line);
    }
  }
  return Object.fromEntries(
    Object.entries(sections).map(([key, value]) => [key, value.join('\n').trim()]),
  );
}

function extractBlock(text, fieldName) {
  const blockRegex = new RegExp(
    `${fieldName}\\s*:\\s*(?:\\n\\s*)?<<<\\s*([\\s\\S]*?)\\s*>>>`,
    'i',
  );
  const blockMatch = text.match(blockRegex);
  if (blockMatch) {
    return blockMatch[1].trim();
  }
  const lineRegex = new RegExp(`${fieldName}\\s*:\\s*([^\\n]+)`, 'i');
  const lineMatch = text.match(lineRegex);
  return lineMatch ? lineMatch[1].trim() : '';
}

function extractLooseBlock(text) {
  const match = text.match(/<<<\s*([\s\S]*?)\s*>>>/);
  return match ? match[1].trim() : text.trim();
}

function splitListItems(text) {
  if (!text) return [];
  const lines = text.split(/\r?\n/);
  const items = [];
  let current = [];
  for (const line of lines) {
    if (line.trim().startsWith('- ')) {
      if (current.length) {
        items.push(current.join('\n').trim());
      }
      current = [line.replace(/^\s*-\s*/, '')];
      continue;
    }
    if (current.length) {
      current.push(line);
    }
  }
  if (current.length) {
    items.push(current.join('\n').trim());
  }
  return items.filter(Boolean);
}

function parseBoolean(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) return null;
  if (['true', 'yes', 'y', '1'].includes(normalized)) return true;
  if (['false', 'no', 'n', '0'].includes(normalized)) return false;
  return null;
}

function parseCoreMemory(sectionText) {
  const items = splitListItems(sectionText);
  return items
    .map((itemText) => {
      const key = extractBlock(itemText, 'key');
      const value = extractBlock(itemText, 'value');
      return {
        key: normalizeText(key),
        value: normalizeText(value),
      };
    })
    .filter((entry) => entry.key && entry.value);
}

function parseSemanticMemories(sectionText) {
  const items = splitListItems(sectionText);
  return items
    .map((itemText) => {
      const content = extractBlock(itemText, 'content');
      const category = extractBlock(itemText, 'category');
      const importanceRaw = extractBlock(itemText, 'importance');
      const archivedRaw = extractBlock(itemText, 'archived');
      const importance = Number.parseInt(importanceRaw, 10);
      const archived = parseBoolean(archivedRaw);
      return {
        content: normalizeText(content),
        category: normalizeText(category),
        importance: Number.isFinite(importance) ? importance : null,
        archived,
      };
    })
    .filter((entry) => entry.content);
}

function parseDailyLogs(sectionText) {
  const items = splitListItems(sectionText);
  return items
    .map((itemText) => {
      const date = extractBlock(itemText, 'date');
      const content = extractBlock(itemText, 'content');
      return {
        date: normalizeText(date),
        content: normalizeText(content),
      };
    })
    .filter((entry) => entry.date && entry.content);
}

function parseMemoryTransfer(text) {
  const body = extractExportBody(text);
  const sections = extractSections(body);
  const behaviorNotes = extractLooseBlock(sections.behaviorNotes || '');
  return {
    behaviorNotes: normalizeText(behaviorNotes),
    coreMemory: parseCoreMemory(sections.coreMemory || ''),
    semanticMemories: parseSemanticMemories(sections.semanticMemories || ''),
    dailyLogs: parseDailyLogs(sections.dailyLogs || ''),
  };
}

function mergeDailyLog(existing, incoming) {
  const trimmedExisting = String(existing || '').trim();
  const trimmedIncoming = String(incoming || '').trim();
  if (!trimmedIncoming) return trimmedExisting;
  if (!trimmedExisting) return trimmedIncoming;
  return `${trimmedExisting}\n\n--- Imported ---\n\n${trimmedIncoming}`;
}

function listAllMemories(memoryManager, userId, agentId) {
  const pageSize = 250;
  const all = [];
  for (const archived of [false, true]) {
    let offset = 0;
    while (true) {
      const page = memoryManager.listMemories(userId, {
        limit: pageSize,
        offset,
        includeArchived: archived,
        agentId,
      });
      if (!page.length) break;
      for (const mem of page) {
        all.push({
          ...mem,
          archived,
        });
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }
  }
  return all;
}

function buildMemoryTransferBundle(memoryManager, userId, agentId) {
  const behaviorNotes = memoryManager.getAssistantBehaviorNotes(userId, {
    agentId,
  });
  const coreMemory = memoryManager.getCoreMemory(userId, { agentId });
  const memories = listAllMemories(memoryManager, userId, agentId);
  const dailyLogs = memoryManager.listAllDailyLogs(userId);
  return {
    behaviorNotes: behaviorNotes || '',
    coreMemory: coreMemory || {},
    memories: memories.map((memory) => ({
      id: memory.id,
      content: memory.content,
      category: memory.category,
      importance: memory.importance,
      archived: Boolean(memory.archived),
      createdAt: memory.created_at || null,
      updatedAt: memory.updated_at || null,
    })),
    dailyLogs: dailyLogs.map((log) => ({
      date: log.date,
      content: log.content,
    })),
  };
}

function buildMemoryTransferMeta(bundle, prompt, agentId, apiKeyCount = 0) {
  const memoryCount = bundle.memories.length;
  const archivedCount = bundle.memories.filter((memory) => memory.archived).length;
  const meta = {
    version: EXPORT_VERSION,
    generatedAt: new Date().toISOString(),
    agentId,
    behaviorNotesLength: bundle.behaviorNotes.length,
    coreCount: Object.keys(bundle.coreMemory || {}).length,
    memoryCount,
    archivedCount,
    dailyLogCount: bundle.dailyLogs.length,
    apiKeyCount,
    bundleChars: JSON.stringify(bundle).length,
    promptChars: prompt.length,
  };
  return meta;
}

async function importMemoryTransfer(memoryManager, userId, agentId, text) {
  const parsed = parseMemoryTransfer(text);
  const warnings = [];
  const results = {
    behaviorNotesUpdated: false,
    coreMemoryUpdated: 0,
    memoriesImported: 0,
    memoriesArchived: 0,
    dailyLogsImported: 0,
  };

  if (parsed.behaviorNotes) {
    memoryManager.setAssistantBehaviorNotes(userId, parsed.behaviorNotes, {
      agentId,
    });
    results.behaviorNotesUpdated = true;
  }

  for (const entry of parsed.coreMemory) {
    memoryManager.updateCore(userId, entry.key, entry.value, { agentId });
    results.coreMemoryUpdated += 1;
  }

  for (const memory of parsed.semanticMemories) {
    const importance = Number.isFinite(memory.importance)
      ? Math.max(1, Math.min(10, memory.importance))
      : 5;
    const id = await memoryManager.saveMemory(
      userId,
      memory.content,
      memory.category || 'episodic',
      importance,
      {
        agentId,
        sourceRef: {
          sourceType: 'memory_transfer',
          sourceLabel: 'External LLM export',
        },
        metadata: {
          importSource: 'memory_transfer',
        },
      },
    );
    results.memoriesImported += 1;
    if (memory.archived === true) {
      memoryManager.archiveMemory(id, true);
      results.memoriesArchived += 1;
    } else if (memory.archived === false) {
      memoryManager.archiveMemory(id, false);
    }
  }

  for (const log of parsed.dailyLogs) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(log.date)) {
      warnings.push(`Skipped daily log with invalid date "${log.date}".`);
      continue;
    }
    const existing = memoryManager.readDailyLog(log.date, userId);
    const merged = mergeDailyLog(existing, log.content);
    memoryManager.writeDailyLog(log.date, merged, userId);
    results.dailyLogsImported += 1;
  }

  const hasContent =
    results.behaviorNotesUpdated ||
    results.coreMemoryUpdated > 0 ||
    results.memoriesImported > 0 ||
    results.dailyLogsImported > 0;

  if (!hasContent) {
    throw new MemoryTransferError('No importable content was found.');
  }

  return {
    summary: results,
    warnings,
  };
}

module.exports = {
  EXPORT_VERSION,
  EXPORT_START,
  EXPORT_END,
  MemoryTransferError,
  buildMemoryTransferPrompt,
  buildMemoryTransferBundle,
  buildMemoryTransferMeta,
  parseMemoryTransfer,
  importMemoryTransfer,
};
