'use strict';

const READ_ONLY_COMMANDS = new Set([
  'base64',
  'cat',
  'diff',
  'du',
  'egrep',
  'fgrep',
  'find',
  'git',
  'grep',
  'head',
  'jq',
  'ls',
  'pwd',
  'rg',
  'sed',
  'sort',
  'tail',
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

// Things that run or write something inside a command that otherwise only reads. This
// decides what a read-only run may do, so anything doubtful counts as a change.
const WRITING_FLAGS = Object.freeze({
  // sed can write and run commands from inside its script, so only printing lines counts.
  sed: /^(?!sed\s+-n\s+["']?[\d,$;p\s]+["']?(?:\s+[^-\s]\S*)*\s*$)/,
  find: /\s-(?:delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)\b/,
  sort: /\s(?:-[a-zA-Z]*o|--output|--compress-program)\b/,
  rg: /\s--(?:pre|hostname-bin)\b/,
  base64: /\s(?:-o|--output)\b/,
  tree: /\s-o\b/,
});
const LISTING_GIT_BRANCH = /^git\s+branch(?:\s+(?:-a|-r|-v+|-vv|--list|--all|--remotes|--show-current|--no-color))*\s*$/;
const SENDING_CURL = /\s(?:-[a-zA-Z]*[XdFTOo]|--(?:request|data\S*|form\S*|upload-file|output|remote-name\S*|json))\b/;
const FD_DUPLICATION = /\d*>&\d/g;
const HIDDEN_EXECUTION = /\$\(|`|<\(|>\(|(?:^|[^&])&(?:[^&]|$)/;

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
    .replace(/\\\n/g, ' ')
    .replace(/(^|\n)\s*#.*(?=\n|$)/g, '\n')
    // A line break ends a command, so it must survive for the split below.
    .replace(/[^\S\n]+/g, ' ')
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
  if (!subcommand || !GIT_READ_ONLY_SUBCOMMANDS.has(subcommand)) return false;
  if (/\s(?:--output|--ext-diff|--open-files-in-pager|-O)/.test(segment)) return false;
  return subcommand !== 'branch' || LISTING_GIT_BRANCH.test(stripEnvAssignments(segment));
}

function hasStateChangingRedirect(segment = '') {
  const matches = String(segment || '').matchAll(/(?:^|[^&|;])(?:>>?|1>)\s*(?:"([^"]+)"|'([^']+)'|(\S+))/g);
  for (const match of matches) {
    const target = String(match[1] || match[2] || match[3] || '').trim();
    if (!target || target === '/dev/null' || /^&\d$/.test(target)) continue;
    if ((target.startsWith('/tmp/') || target.startsWith('/var/tmp/')) && !target.includes('..')) continue;
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

// `fetches` is for telling repeats apart: a plain download counts as the same evidence
// however it is piped, but it reaches the network, so it is not read-only for permissions.
function isClearlyReadOnlyShellCommand(command = '', { fetches = false } = {}) {
  if (HIDDEN_EXECUTION.test(stripShellNoise(command).replace(/&&/g, '').replace(FD_DUPLICATION, ''))) return false;
  const segments = splitCommandSegments(command);
  if (segments.length === 0) return false;
  return segments.every((segment) => {
    const normalized = stripEnvAssignments(segment);
    // A variable can change what a command runs (PAGER, LD_PRELOAD, GIT_EXTERNAL_DIFF).
    if (normalized !== segment) return false;
    if (isStateChangingShellSegment(normalized)) return false;
    if (normalizeCommandName(firstToken(normalized)) === 'git') return isReadOnlyGitCommand(normalized);
    const commandName = normalizeCommandName(firstToken(normalized));
    if (!commandName) return false;
    if (fetches && commandName === 'curl' && !SENDING_CURL.test(normalized)) return true;
    if (WRITING_FLAGS[commandName]?.test(normalized)) return false;
    return READ_ONLY_COMMANDS.has(commandName);
  });
}

module.exports = {
  isClearlyReadOnlyShellCommand,
};
