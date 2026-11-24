'use strict';

const { GUEST_WORKSPACE_DIR, fromGuestWorkspacePath } = require('../runtime/guest_paths');
const { shellQuote } = require('../../utils/shell');
const { GIT_FUNCTION } = require('./git_snapshot');

// The coding tools read a repository through the shell of whichever computer the
// run uses, so a guest VM, a desktop companion, and host mode behave the same.
// Scripts stick to POSIX sh: the shell is bash in a guest and zsh on a Mac, so no
// variable may rely on word splitting, or be called `path` or `status`.
const MARKER = '@@neoagent:';
const READ_TIMEOUT_MS = 60_000;


function section(name) {
  return `printf '%s\\n' ${shellQuote(`${MARKER}${name}`)}`;
}

function workspaceRelative(value) {
  const text = String(value ?? '').trim();
  if (!text || text === '/workspace') return '.';
  if (text.startsWith('/workspace/')) return text.slice('/workspace/'.length) || '.';
  return fromGuestWorkspacePath(text) || '.';
}

// Moves into a directory, or a file's directory, or stops with a marker. By default
// it must be in the workspace, judged on the physical path, so neither `..` nor a
// symlink leaves it: the read tools run without approval and must not read what the
// file tools could not. A caller already allowed to go elsewhere passes anywhere.
function enterScript(target, { anywhere = false } = {}) {
  return [
    'neo_root=$(pwd -P)',
    `neo_dir=${shellQuote(workspaceRelative(target))}`,
    'neo_name=.',
    // A named file is searched from its directory; a link to one could point anywhere.
    'if [ -f "$neo_dir" ] && [ ! -L "$neo_dir" ]; then neo_name=$(basename -- "$neo_dir"); neo_dir=$(dirname -- "$neo_dir"); fi',
    `CDPATH= cd -- "$neo_dir" 2>/dev/null || { ${section('missing')}; exit 0; }`,
    ...(anywhere ? [] : [`case "$(pwd -P)/" in "$neo_root"/*) ;; *) ${section('outside')}; exit 0 ;; esac`]),
  ];
}

// Each marker opens a section. A login shell may print before the first one.
function parseSections(stdout) {
  const sections = [];
  let current = null;
  for (const line of String(stdout || '').split('\n')) {
    if (line.startsWith(MARKER)) {
      current = { name: line.slice(MARKER.length), lines: [] };
      sections.push(current);
    } else if (current) {
      current.lines.push(line);
    }
  }
  return sections;
}

function firstSection(sections, name) {
  return sections.find((entry) => entry.name === name) || null;
}

function sectionLines(sections, name) {
  return (firstSection(sections, name)?.lines || []).filter(Boolean);
}

function locationError(sections, target) {
  const shown = workspaceRelative(target);
  if (firstSection(sections, 'outside')) return `${shown} is outside the workspace.`;
  if (firstSection(sections, 'missing')) return `${shown} does not exist in the workspace.`;
  return '';
}

function commandError(result) {
  if (result?.error) return String(result.error);
  if (result?.timedOut) return 'The command timed out.';
  if (result?.killed) return 'The command was stopped.';
  return '';
}

// Null when no computer can run commands.
async function createWorkspaceShell(ctx) {
  const manager = ctx.runtime();
  if (typeof manager?.executeCliCommand !== 'function') return null;
  const workspace = ctx.computerWorkspace();
  const root = typeof workspace?.getWorkspaceRoot === 'function'
    ? await workspace.getWorkspaceRoot(ctx.userId)
    : GUEST_WORKSPACE_DIR;
  return {
    run(script, options = {}) {
      return manager.executeCliCommand(ctx.userId, script, {
        // The one working directory every computer maps to its own workspace.
        cwd: root,
        timeout: options.timeout || READ_TIMEOUT_MS,
        runId: ctx.runId,
        stepId: ctx.stepId,
        signal: ctx.signal,
        deviceTarget: ctx.deviceTarget,
      });
    },
  };
}

module.exports = {
  GIT_FUNCTION,
  commandError,
  createWorkspaceShell,
  enterScript,
  firstSection,
  locationError,
  parseSections,
  section,
  sectionLines,
  workspaceRelative,
};
