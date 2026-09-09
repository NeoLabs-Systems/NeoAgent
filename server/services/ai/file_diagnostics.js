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

// Line numbers move when unrelated lines are edited; the error itself is what
// identifies a repeat.
function errorSignature(output) {
  return output.replace(/\d+/g, '#');
}

// Returns `{ ok: false, output }` when the checker rejected the file, or null
// when there is nothing to report: unsupported file type, no runtime, or the
// checker itself could not run (missing interpreter, timeout).
//
// `options.history` is the caller's per-run memory of the last verdict per
// file. With it, an edit that leaves the same error in place is called out as
// such — a model patching the same line over and over needs to be told the
// patches are not working, not handed the same message as if it were new.
async function runFileDiagnostics(runtimeManager, userId, filePath, options = {}) {
  const command = diagnosticsCommand(filePath);
  if (!command || typeof runtimeManager?.executeCliCommand !== 'function') return null;
  const history = options.history && typeof options.history === 'object' ? options.history : null;
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
  const output = result?.exitCode === 1
    ? String(result.stderr || result.stdout || '').trim().slice(-MAX_OUTPUT_CHARS)
    : '';
  if (!output) {
    if (history) delete history[filePath];
    return null;
  }
  let repeats = 1;
  if (history) {
    const signature = errorSignature(output);
    repeats = history[filePath]?.signature === signature ? history[filePath].repeats + 1 : 1;
    history[filePath] = { signature, repeats };
  }
  if (repeats === 1) return { ok: false, output };
  return {
    ok: false,
    output,
    note: `This is the same error as after the previous ${repeats - 1} edit(s); those edits did not address it. Rewrite the affected block or the whole file with write_file instead of patching again.`,
  };
}

module.exports = { diagnosticsCommand, runFileDiagnostics };
