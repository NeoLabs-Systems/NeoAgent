const ALWAYS_ON_TOOLS = ['notify_user'];

const PACKS = {
  code: ['execute_command', 'read_file', 'list_directory', 'search_files'],
  web: ['web_search', 'http_request', 'browser_navigate', 'browser_extract', 'browser_click', 'browser_type', 'browser_screenshot'],
  messaging: ['send_message', 'make_call'],
  memory: ['memory_recall', 'memory_save', 'memory_update_core', 'memory_read', 'memory_write'],
  scheduling: ['create_scheduled_task', 'schedule_run', 'list_scheduled_tasks', 'update_scheduled_task', 'delete_scheduled_task'],
  protocols: ['manage_protocols'],
  skills: ['create_skill', 'list_skills', 'update_skill', 'delete_skill'],
  images: ['generate_image', 'analyze_image'],
  tables: ['generate_table', 'generate_graph'],
  subagents: ['spawn_subagent'],
  mcpAdmin: ['mcp_add_server', 'mcp_list_servers', 'mcp_remove_server']
};

function containsAny(text, patterns) {
  return patterns.some((pattern) => pattern.test(text));
}

function detectRequestedPacks(task = '', options = {}) {
  const text = String(task || '').toLowerCase();
  const packs = new Set();

  if (containsAny(text, [
    /\b(run|execute|command|shell|terminal|bash|zsh|npm|node|python|script|repo|code|bug|fix|patch|test|build|file|folder|directory|grep|search files?)\b/,
    /\b(read|open|inspect)\s+(the\s+)?(file|repo|code)\b/
  ])) {
    packs.add('code');
  }

  if (containsAny(text, [
    /\b(web|website|url|page|browser|click|navigate|scrape|search|google|lookup|http|fetch|api request|screenshot)\b/,
    /\bopen\b.*\bsite\b/
  ])) {
    packs.add('web');
  }

  if (containsAny(text, [
    /\b(message|reply|respond|text|whatsapp|telegram|discord|dm|email|call|phone|notify|send to)\b/,
    /\[no response\]/,
    /\bsend_message\b/,
    /\bmake_call\b/
  ])) {
    packs.add('messaging');
  }

  if (containsAny(text, [
    /\bmemory\b/,
    /\bremember\b/,
    /\brecall\b/,
    /\bpreference\b/,
    /\bprofile\b/,
    /\bsoul\b/
  ])) {
    packs.add('memory');
  }

  if (containsAny(text, [
    /\bschedule\b/,
    /\bcron\b/,
    /\bremind\b/,
    /\brecurring\b/,
    /\bweekly\b/,
    /\bdaily\b/,
    /\bone-time\b/,
    /\btask\b.*\blater\b/
  ])) {
    packs.add('scheduling');
  }

  if (containsAny(text, [/\bprotocol\b/, /\bplaybook\b/])) {
    packs.add('protocols');
  }

  if (containsAny(text, [/\bskill\b/, /\binstall skill\b/, /\bcreate skill\b/])) {
    packs.add('skills');
  }

  if (containsAny(text, [/\bimage\b/, /\bpicture\b/, /\bphoto\b/, /\bgraph\b/, /\bchart\b/, /\btable\b/, /\bqr\b/, /\bocr\b/])) {
    packs.add('images');
  }

  if (containsAny(text, [/\btable\b/, /\bspreadsheet\b/, /\bgraph\b/, /\bchart\b/])) {
    packs.add('tables');
  }

  if (containsAny(text, [/\bsub-?agent\b/, /\bdelegate\b/, /\bparallel\b/, /\bbackground worker\b/])) {
    packs.add('subagents');
  }

  if (containsAny(text, [/\bmcp\b/, /\bmodel context protocol\b/, /\bserver tool\b/])) {
    packs.add('mcpAdmin');
  }

  if (options.mediaAttachments?.length) {
    packs.add('images');
  }

  return packs;
}

function maybeSelectMcpTools(text, mcpTools = []) {
  const normalized = String(text || '').toLowerCase();
  if (!normalized || !mcpTools.length) return [];

  const explicitMcp = /\bmcp\b|\bmodel context protocol\b/.test(normalized);
  return mcpTools.filter((tool) => {
    const name = String(tool.name || '').toLowerCase();
    const original = String(tool.originalName || '').toLowerCase();
    const server = String(tool.serverId || '').toLowerCase();
    return explicitMcp || normalized.includes(name) || normalized.includes(original) || (server && normalized.includes(server));
  });
}

function selectToolsForTask(task, builtInTools = [], mcpTools = [], options = {}) {
  const packs = detectRequestedPacks(task, options);
  const allowNames = new Set(ALWAYS_ON_TOOLS);

  for (const pack of packs) {
    for (const toolName of PACKS[pack] || []) {
      allowNames.add(toolName);
    }
  }

  const selectedBuiltIns = builtInTools.filter((tool) => allowNames.has(tool.name));
  const selectedMcp = maybeSelectMcpTools(task, mcpTools);

  return [...selectedBuiltIns, ...selectedMcp];
}

module.exports = {
  ALWAYS_ON_TOOLS,
  PACKS,
  detectRequestedPacks,
  selectToolsForTask
};
