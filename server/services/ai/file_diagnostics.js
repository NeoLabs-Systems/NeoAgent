'use strict';

const path = require('path');
const { shellQuote } = require('../../utils/shell');

const DIAGNOSTICS_TIMEOUT_MS = 15000;
const MAX_OUTPUT_CHARS = 600;

// Syntax-only checks. None of these import or execute the file, so they are
// safe to run on anything the model just wrote. Exit code 1 means "the file
// is wrong"; anything else means the check itself could not run.
const PYTHON_SYNTAX_CHECK = [
  'import ast, sys',
  'p = sys.argv[1]',
  'try: ast.parse(open(p).read(), p)',
  "except SyntaxError as e: print(f\"{p}:{e.lineno}: {type(e).__name__}: {e.msg}\\n{(e.text or '').rstrip()}\", file=sys.stderr); sys.exit(1)",
  'except Exception: sys.exit(2)',
].join('\n');

const CHECKERS = {
  '.py': (file) => `python3 -c ${shellQuote(PYTHON_SYNTAX_CHECK)} ${file}`,
  '.js': (file) => `node --check ${file}`,
  '.cjs': (file) => `node --check ${file}`,
  '.mjs': (file) => `node --check ${file}`,
};

function diagnosticsCommand(filePath) {
  const checker = CHECKERS[path.posix.extname(String(filePath || '')).toLowerCase()];
  return checker ? checker(shellQuote(filePath)) : null;
}

// Returns `{ ok: false, output }` when the checker rejected the file, or null
// when there is nothing to report: unsupported file type, no runtime, or the
// checker itself could not run (missing interpreter, timeout).
async function runFileDiagnostics(runtimeManager, userId, filePath, options = {}) {
  const command = diagnosticsCommand(filePath);
  if (!command || typeof runtimeManager?.executeCliCommand !== 'function') return null;
  let result;
  try {
    result = await runtimeManager.executeCliCommand(userId, command, {
      timeout: DIAGNOSTICS_TIMEOUT_MS,
      signal: options.signal,
      deviceTarget: options.deviceTarget,
    });
  } catch {
    return null;
  }
  if (result?.exitCode !== 1) return null;
  const output = String(result.stderr || result.stdout || '').trim().slice(-MAX_OUTPUT_CHARS);
  return output ? { ok: false, output } : null;
}

module.exports = { diagnosticsCommand, runFileDiagnostics };
