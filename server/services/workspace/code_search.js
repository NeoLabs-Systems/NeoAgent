'use strict';

const { shellQuote } = require('../../utils/shell');
const {
  commandError,
  enterScript,
  firstSection,
  locationError,
  parseSections,
  section,
  workspaceRelative,
} = require('./workspace_shell');

const DEFAULT_MAX_RESULTS = 50;
const MAX_RESULTS = 200;
const DEFAULT_PER_FILE = 15;
const MAX_CONTEXT = 5;
const MAX_LINE_CHARS = 160;
const MAX_OUTPUT_BYTES = 45_000;
const DEFAULT_MAX_FILE_BYTES = 1024 * 1024;
// grep has no idea what .gitignore says, so the usual generated trees are named.
const SKIPPED_DIRS = ['.git', 'node_modules', 'dist', 'build', 'coverage', '.next', '.cache', 'target', 'vendor', '__pycache__', '.venv', 'venv'];
// Dotfiles are searched, but a stray match should not put a secret in the transcript.
const SECRET_FILES = ['.env', '.env.*'];

function boundedInteger(value, fallback, min, max) {
  const number = Math.floor(Number(value));
  return Number.isFinite(number) ? Math.min(Math.max(number, min), max) : fallback;
}

function includeGlobs(include) {
  const list = Array.isArray(include) ? include : [include];
  return list.map((glob) => String(glob ?? '').trim()).filter(Boolean);
}

// grep's --include takes neither braces nor directories, so `src/*.{js,ts}` is
// narrowed to its file names there and the directories are checked afterwards.
function basenameGlobs(glob) {
  const last = glob.split('/').pop() || '*';
  const braces = /^(.*)\{([^{}]*)\}(.*)$/.exec(last);
  return braces ? braces[2].split(',').map((part) => `${braces[1]}${part}${braces[3]}`) : [last];
}

function globToRegExp(glob) {
  const pattern = glob.replace(/\*\*\/|\*\*|\*|\?|\{[^{}]*\}|[.+^$()|\\]/g, (token) => {
    if (token === '**/') return '(?:.*/)?';
    if (token === '**') return '.*';
    if (token === '*') return '[^/]*';
    if (token === '?') return '[^/]';
    if (token.startsWith('{')) return `(?:${token.slice(1, -1).split(',').map((part) => part.replace(/[.+^$()|\\]/g, '\\$&').replace(/\*/g, '[^/]*')).join('|')})`;
    return `\\${token}`;
  });
  return new RegExp(`^(?:.*/)?${pattern}$`);
}

function ripgrepCommand(options) {
  const flags = [
    '--no-config', '--color=never', '--no-heading', '--with-filename', '--line-number', '--null',
    '--hidden', '--sort=path', '--max-columns=400', '--max-columns-preview',
    `--max-filesize=${options.maxFileBytes}`, '--max-count="$neo_per"',
    options.regex ? '' : '--fixed-strings',
    options.ignoreCase ? '--ignore-case' : '--case-sensitive',
    options.context ? `--context=${options.context}` : '',
    options.maxDepth ? `--max-depth=${options.maxDepth}` : '',
  ].filter(Boolean);
  const globs = [
    '!.git',
    ...SECRET_FILES.map((name) => `!${name}`),
    ...(options.inGenerated ? [] : ['!node_modules']),
    ...options.include,
  ];
  const args = globs.map((glob) => `--glob ${shellQuote(glob)}`);
  return `rg ${flags.join(' ')} ${args.join(' ')} -e ${shellQuote(options.query)} -- "$neo_name"`;
}

function grepCommand(options) {
  const flags = [
    '-rnIH', '--null', '--color=never', '-m "$neo_per"',
    options.regex ? '-E' : '-F',
    options.ignoreCase ? '-i' : '',
    options.context ? `-C ${options.context}` : '',
  ].filter(Boolean);
  // --include must come before any --exclude/--exclude-dir: GNU grep silently
  // drops the include restriction when an exclude option precedes it, so
  // `--exclude='.env' --include='*.ts'` searches every file.
  const includes = options.include.flatMap(basenameGlobs).map((name) => `--include=${shellQuote(name)}`);
  const excludes = [
    ...SKIPPED_DIRS.map((name) => `--exclude-dir=${shellQuote(name)}`),
    ...SECRET_FILES.map((name) => `--exclude=${shellQuote(name)}`),
  ];
  return `grep ${flags.join(' ')} ${includes.join(' ')} ${excludes.join(' ')} -e ${shellQuote(options.query)} -- "$neo_name"`;
}

// Everything is written to a file first: rg's exit code has to survive, and sh has
// no pipefail. What reaches stdout is then cut by width and by size.
function searchScript(options) {
  return [
    ...enterScript(options.target),
    // One file is read as far as the caller asked; across a tree, no file may crowd out the rest.
    `neo_per=${DEFAULT_PER_FILE}`,
    `[ "$neo_name" = . ] || neo_per=${options.maxResults + 1}`,
    `${section('directory')}; printf '%s\n' "$neo_dir"`,
    'neo_tmp=$(mktemp -d) || exit 1',
    'trap \'rm -rf "$neo_tmp"\' EXIT',
    'if command -v rg >/dev/null 2>&1; then',
    `  ${section('engine')}; echo rg`,
    `  ${ripgrepCommand(options)} >"$neo_tmp/out" 2>"$neo_tmp/err"`,
    'else',
    `  ${section('engine')}; echo grep`,
    `  ${grepCommand(options)} >"$neo_tmp/out" 2>"$neo_tmp/err"`,
    'fi',
    'neo_code=$?',
    `${section('exit')}; echo "$neo_code"`,
    `${section('size')}; wc -c <"$neo_tmp/out"`,
    `${section('stderr')}; head -c 400 "$neo_tmp/err"; echo`,
    `${section('matches')}; LC_ALL=C cut -b 1-700 "$neo_tmp/out" | head -c ${MAX_OUTPUT_BYTES}`,
  ].join('\n');
}

function cleanRelative(base, name) {
  return base === '.' ? name : `${base.replace(/\/+$/, '')}/${name}`;
}

function outputLine(raw, base) {
  const separator = raw.indexOf('\0');
  if (separator < 0) return null;
  const match = /^(\d+)([:-])(.*)$/s.exec(raw.slice(separator + 1));
  if (!match) return null;
  const name = raw.slice(0, separator).replace(/^\.\//, '');
  return {
    file: cleanRelative(base, name),
    depth: name.split('/').length,
    line: Number(match[1]),
    isMatch: match[2] === ':',
    content: match[3].trimEnd().slice(0, MAX_LINE_CHARS),
  };
}

// One flat list so it survives compactToolResult, in file order. A file's name
// appears on its first entry only, and context lines read like grep's: "13-".
function groupMatches(lines, maxResults) {
  const byFile = new Map();
  for (const line of lines) {
    if (!byFile.has(line.file)) byFile.set(line.file, []);
    byFile.get(line.file).push(line);
  }
  const matches = [];
  let shown = 0;
  let total = 0;
  for (const [file, entries] of byFile) {
    let named = false;
    for (const entry of entries) {
      if (entry.isMatch) total += 1;
      if (shown >= maxResults) continue;
      if (entry.isMatch) shown += 1;
      matches.push({
        ...(named ? {} : { file }),
        line: entry.isMatch ? entry.line : `${entry.line}-`,
        content: entry.content,
      });
      named = true;
    }
  }
  return { matches, shown, total, files: byFile.size };
}

function emptyResultNote(options) {
  if (!options.regex && /[|\\^$]|\.\*|\(.*\)|\[.*\]/.test(options.query)) {
    return 'No matches for this exact text. If it was meant as a pattern, set regex to true.';
  }
  return 'No matches. Ignored and generated files are not searched.';
}

async function searchWorkspace(shell, args = {}) {
  const query = String(args.query ?? '');
  if (!query.trim()) return { error: 'search_files requires a query.', count: 0, matches: [] };
  if (/[\r\n]/.test(query)) return { error: 'query must be a single line.', count: 0, matches: [] };

  const maxResults = boundedInteger(args.max_results ?? args.maxResults, DEFAULT_MAX_RESULTS, 1, MAX_RESULTS);
  const include = includeGlobs(args.include);
  const options = {
    query,
    target: args.path,
    maxResults,
    regex: args.regex === true,
    // Lower case searches loosely, as rg's smart case does; a capital means it.
    ignoreCase: typeof args.case_sensitive === 'boolean' ? !args.case_sensitive : !/[A-Z]/.test(query),
    context: boundedInteger(args.context, 0, 0, MAX_CONTEXT),
    maxDepth: boundedInteger(args.maxDepth ?? args.max_depth, 0, 0, 32),
    maxFileBytes: boundedInteger(args.maxFileSize ?? args.max_file_size, DEFAULT_MAX_FILE_BYTES, 1, 64 * 1024 * 1024),
    inGenerated: /(^|\/)node_modules(\/|$)/.test(workspaceRelative(args.path)),
    include,
  };

  const result = await shell.run(searchScript(options));
  const failure = commandError(result);
  if (failure) return { error: failure, count: 0, matches: [] };
  const sections = parseSections(result.stdout);
  const location = locationError(sections, args.path);
  if (location) return { error: location, count: 0, matches: [] };

  const exitCode = Number(firstSection(sections, 'exit')?.lines[0]);
  const stderr = (firstSection(sections, 'stderr')?.lines || []).join(' ').trim();
  const body = firstSection(sections, 'matches')?.lines || [];
  const engine = firstSection(sections, 'engine')?.lines[0];
  const pathFilters = engine === 'grep' ? include.filter((glob) => glob.includes('/')).map(globToRegExp) : [];
  const directory = firstSection(sections, 'directory')?.lines[0] || '.';
  // grep cannot apply these itself.
  const lines = body
    .map((raw) => outputLine(raw, directory))
    .filter(Boolean)
    .filter((line) => !pathFilters.length || pathFilters.some((filter) => filter.test(line.file)))
    .filter((line) => engine !== 'grep' || !options.maxDepth || line.depth <= options.maxDepth);
  if (!lines.length && exitCode > 1) {
    return { error: stderr || `search failed with exit code ${exitCode}`, count: 0, matches: [] };
  }

  const { matches, shown, total, files } = groupMatches(lines, maxResults);
  const cut = Number(firstSection(sections, 'size')?.lines[0]) > MAX_OUTPUT_BYTES;
  return {
    count: total,
    files,
    matches,
    truncated: cut || total > shown,
    engine,
    ...(total === 0 ? { note: emptyResultNote(options) } : {}),
  };
}

module.exports = { searchWorkspace };
