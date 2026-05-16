const HEADING_ALIASES = {
  profile: 'identity',
  identity: 'identity',
  preferences: 'preferences',
  preference: 'preferences',
  projects: 'projects',
  project: 'projects',
  contacts: 'contacts',
  contact: 'contacts',
  events: 'events',
  event: 'events',
  tasks: 'tasks',
  task: 'tasks',
  'assistant self': 'assistant_self',
  self: 'assistant_self',
  'behavior notes': '__behavior_notes',
  'assistant behavior notes': '__behavior_notes',
  'core memory': '__core',
  'core memories': '__core',
  'other memories': 'episodic',
  other: 'episodic',
  misc: 'episodic',
  miscellaneous: 'episodic',
};

const SECTION_PRIORITY = {
  identity: 8,
  preferences: 7,
  projects: 6,
  contacts: 6,
  events: 6,
  tasks: 6,
  assistant_self: 7,
  episodic: 5,
};

const MAX_MEMORY_LENGTH = 1200;
const MAX_MEMORIES = 200;

function normalizeHeadingLabel(input) {
  return String(input || '')
    .trim()
    .replace(/^#+\s*/, '')
    .replace(/[:]+$/g, '')
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function detectHeading(line) {
  const trimmed = String(line || '').trim();
  if (!trimmed) return null;
  const normalized = normalizeHeadingLabel(trimmed);
  if (HEADING_ALIASES[normalized]) return normalized;
  return null;
}

function splitSections(text) {
  const lines = String(text || '').split(/\r?\n/);
  const sections = [];
  let current = { heading: 'other', lines: [] };

  for (const line of lines) {
    const heading = detectHeading(line);
    if (heading) {
      if (current.lines.length || current.heading) {
        sections.push(current);
      }
      current = { heading, lines: [] };
      continue;
    }
    current.lines.push(line);
  }

  if (current.lines.length || current.heading) {
    sections.push(current);
  }

  return sections;
}

function collectBulletItems(lines) {
  const items = [];
  for (const line of lines) {
    const match = String(line || '').match(/^\s*(?:[-*]|\u2022|\d+\.)\s+(.*)$/);
    if (match && match[1]) {
      const value = match[1].trim();
      if (value) items.push(value);
    }
  }
  return items;
}

function collapseParagraph(lines) {
  const parts = lines
    .map((line) => String(line || '').trim())
    .filter((line) => line.length > 0);
  if (!parts.length) return '';
  return parts.join(' ');
}

function normalizeMemoryContent(text) {
  const cleaned = String(text || '').trim();
  if (!cleaned) return '';
  if (cleaned.length <= MAX_MEMORY_LENGTH) return cleaned;
  return cleaned.slice(0, MAX_MEMORY_LENGTH).trim();
}

function buildLlmTransferPrompt({ agentLabel = 'NeoAgent' } = {}) {
  return [
    'You are preparing a memory export for ' + agentLabel + '.',
    'Produce a concise, structured summary of everything you know about the user. Be specific and concrete — names, preferences, and facts matter more than vague generalizations.',
    '',
    'Rules:',
    '- Plain text only. No JSON, no code blocks, no markdown tables.',
    '- Short bullet points. One fact per bullet. Prefer under 20 words per line.',
    '- State facts, not impressions. "Prefers Python over JavaScript" beats "enjoys coding".',
    '- Omit secrets, passwords, API keys, and sensitive credentials entirely.',
    '- Omit sections with no useful data.',
    '',
    'Use these sections and formatting:',
    '# Profile',
    '- Key identity facts: name, role, location, languages, and anything stable.',
    '# Preferences',
    '- Concrete preferences, defaults, and habits. Include tool, style, and workflow choices.',
    '# Projects',
    '- Ongoing projects with their current state and goal. Include deadlines if known.',
    '# Contacts',
    '- Important people or organizations, their role, and relationship to the user.',
    '# Events',
    '- Important dates, recurring events, or deadlines. Use absolute dates where possible.',
    '# Tasks',
    '- Open tasks or commitments the user expects to be remembered.',
    '# Behavior Notes',
    'Short, specific guidance for how the assistant should behave with this user.',
    '# Core Memory',
    'key: value entries for critical facts that must always be available.',
    '# Other Memories',
    '- Anything concrete that does not fit the sections above.',
  ].join('\n');
}

function parseLlmTransferText(text) {
  const sections = splitSections(text);
  const memories = [];
  const coreEntries = {};
  let behaviorNotes = '';
  const warnings = [];

  for (const section of sections) {
    const heading = normalizeHeadingLabel(section.heading || 'other');
    const alias = HEADING_ALIASES[heading] || 'episodic';
    const lines = section.lines || [];

    if (alias === '__behavior_notes') {
      const notes = collapseParagraph(lines);
      if (notes) behaviorNotes = notes;
      continue;
    }

    if (alias === '__core') {
      for (const rawLine of lines) {
        const line = String(rawLine || '').trim();
        if (!line) continue;
        const cleanedLine = line.replace(/^[-*]\s*/, '');
        const colonIndex = cleanedLine.indexOf(':');
        if (colonIndex <= 0) continue;
        const key = cleanedLine.slice(0, colonIndex).trim();
        const value = cleanedLine.slice(colonIndex + 1).trim();
        if (!key || !value) continue;
        if (key === 'active_context') continue;
        coreEntries[key] = value;
      }
      continue;
    }

    const bulletItems = collectBulletItems(lines);
    if (bulletItems.length) {
      for (const item of bulletItems) {
        const content = normalizeMemoryContent(item);
        if (!content) continue;
        memories.push({
          category: alias,
          content,
        });
      }
      continue;
    }

    const paragraph = normalizeMemoryContent(collapseParagraph(lines));
    if (paragraph) {
      memories.push({
        category: alias,
        content: paragraph,
      });
    }
  }

  if (memories.length > MAX_MEMORIES) {
    warnings.push('Import exceeded ' + MAX_MEMORIES + ' items; extra entries were skipped.');
  }

  return {
    memories: memories.slice(0, MAX_MEMORIES),
    coreEntries,
    behaviorNotes,
    warnings,
  };
}

function importanceForCategory(category) {
  return SECTION_PRIORITY[category] || 5;
}

module.exports = {
  buildLlmTransferPrompt,
  parseLlmTransferText,
  importanceForCategory,
};
