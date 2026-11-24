'use strict';

const path = require('path');
const { EVENT_TYPES } = require('./events/event_types');
const { createServiceLogger } = require('../../../utils/logger');
const { fromGuestWorkspacePath, GUEST_WORKSPACE_DIR } = require('../../runtime/guest_paths');
const { resolveToolMeta } = require('../tools/metadata');
const { snapshotCommand, GIT_FUNCTION } = require('../../workspace/git_snapshot');

const logger = createServiceLogger('Checkpoint');

// Snapshots provide advisory change tracking, not proof of ownership. External
// editors and processes can write during any tool, so automatic restore is refused.
const COMMAND_TIMEOUT_MS = 30_000;
// Reading a tree this slow around every call would cost more than an undo is worth.
const SLOW_READ_MS = 5_000;
const GITLINK_MODE = '160000';


function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

// Prints the repository root and a tree of the working tree as it is now. Runs from
// the workspace, so a relative directory means what the tool meant by it, and a file
// about to be created still finds its repository through the nearest existing parent.
function repositoryScript(directory, command) {
  return [
    'set -e',
    ...(directory ? [
      `d=${shellQuote(directory)}`,
      'while [ ! -d "$d" ] && [ "$d" != "." ] && [ "$d" != "/" ]; do d=$(dirname "$d"); done',
      'cd "$d"',
    ] : []),
    command,
  ].join('\n');
}

function runner(session) {
  const manager = session.app?.locals?.runtimeManager || session.engine?.runtimeManager;
  return typeof manager?.executeCliCommand === 'function' ? manager : null;
}

// The file a file tool names, as the tool itself resolves it.
function targetFile(call) {
  if (resolveToolMeta(call.name).group === 'shell') return null;
  const target = call.arguments?.path;
  return target ? fromGuestWorkspacePath(String(target)) : null;
}

// Where a call works. A shell command often moves there itself: "cd project && ...".
function commandDirectory(call) {
  if (resolveToolMeta(call.name).group === 'shell') {
    if (call.arguments?.cwd) return fromGuestWorkspacePath(String(call.arguments.cwd));
    const moved = /^\s*cd\s+("[^"]+"|'[^']+'|[^\s;&|]+)\s*(?:&&|;)/.exec(String(call.arguments?.command || ''));
    return moved ? fromGuestWorkspacePath(moved[1].replace(/^["']|["']$/g, '')) : null;
  }
  const file = targetFile(call);
  return file ? path.posix.dirname(file) : null;
}

function run(session, manager, script, options = {}) {
  return manager.executeCliCommand(session.userId, script, {
    // The one working directory every computer maps to its own workspace, which is
    // what a relative path in a tool call means.
    cwd: GUEST_WORKSPACE_DIR,
    timeout: COMMAND_TIMEOUT_MS,
    runId: session.runId,
    signal: session.getActiveSignal?.(),
    deviceTarget: session.deviceTarget,
    ...options,
  });
}

async function readTree(session, manager, directory) {
  const result = await run(session, manager, repositoryScript(directory, snapshotCommand()));
  if (result?.exitCode !== 0) {
    return { notRepository: /not a git repository/i.test(String(result?.stderr || '')) };
  }
  const [root, tree] = String(result.stdout || '').trim().split('\n');
  // The tree is later handed to git as a revision.
  return root && /^[0-9a-f]{40,64}$/.test(tree || '') ? { root, tree } : {};
}

// ":100644 100644 <old> <new> M\tpath". Unusual names come back quoted, and those
// are left out: not recording a file only means rollback leaves it alone.
function parseRawDiff(text) {
  return String(text || '').split('\n').flatMap((line) => {
    const match = /^:(\d+) (\d+) ([0-9a-f]+) ([0-9a-f]+) \S+\t(.+)$/.exec(line);
    if (!match || match[5].startsWith('"')) return [];
    return [{
      path: match[5],
      gitlink: match[1] === GITLINK_MODE || match[2] === GITLINK_MODE,
    }];
  });
}

function noteUntracked(session, call, reason) {
  const state = session.checkpoints;
  state.untracked.push({ tool: call.name, reason });
  session.eventBus.publish({
    runId: session.runId,
    userId: session.userId,
    agentId: session.agentId,
    eventType: EVENT_TYPES.WORKSPACE_CHANGED,
    payload: { untracked: true, tool: call.name, reason },
  });
}

/**
 * Reads the tree a mutating call starts from. A failure never stops the work, but it
 * is recorded, so rollback and the run's outcome can say what they do not cover.
 * Returns what recordMutation needs afterwards.
 */
async function ensureCheckpoint(session, call) {
  const manager = runner(session);
  if (!manager) return null;
  session.checkpoints ||= { notRepositories: new Set(), repositories: new Map(), untracked: [] };
  const state = session.checkpoints;
  const directory = commandDirectory(call);
  const key = directory || '.';
  if (state.notRepositories.has(key)) {
    noteUntracked(session, call, 'not_a_repository');
    return null;
  }

  state.directories ||= new Map();
  const started = Date.now();
  try {
    let knownRoot = state.directories.get(key);
    if (!knownRoot && [...state.repositories.values()].some((repository) => repository.tooSlow)) {
      // Resolve identity cheaply before deciding whether a full snapshot is allowed.
      const script = repositoryScript(directory, `${GIT_FUNCTION}\ng rev-parse --show-toplevel`);
      const result = await run(session, manager, script);
      if (result?.exitCode === 0) {
        knownRoot = String(result.stdout || '').trim();
        state.directories.set(key, knownRoot);
      }
    }
    if (knownRoot && state.repositories.get(knownRoot)?.tooSlow) {
      noteUntracked(session, call, 'repository_too_slow');
      return null;
    }
    const start = await readTree(session, manager, directory);
    if (start.notRepository) state.notRepositories.add(key);
    if (!start.tree) {
      noteUntracked(session, call, start.notRepository ? 'not_a_repository' : 'read_failed');
      return null;
    }
    state.directories.set(key, start.root);
    if (!state.repositories.has(start.root)) {
      state.repositories.set(start.root, { paths: new Map(), tooSlow: false });
      session.eventBus.publish({
        runId: session.runId,
        userId: session.userId,
        agentId: session.agentId,
        eventType: EVENT_TYPES.CHECKPOINT_CREATED,
        payload: { kind: 'workspace', duration_ms: Date.now() - started },
      });
    }
    const repository = state.repositories.get(start.root);
    if (repository.tooSlow) {
      noteUntracked(session, call, 'repository_too_slow');
      return null;
    }
    if (Date.now() - started > SLOW_READ_MS) repository.tooSlow = true;

    return { root: start.root, tree: start.tree, file: targetFile(call), call };
  } catch (error) {
    logger.warn('Could not read the workspace:', error?.message || error);
    noteUntracked(session, call, 'read_failed');
    return null;
  }
}

// Record advisory differences for repo_diff. The first snapshot is the baseline,
// not an ownership claim or authorization to restore the path.
async function recordMutation(session, mutation) {
  const manager = runner(session);
  if (!manager || !mutation) return [];
  try {
    const end = await readTree(session, manager, mutation.root);
    if (!end.tree) {
      noteUntracked(session, mutation.call, 'read_failed');
      return [];
    }
    if (end.tree === mutation.tree) return [];
    const diff = await run(session, manager, `${GIT_FUNCTION}\ncd ${shellQuote(mutation.root)} && g -c core.quotepath=off diff-tree -r --no-renames --raw ${shellQuote(mutation.tree)} ${shellQuote(end.tree)}`);
    // A file tool changes the one file it names. Anything else that moved in that
    // moment is someone else's.
    if (diff?.exitCode !== 0 || diff.truncated) {
      noteUntracked(session, mutation.call, diff?.truncated ? 'too_many_changes' : 'read_failed');
      return [];
    }
    const listed = parseRawDiff(diff.stdout);
    if (listed.some((change) => change.gitlink)) noteUntracked(session, mutation.call, 'submodule');
    const changes = listed
      .filter((change) => !change.gitlink)
      .filter((change) => !mutation.file || mutation.file === change.path || mutation.file.endsWith(`/${change.path}`));
    const { paths } = session.checkpoints.repositories.get(mutation.root);
    for (const change of changes) {
      const known = paths.get(change.path);
      paths.set(change.path, { source: known?.source ?? mutation.tree });
    }
    if (changes.length) {
      session.eventBus.publish({
        runId: session.runId,
        userId: session.userId,
        agentId: session.agentId,
        eventType: EVENT_TYPES.WORKSPACE_CHANGED,
        payload: { count: changes.length, paths: changes.slice(0, 50).map((change) => change.path) },
      });
    }
    return changes.map((change) => change.path);
  } catch (error) {
    logger.warn('Could not record what changed:', error?.message || error);
    noteUntracked(session, mutation.call, 'read_failed');
    return [];
  }
}

function changedPaths(session) {
  return [...(session?.checkpoints?.repositories?.values() || [])].flatMap((repository) => [...repository.paths.keys()]);
}

// A before/after tree cannot distinguish our writes from an external editor's,
// and a check followed by restore cannot atomically exclude an external write.
// Keep the public tool callable, but never guess or run destructive Git commands.
async function rollbackWorkspace() {
  return {
    success: false,
    error: 'Automatic workspace rollback is disabled: this shared workspace cannot prove exclusive ownership of changes. Inspect repo_diff and correct specific edits forward.',
  };
}

module.exports = {
  changedPaths,
  ensureCheckpoint,
  recordMutation,
  rollbackWorkspace,
};
