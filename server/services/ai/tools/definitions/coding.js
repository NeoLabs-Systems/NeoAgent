'use strict';

// Coding tools: what a run needs to understand a repository and check its own work
// without going through the shell. Reading a file, searching, and editing are file
// tools; these are the ones that need git or a test runner.

module.exports = [
  {
    name: 'repo_overview',
    selection: 'coding',
    resultShape: 'bounded',
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['repo', 'overview', 'git', 'code', 'tests'],
    prerequisites: ['computer'],
    whenToUse: ['first look at a repository, instead of ls, git status, and cat package.json'],
    description: 'One compact view of a repository: root, branch, dirty files, top-level layout, languages, manifests, docs, and how to run its tests.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Repository directory (default the workspace root)' },
      },
      required: [],
    },
  },
  {
    name: 'repo_diff',
    selection: 'coding',
    resultShape: 'bounded',
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['repo', 'diff', 'git', 'status', 'review'],
    prerequisites: ['computer'],
    whenToUse: ['review what you changed, instead of git status and git diff'],
    description: 'Changed files and a bounded diff, including new files. By default uses snapshots around this run\'s calls; concurrent external writes may be included. Does not modify workspace files or the Git index.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Repository directory, when the run has no changes recorded or scope is not run (default the workspace root)' },
        scope: { type: 'string', enum: ['run', 'uncommitted'], description: 'run: this run\'s changes (default). uncommitted: everything since HEAD.' },
        base: { type: 'string', description: 'Compare with where this ref branched off instead, such as "main"' },
        paths: { type: 'array', items: { type: 'string' }, description: 'Only these files or directories; gives each more room' },
        max_chars: { type: 'number', description: 'Diff size limit (default 12000, max 30000)' },
      },
      required: [],
    },
  },
  {
    name: 'run_tests',
    selection: 'coding',
    resultShape: 'bounded',
    group: 'shell', access: 'write', sideEffect: 'workspace', stateScope: 'workspace', latencyClass: 'slow', repeatable: true,
    capabilities: ['tests', 'verify', 'ci', 'failures'],
    prerequisites: ['computer'],
    // A test run executes the project's code and any command given, as the shell does.
    policy: { category: 'shell' },
    whenToUse: ['run or re-run tests, instead of execute_command'],
    description: 'Run the project\'s tests, detecting the runner or using your command. Returns the counts and only the failures, with the full log in log_artifact_id for read_artifact.',
    parameters: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'Test command, such as "node --test test/a.test.js". Omit to detect it.' },
        cwd: { type: 'string', description: 'Project directory (default the workspace root)' },
        timeout: { type: 'number', description: 'Maximum runtime in ms (default 600000, max 1800000)' },
      },
      required: [],
    },
  },
];
