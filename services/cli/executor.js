const { spawn } = require('child_process');
const path = require('path');

class CLIExecutor {
  constructor() {
    this.activeProcesses = new Map();
    this.defaultShell = process.env.SHELL || '/bin/zsh';
  }

  async execute(command, options = {}) {
    const cwd = options.cwd || process.env.HOME;
    const timeout = options.timeout || 60000;
    const stdinInput = options.stdinInput;

    return new Promise((resolve) => {
      let stdout = '';
      let stderr = '';
      let killed = false;

      const proc = spawn(this.defaultShell, ['-c', command], {
        cwd,
        env: { ...process.env, ...(options.env || {}) },
        timeout,
        stdio: ['pipe', 'pipe', 'pipe']
      });

      const pid = proc.pid;
      this.activeProcesses.set(pid, proc);

      proc.stdout.on('data', (data) => {
        stdout += data.toString();
        if (stdout.length > 500000) {
          stdout = stdout.slice(-250000);
        }
      });

      proc.stderr.on('data', (data) => {
        stderr += data.toString();
        if (stderr.length > 100000) {
          stderr = stderr.slice(-50000);
        }
      });

      if (stdinInput) {
        proc.stdin.write(stdinInput);
        proc.stdin.end();
      }

      const timer = setTimeout(() => {
        killed = true;
        proc.kill('SIGTERM');
        setTimeout(() => {
          if (!proc.killed) proc.kill('SIGKILL');
        }, 5000);
      }, timeout);

      proc.on('close', (code) => {
        clearTimeout(timer);
        this.activeProcesses.delete(pid);

        const truncate = (str, max) => {
          if (str.length > max) return str.slice(0, max) + `\n...[truncated, ${str.length} total chars]`;
          return str;
        };

        resolve({
          exitCode: code,
          stdout: truncate(stdout.trim(), 50000),
          stderr: truncate(stderr.trim(), 10000),
          killed,
          command,
          cwd
        });
      });

      proc.on('error', (err) => {
        clearTimeout(timer);
        this.activeProcesses.delete(pid);
        resolve({
          exitCode: -1,
          stdout: '',
          stderr: err.message,
          killed: false,
          command,
          cwd,
          error: err.message
        });
      });
    });
  }

  async executeInteractive(command, inputs = [], options = {}) {
    const cwd = options.cwd || process.env.HOME;
    const timeout = options.timeout || 120000;

    return new Promise((resolve) => {
      let output = '';
      let inputIndex = 0;
      let killed = false;

      let pty;
      try {
        pty = require('node-pty');
      } catch {
        return this.execute(command, { ...options, stdinInput: inputs.join('\n') + '\n' }).then(resolve);
      }

      const proc = pty.spawn(this.defaultShell, ['-c', command], {
        name: 'xterm-256color',
        cols: 120,
        rows: 30,
        cwd,
        env: { ...process.env, TERM: 'xterm-256color' }
      });

      const pid = proc.pid;
      this.activeProcesses.set(pid, proc);

      proc.onData((data) => {
        output += data;

        if (inputIndex < inputs.length) {
          const inputItem = inputs[inputIndex];
          if (typeof inputItem === 'object' && inputItem.waitFor) {
            if (output.includes(inputItem.waitFor)) {
              proc.write(inputItem.input + '\r');
              inputIndex++;
            }
          } else {
            setTimeout(() => {
              proc.write(inputItem + '\r');
              inputIndex++;
            }, 200);
          }
        }
      });

      const timer = setTimeout(() => {
        killed = true;
        proc.kill();
      }, timeout);

      proc.onExit(({ exitCode }) => {
        clearTimeout(timer);
        this.activeProcesses.delete(pid);

        const cleanOutput = output.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '').trim();
        resolve({
          exitCode,
          stdout: cleanOutput.slice(0, 50000),
          stderr: '',
          killed,
          command,
          cwd,
          interactive: true
        });
      });
    });
  }

  kill(pid) {
    const proc = this.activeProcesses.get(pid);
    if (proc) {
      proc.kill?.('SIGTERM') || proc.kill?.();
      this.activeProcesses.delete(pid);
      return true;
    }
    return false;
  }

  killAll() {
    for (const [pid, proc] of this.activeProcesses) {
      proc.kill?.('SIGTERM') || proc.kill?.();
    }
    this.activeProcesses.clear();
  }
}

module.exports = { CLIExecutor };
