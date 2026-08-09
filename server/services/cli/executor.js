const { spawn, execFileSync } = require('child_process');
const { CommandOutputAccumulator } = require('./output_accumulator');

let _cachedLoginPath = null;
const DEFAULT_TIMEOUT_MS = 15 * 60 * 1000;
const DEFAULT_INTERACTIVE_TIMEOUT_MS = 20 * 60 * 1000;
const FORCE_KILL_GRACE_MS = 5000;

function abortedResult(command, cwd, startedAt = Date.now()) {
  return {
    exitCode: null,
    stdout: '',
    stderr: 'Command aborted before it started.',
    stdoutBytes: 0,
    stderrBytes: Buffer.byteLength('Command aborted before it started.'),
    truncated: false,
    killed: true,
    timedOut: false,
    aborted: true,
    signal: null,
    durationMs: Date.now() - startedAt,
    pid: null,
    command,
    cwd,
  };
}

function windowsShellCandidates() {
  if (process.platform !== 'win32') return [];
  const programFiles = process.env['ProgramFiles'] || 'C:\\Program Files';
  const programFilesX86 = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
  const systemRoot = process.env.SystemRoot || 'C:\\Windows';
  return [
    process.env.SHELL,
    `${programFiles}\\Git\\bin\\bash.exe`,
    `${programFiles}\\Git\\usr\\bin\\bash.exe`,
    `${programFilesX86}\\Git\\bin\\bash.exe`,
    `${systemRoot}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe`,
    `${systemRoot}\\System32\\cmd.exe`,
    'bash.exe',
    'powershell.exe',
    'cmd.exe',
  ].filter(Boolean);
}

function isWindowsCmd(shellPath) {
  return /(?:^|[\\/])cmd(?:\.exe)?$/i.test(String(shellPath || ''));
}

function isWindowsPowerShell(shellPath) {
  return /(?:^|[\\/])powershell(?:\.exe)?$/i.test(String(shellPath || ''));
}

function isPosixShell(shellPath) {
  return !isWindowsCmd(shellPath) && !isWindowsPowerShell(shellPath);
}

function shellProbeArgs(shellPath) {
  if (isWindowsCmd(shellPath)) return ['/d', '/s', '/c', 'echo ok'];
  if (isWindowsPowerShell(shellPath)) return ['-NoProfile', '-Command', "Write-Output 'ok'"];
  return ['-lc', 'printf ok'];
}

function shellExecArgs(shellPath, command) {
  if (isWindowsCmd(shellPath)) return ['/d', '/s', '/c', command];
  if (isWindowsPowerShell(shellPath)) return ['-NoProfile', '-Command', command];
  // Git Bash and other POSIX shells on Windows also accept -lc.
  return ['-l', '-c', command];
}

function resolveDefaultShell() {
  const candidates = [
    process.env.SHELL,
    '/bin/zsh',
    '/bin/bash',
    '/bin/sh',
    ...windowsShellCandidates(),
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      execFileSync(candidate, shellProbeArgs(candidate), {
        timeout: 3000,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      return candidate;
    } catch {}
  }

  console.warn('[CLI] No usable shell found for executor');
  return null;
}

function clampTimeout(value, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.floor(parsed);
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

function terminateWithEscalation(proc, isActive) {
  terminateProcess(proc, 'SIGTERM');
  if (proc.__neoagentForceKillTimer) return;
  proc.__neoagentForceKillTimer = setTimeout(() => {
    if (isActive()) terminateProcess(proc, 'SIGKILL');
  }, FORCE_KILL_GRACE_MS);
  proc.__neoagentForceKillTimer.unref?.();
}

function clearForceKill(proc) {
  if (proc?.__neoagentForceKillTimer) {
    clearTimeout(proc.__neoagentForceKillTimer);
    proc.__neoagentForceKillTimer = null;
  }
}

function shellSupportsPipefail(shellPath) {
  const normalized = String(shellPath || '').trim().toLowerCase();
  return /(?:^|\/)(?:bash|zsh|ksh|mksh|yash)$/.test(normalized);
}

function wrapCommandForShell(command, shellPath) {
  if (!shellSupportsPipefail(shellPath)) {
    return command;
  }
  return `set -o pipefail; ${command}`;
}

class CLIExecutor {
  constructor() {
    this.activeProcesses = new Map();
    this.defaultShell = resolveDefaultShell();
    if (!this.defaultShell) {
      throw new Error('No usable shell found for CLI execution.');
    }
  }

  _getLoginPath() {
    if (_cachedLoginPath) return _cachedLoginPath;
    try {
      const pathCommand = isPosixShell(this.defaultShell)
        ? 'echo $PATH'
        : isWindowsPowerShell(this.defaultShell)
          ? 'Write-Output $env:PATH'
          : 'echo %PATH%';
      const raw = execFileSync(this.defaultShell, shellExecArgs(this.defaultShell, pathCommand), {
        timeout: 5000,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      _cachedLoginPath = raw.trim();
    } catch {
      _cachedLoginPath = process.env.PATH
        || (process.platform === 'win32'
          ? `${process.env.SystemRoot || 'C:\\Windows'}\\System32`
          : '/usr/local/bin:/usr/bin:/bin');
    }
    return _cachedLoginPath;
  }

  _buildEnv(extra = {}) {
    const loginPath = this._getLoginPath();
    const delimiter = process.platform === 'win32' ? ';' : ':';
    const current = (process.env.PATH || '').split(delimiter);
    const login = loginPath.split(delimiter);
    const merged = [...new Set([...login, ...current].filter(Boolean))].join(delimiter);
    return { ...process.env, PATH: merged, ...extra };
  }

  async execute(command, options = {}) {
    const cwd = options.cwd || process.env.HOME;
    const timeout = clampTimeout(options.timeout, DEFAULT_TIMEOUT_MS);
    const stdinInput = options.stdinInput;
    if (options.signal?.aborted) return abortedResult(command, cwd);

    return new Promise((resolve) => {
      const output = new CommandOutputAccumulator();
      let killed = false;
      let timedOut = false;
      const startedAt = Date.now();
      const wrappedCommand = wrapCommandForShell(command, this.defaultShell);

      const proc = spawn(this.defaultShell, shellExecArgs(this.defaultShell, wrappedCommand), {
        cwd: cwd || process.cwd(),
        detached: process.platform !== 'win32',
        env: this._buildEnv(options.env),
        stdio: ['pipe', 'pipe', 'pipe']
      });
      proc.__neoagentDetached = process.platform !== 'win32';

      const pid = proc.pid;
      this.activeProcesses.set(pid, proc);
      options.onSpawn?.(pid);
      const onAbort = () => {
        killed = true;
        proc.__neoagentKilled = true;
        proc.__neoagentKillReason = 'aborted';
        terminateWithEscalation(proc, () => this.activeProcesses.get(pid) === proc);
      };
      options.signal?.addEventListener('abort', onAbort, { once: true });

      proc.stdout.on('data', (data) => {
        output.append('stdout', data);
      });

      proc.stderr.on('data', (data) => {
        output.append('stderr', data);
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
        terminateWithEscalation(proc, () => this.activeProcesses.get(pid) === proc);
      }, timeout);
      timer.unref?.();

      proc.on('close', (code, signal) => {
        clearTimeout(timer);
        clearForceKill(proc);
        options.signal?.removeEventListener('abort', onAbort);
        this.activeProcesses.delete(pid);
        const durationMs = Date.now() - startedAt;

        const outputResult = output.finalize();
        resolve({
          exitCode: typeof code === 'number' ? code : null,
          ...outputResult,
          killed: killed || proc.__neoagentKilled === true,
          timedOut: timedOut || proc.__neoagentKillReason === 'timeout',
          aborted: proc.__neoagentKillReason === 'aborted',
          signal: signal || null,
          durationMs,
          pid,
          command,
          cwd
        });
      });

      proc.on('error', (err) => {
        clearTimeout(timer);
        clearForceKill(proc);
        options.signal?.removeEventListener('abort', onAbort);
        this.activeProcesses.delete(pid);
        output.discard();
        resolve({
          exitCode: -1,
          stdout: '',
          stderr: err.message,
          stdoutBytes: 0,
          stderrBytes: Buffer.byteLength(err.message),
          truncated: false,
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
    if (options.signal?.aborted) return abortedResult(command, cwd);

    return new Promise((resolve) => {
      const output = new CommandOutputAccumulator({ stderrPreviewBytes: 50_000 });
      let inputWindow = '';
      let inputIndex = 0;
      let killed = false;
      let timedOut = false;
      const startedAt = Date.now();
      const wrappedCommand = wrapCommandForShell(command, this.defaultShell);

      let pty;
      try {
        pty = require('node-pty');
      } catch {
        output.discard();
        return this.execute(command, { ...options, stdinInput: inputs.join('\n') + '\n' }).then(resolve);
      }

      let proc;
      try {
        proc = pty.spawn(this.defaultShell, shellExecArgs(this.defaultShell, wrappedCommand), {
          name: 'xterm-256color',
          cols: 120,
          rows: 30,
          cwd: cwd || process.cwd(),
          env: { ...this._buildEnv(), TERM: 'xterm-256color' }
        });
      } catch (error) {
        output.discard();
        resolve({
          exitCode: -1,
          stdout: '',
          stderr: error.message,
          stdoutBytes: 0,
          stderrBytes: Buffer.byteLength(error.message),
          truncated: false,
          killed: false,
          timedOut: false,
          durationMs: Date.now() - startedAt,
          command,
          cwd,
          interactive: true,
          error: error.message,
        });
        return;
      }

      const pid = proc.pid;
      this.activeProcesses.set(pid, proc);
      options.onSpawn?.(pid);
      const onAbort = () => {
        killed = true;
        proc.__neoagentKilled = true;
        proc.__neoagentKillReason = 'aborted';
        terminateWithEscalation(proc, () => this.activeProcesses.get(pid) === proc);
      };
      options.signal?.addEventListener('abort', onAbort, { once: true });

      proc.onData((data) => {
        output.append('stdout', Buffer.from(data, 'utf8'));
        inputWindow = `${inputWindow}${data}`.slice(-20_000);

        if (inputIndex < inputs.length) {
          const inputItem = inputs[inputIndex];
          if (typeof inputItem === 'object' && inputItem.waitFor) {
            if (inputWindow.includes(inputItem.waitFor)) {
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
        terminateWithEscalation(proc, () => this.activeProcesses.get(pid) === proc);
      }, timeout);
      timer.unref?.();

      proc.onExit(({ exitCode, signal }) => {
        clearTimeout(timer);
        clearForceKill(proc);
        options.signal?.removeEventListener('abort', onAbort);
        this.activeProcesses.delete(pid);

        const outputResult = output.finalize();
        resolve({
          exitCode,
          ...outputResult,
          stdout: outputResult.stdout.replace(/\x1B\[[0-9;]*[a-zA-Z]/g, '').trim(),
          killed: killed || proc.__neoagentKilled === true,
          timedOut: timedOut || proc.__neoagentKillReason === 'timeout',
          aborted: proc.__neoagentKillReason === 'aborted',
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
      terminateWithEscalation(proc, () => this.activeProcesses.get(pid) === proc);
      return true;
    }
    return false;
  }

  isManaged(pid) {
    return this.activeProcesses.has(pid);
  }

  killAll(reason = 'aborted') {
    for (const [pid, proc] of this.activeProcesses) {
      proc.__neoagentKilled = true;
      proc.__neoagentKillReason = reason;
      terminateWithEscalation(proc, () => this.activeProcesses.get(pid) === proc);
    }
  }
}

module.exports = { CLIExecutor };
