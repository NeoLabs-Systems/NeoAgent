'use strict';

// Shell tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'execute_command',
    selection: 'default',
    resultShape: 'command',
    group: 'shell', access: 'dynamic_shell', sideEffect: 'workspace', stateScope: 'workspace', latencyClass: 'slow', repeatable: true,
    capabilities: ['shell', 'terminal', 'git', 'tests', 'build', 'packages', 'scripts'],
    prerequisites: ['computer'],
    policy: { category: 'shell' },
    description: 'Execute a terminal/shell command as a recoverable step inside the user\'s isolated cloud computer. The command shares the persistent workspace with browser, desktop, and file tools. Use it for git, builds, installs, and anything the coding tools do not cover, package managers, and shell-native work; prefer workspace file tools for direct file reads and edits. A timeout, signal, or non-zero exit is not success, and a chained command may have stopped before later segments ran.',
    parameters: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'The shell command to execute' },
        cwd: { type: 'string', description: 'Working directory (optional, default $HOME)' },
        timeout: { type: 'number', description: 'Maximum runtime in ms. Default 900000 (15 minutes); use longer values for installs, builds, or package managers.' },
        stdin_input: { type: 'string', description: 'Input to pipe to stdin' },
        pty: { type: 'boolean', description: 'Use PTY for interactive programs, progress UIs, or commands that need a real terminal (default false)' },
        inputs: { type: 'array', items: { type: 'string' }, description: 'Sequence of inputs for interactive PTY prompts' }
      },
      required: ['command']
    }
  },
];
