const { spawn, execFileSync } = require('child_process');

let _cachedLoginPath = null;
const DEFAULT_TIMEOUT_MS = 15 * 60 * 1000;
const DEFAULT_INTERACTIVE_TIMEOUT_MS = 20 * 60 * 1000;
const FORCE_KILL_GRACE_MS = 5000;
const MAX_STDOUT_CHARS = 50000;
const MAX_STDERR_CHARS = 10000;

function clampTimeout(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
}

function truncateOutput(str, max) {
  if (str.length > max) return str.slice(0, max) + `\n...[truncated, ${str.length} total chars]`;
  return str;
}

function terminateProcess(proc, signal = 'SIGTERM') {
  if (!proc) return;
  if (proc.__neoagentDetached && typeof proc.pid === 'number' && process.platform !== 'win32') {
    try {
      process.kill(-proc.pid, signal);
      return;
    } catch {
      // Fall back to direct kill below.
    }
  }
  proc.kill?.(signal) || proc.kill?.();
}

class CLIExecutor {
  constructor() {
    this.activeProcesses = new Map();
    this.defaultShell = process.env.SHELL || '/bin/zsh';
  }

  _getLoginPath() {
    if (_cachedLoginPath) return _cachedLoginPath;
    try {
      const raw = execFileSync(this.defaultShell, ['-l', '-c', 'echo $PATH'], {
        timeout: 5000,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      _cachedLoginPath = raw.trim();
    } catch {
      _cachedLoginPath = process.env.PATH || '/usr/local/bin:/usr/bin:/bin';
    }
    return _cachedLoginPath;
  }

  _buildEnv(extra = {}) {
    const loginPath = this._getLoginPath();
    const current = (process.env.PATH || '').split(':');
    const login = loginPath.split(':');
    const merged = [...new Set([...login, ...current])].join(':');
    return { ...process.env, PATH: merged, ...extra };
  }

  async execute(command, options = {}) {
    const cwd = options.cwd || process.env.HOME;
    const timeout = clampTimeout(options.timeout, DEFAULT_TIMEOUT_MS);
    const stdinInput = options.stdinInput;

    return new Promise((resolve) => {
      let stdout = '';
      let stderr = '';
      let killed = false;
      let timedOut = false;
      const startedAt = Date.now();

      const proc = spawn(this.defaultShell, ['-l', '-c', command], {
        cwd,
        detached: process.platform !== 'win32',
        env: this._buildEnv(options.env),
        stdio: ['pipe', 'pipe', 'pipe']
      });
      proc.__neoagentDetached = process.platform !== 'win32';

      const pid = proc.pid;
      this.activeProcesses.set(pid, proc);
      options.onSpawn?.(pid);

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
        timedOut = true;
        proc.__neoagentKilled = true;
        proc.__neoagentKillReason = 'timeout';
        terminateProcess(proc, 'SIGTERM');
        setTimeout(() => {
          if (!proc.killed) terminateProcess(proc, 'SIGKILL');
        }, FORCE_KILL_GRACE_MS);
      }, timeout);

      proc.on('close', (code, signal) => {
        clearTimeout(timer);
        this.activeProcesses.delete(pid);
        const durationMs = Date.now() - startedAt;

        resolve({
          exitCode: typeof code === 'number' ? code : null,
          stdout: truncateOutput(stdout.trim(), MAX_STDOUT_CHARS),
          stderr: truncateOutput(stderr.trim(), MAX_STDERR_CHARS),
          killed: killed || proc.__neoagentKilled === true,
          timedOut: timedOut || proc.__neoagentKillReason === 'timeout',
          signal: signal || null,
          durationMs,
          pid,
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
          timedOut: false,
          signal: null,
          durationMs: Date.now() - startedAt,
          pid,
          command,
          cwd,
          error: err.message
        });
      });
    });
  }

  async executeInteractive(command, inputs = [], options = {}) {
    const cwd = options.cwd || process.env.HOME;
    const timeout = clampTimeout(options.timeout, DEFAULT_INTERACTIVE_TIMEOUT_MS);

    return new Promise((resolve) => {
      let output = '';
      let inputIndex = 0;
      let killed = false;
      let timedOut = false;
      const startedAt = Date.now();

      let pty;
      try {
        pty = require('node-pty');
      } catch {
        return this.execute(command, { ...options, stdinInput: inputs.join('\n') + '\n' }).then(resolve);
      }

      const proc = pty.spawn(this.defaultShell, ['-l', '-c', command], {
        name: 'xterm-256color',
        cols: 120,
        rows: 30,
        cwd,
        env: { ...this._buildEnv(), TERM: 'xterm-256color' }
      });

      const pid = proc.pid;
      this.activeProcesses.set(pid, proc);
      options.onSpawn?.(pid);

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
        timedOut = true;
        proc.__neoagentKilled = true;
        proc.__neoagentKillReason = 'timeout';
        proc.kill();
      }, timeout);

      proc.onExit(({ exitCode, signal }) => {
        clearTimeout(timer);
        this.activeProcesses.delete(pid);

        const cleanOutput = output.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '').trim();
        resolve({
          exitCode,
          stdout: truncateOutput(cleanOutput, MAX_STDOUT_CHARS),
          stderr: '',
          killed: killed || proc.__neoagentKilled === true,
          timedOut: timedOut || proc.__neoagentKillReason === 'timeout',
          signal: typeof signal === 'number' ? String(signal) : signal || null,
          durationMs: Date.now() - startedAt,
          pid,
          command,
          cwd,
          interactive: true
        });
      });
    });
  }

  kill(pid, reason = 'aborted') {
    const proc = this.activeProcesses.get(pid);
    if (proc) {
      proc.__neoagentKilled = true;
      proc.__neoagentKillReason = reason;
      terminateProcess(proc, 'SIGTERM');
      this.activeProcesses.delete(pid);
      return true;
    }
    return false;
  }

  killAll(reason = 'aborted') {
    for (const [pid, proc] of this.activeProcesses) {
      proc.__neoagentKilled = true;
      proc.__neoagentKillReason = reason;
      terminateProcess(proc, 'SIGTERM');
    }
    this.activeProcesses.clear();
  }
}

module.exports = { CLIExecutor };
