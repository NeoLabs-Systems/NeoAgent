'use strict';

function workspaceFolderName(workspaceRoot) {
  const normalized = String(workspaceRoot || '').trim().replace(/\\/g, '/');
  if (!normalized) return null;
  const parts = normalized.split('/').filter(Boolean);
  return parts.length ? parts[parts.length - 1] : null;
}

function buildCoworkWorkspaceFacts(context = {}) {
  const workspaceRoot = typeof context.workspaceRoot === 'string' && context.workspaceRoot.trim()
    ? context.workspaceRoot.trim()
    : null;
  return {
    workspaceRoot,
    folderName: workspaceFolderName(workspaceRoot),
    device: context.deviceTarget === 'local'
      ? 'this device'
      : context.deviceTarget === 'cloud'
        ? 'cloud computer'
        : null,
    mode: context.interactionMode === 'plan' ? 'plan' : 'agent',
  };
}

function buildSessionLines(facts) {
  const lines = [];
  if (facts.folderName && facts.workspaceRoot) {
    lines.push(
      `Open folder: ${facts.folderName} (${facts.workspaceRoot}). File tools treat this folder as the workspace root. Call list_directory(".") and use relative paths.`,
    );
  } else {
    lines.push(
      'Open folder: the default NeoAgent workspace on this computer. Call list_directory(".") to see what is already here.',
    );
  }
  if (facts.device) lines.push(`Computer: ${facts.device}.`);
  lines.push(facts.mode === 'plan' ? 'Mode: Plan (inspect only).' : 'Mode: Agent (edit now).');
  return lines;
}

function buildCoworkOperatingContract(context = {}) {
  if (context.triggerSource !== 'cowork') return '';
  const facts = buildCoworkWorkspaceFacts(context);
  return [
    'COWORK WORKSPACE',
    'You are in Cowork: a workspace session against an already-open project folder. This is not the all-in-one personal-assistant chat. The user already pointed you at the work. They do not need to paste a URL, clone a repo, or grant permission to start.',
    '',
    'SESSION',
    ...buildSessionLines(facts),
    '',
    'WORKFLOW',
    'Inspect the open folder before making project claims. Start with list_directory(".") and targeted search/read tools; infer the stack, entry points, conventions, and current state from the files. Shared chat attachments are already available.',
    'In Agent mode, apply requested changes in this run. Prefer workspace file tools for reads and edits; use execute_command for git, tests, builds, package managers, and other shell-native work.',
    'Match the existing structure and naming. Make the smallest coherent change that achieves the requested outcome, then re-read changed files or run a relevant check.',
    '',
    'BOUNDARIES',
    'The open folder is the source. Do not ask for a URL, repo, clone path, zip, or permission to start; do not clone or remotely rediscover code already present.',
    'Use web, browser, or GitHub only for evidence absent from the folder, such as current upstream docs or a live deployment the user explicitly asked to inspect.',
    'Do not permanently delete files unless requested. Do not expose internal VM paths; refer to the project by folder name and relative paths.',
    'Resolve discoverable facts yourself. Ask only about a material user-owned choice or destructive scope that the files cannot settle.',
    '',
    facts.mode === 'plan'
      ? [
        'PLAN MODE',
        'Inspect with read-only workspace and research tools and produce a decision-complete implementation plan. Do not run shell commands, mutate files, message people, or change external systems.',
      ].join('\n')
      : [
        'AGENT MODE',
        'Edit the workspace now. Lead the user-facing reply with what you changed. Keep working until the requested outcome is in the files or you hit a concrete blocker.',
      ].join('\n'),
  ].join('\n');
}

function buildCoworkExecutionGuidance(context = {}) {
  if (context.triggerSource !== 'cowork') return [];
  return [
    'Work from the attached workspace. In Agent mode, make the requested edits now; in Plan mode, inspect without mutation.',
    'Verify changed state from disk before claiming completion and lead the final reply with the outcome, not tool narration.',
  ];
}

module.exports = {
  buildCoworkExecutionGuidance,
  buildCoworkOperatingContract,
  buildCoworkWorkspaceFacts,
  workspaceFolderName,
};
