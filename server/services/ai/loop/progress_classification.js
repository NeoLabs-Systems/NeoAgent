'use strict';

const READ_ONLY_COMMANDS = new Set([
  'awk',
  'base64',
  'cat',
  'curl',
  'diff',
  'du',
  'egrep',
  'env',
  'fgrep',
  'find',
  'git',
  'grep',
  'head',
  'jq',
  'less',
  'ls',
  'pwd',
  'rg',
  'sed',
  'sort',
  'tail',
  'tee',
  'test',
  'tr',
  'tree',
  'wc',
  'which',
]);

const GIT_READ_ONLY_SUBCOMMANDS = new Set([
  'branch',
  'diff',
  'grep',
  'log',
  'ls-files',
  'ls-remote',
  'rev-parse',
  'show',
  'status',
]);

const STATE_CHANGING_COMMANDS = new Set([
  'apply_patch',
  'chmod',
  'chown',
  'cp',
  'git-clone',
  'git-commit',
  'git-push',
  'git-switch',
  'git-checkout',
  'git-merge',
  'git-rebase',
  'install',
  'mkdir',
  'mv',
  'npm',
  'pnpm',
  'rm',
  'rmdir',
  'touch',
  'yarn',
]);

function stripShellNoise(command = '') {
  return String(command || '')
    .replace(/(^|\n)\s*#.*(?=\n|$)/g, '\n')
    .replace(/\s+/g, ' ')
    .trim();
}

function firstToken(segment = '') {
  const match = String(segment || '').trim().match(/^([A-Za-z0-9_./-]+)/);
  return match ? match[1] : '';
}

function normalizeCommandName(token = '') {
  return String(token || '').trim().split('/').pop().toLowerCase();
}

function splitCommandSegments(command = '') {
  return stripShellNoise(command)
    .split(/\s*(?:&&|\|\||;|\||\n)\s*/g)
    .map((segment) => segment.trim())
    .filter(Boolean);
}

function stripEnvAssignments(segment = '') {
  let text = String(segment || '').trim();
  while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(text)) {
    text = text.replace(/^[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|\S+)\s*/, '').trim();
  }
  return text;
}

function gitSubcommand(segment = '') {
  const parts = stripEnvAssignments(segment).split(/\s+/).filter(Boolean);
  if (normalizeCommandName(parts[0]) !== 'git') return '';
  return String(parts[1] || '').toLowerCase();
}

function isReadOnlyGitCommand(segment = '') {
  const subcommand = gitSubcommand(segment);
  if (!subcommand) return false;
  return GIT_READ_ONLY_SUBCOMMANDS.has(subcommand);
}

function isReadOnlyInterpreterCommand(segment = '') {
  const normalized = stripEnvAssignments(segment);
  const commandName = normalizeCommandName(firstToken(normalized));
  if (!['node', 'perl', 'python', 'python3'].includes(commandName)) return false;
  if (/\b(open|write|writefile|appendfile|unlink|rename|mkdir|rmdir|remove|rm|spawn|exec)\b/i.test(normalized)) {
    return false;
  }
  return /\b(print|json\.|json_tool|json\.load|json\.loads|sys\.stdin|process\.exit|console\.log)\b|-m\s+json\.tool/i.test(normalized);
}

function hasStateChangingRedirect(segment = '') {
  const matches = String(segment || '').matchAll(/(?:^|[^&|;])(?:>>?|1>)\s*(?:"([^"]+)"|'([^']+)'|(\S+))/g);
  for (const match of matches) {
    const target = String(match[1] || match[2] || match[3] || '').trim();
    if (!target || target === '/dev/null') continue;
    if (target.startsWith('/tmp/') || target.startsWith('/var/tmp/')) continue;
    return true;
  }
  return false;
}

function isStateChangingShellSegment(segment = '') {
  const normalized = stripEnvAssignments(segment);
  if (hasStateChangingRedirect(normalized)) return true;
  const command = normalizeCommandName(firstToken(normalized));
  if (!command) return false;
  if (command === 'git') {
    const subcommand = gitSubcommand(normalized);
    return subcommand && !GIT_READ_ONLY_SUBCOMMANDS.has(subcommand);
  }
  return STATE_CHANGING_COMMANDS.has(command);
}

function isClearlyReadOnlyShellCommand(command = '') {
  const segments = splitCommandSegments(command);
  if (segments.length === 0) return false;
  return segments.every((segment) => {
    const normalized = stripEnvAssignments(segment);
    if (isStateChangingShellSegment(normalized)) return false;
    if (isReadOnlyGitCommand(normalized)) return true;
    if (isReadOnlyInterpreterCommand(normalized)) return true;
    const commandName = normalizeCommandName(firstToken(normalized));
    if (!commandName) return false;
    return READ_ONLY_COMMANDS.has(commandName);
  });
}

function isProgressToolCall(toolName, toolArgs = {}) {
  const name = String(toolName || '');
  if (!name) return false;
  if (name === 'activate_tools' || name === 'save_widget_snapshot') return false;
  if (name === 'send_interim_update') return false;
  if (/^(list_|search_|read_file|get_file|find_files?|github_list|github_get|github_search|browser_get|browser_read)/.test(name)) {
    return false;
  }
  if (name === 'http_request' || name === 'github_api_request') {
    return String(toolArgs?.method || 'GET').toUpperCase() !== 'GET';
  }
  if (name === 'execute_command') {
    return !isClearlyReadOnlyShellCommand(toolArgs?.command || '');
  }
  return true;
}

function buildReadOnlyChurnGuidance({ readOnlyCount = 0, alreadyRead = '' } = {}) {
  const count = Math.max(0, Number(readOnlyCount) || 0);
  const urgency = count >= 6 ? 'CRITICAL' : 'ACTION REQUIRED';
  return [
    `${urgency}: ${count} consecutive read-only turns with no concrete action.`,
    alreadyRead
      ? `You have already read/searched: ${alreadyRead}. Their output is in this conversation above, so do not read or search them again.`
      : 'Do not re-read or re-search anything already in this conversation.',
    'Decide from the evidence you have now.',
    'If the requested work is already done, no matching target exists, or the available tools cannot make the change, call task_complete with that truthful final answer or blocker.',
    'If exactly one concrete safe action remains, take that action now. Otherwise finish; more poking around is not progress.',
  ].join(' ');
}

module.exports = {
  buildReadOnlyChurnGuidance,
  isClearlyReadOnlyShellCommand,
  isProgressToolCall,
};
