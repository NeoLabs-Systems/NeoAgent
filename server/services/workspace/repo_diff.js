'use strict';

const { shellQuote } = require('../../utils/shell');
const { snapshotLines } = require('./git_snapshot');
const {
  GIT_FUNCTION,
  commandError,
  enterScript,
  firstSection,
  locationError,
  parseSections,
  section,
  sectionLines,
  workspaceRelative,
} = require('./workspace_shell');

const DEFAULT_MAX_CHARS = 12_000;
const MAX_CHARS = 30_000;
const MAX_LISTED_FILES = 100;
const MAX_DIFFED_FILES = 40;
const MAX_RUN_PATHS = 500;
// What one command may print: a command's stdout is only kept whole below 50 KB.
const MAX_SCRIPT_BYTES = 45_000;
const GIT_DIFF = 'g --literal-pathspecs diff --no-ext-diff --no-textconv --no-color --no-renames';


function enterRepositoryLines(target, enterOptions) {
  return [
    ...enterScript(target, enterOptions),
    GIT_FUNCTION,
    `g rev-parse --is-inside-work-tree >/dev/null 2>&1 || { ${section('not-repo')}; exit 0; }`,
    'neo_top=$(g rev-parse --show-toplevel)',
    ...(enterOptions?.anywhere ? [] : [`case "$neo_top/" in "$neo_root"/*) ;; *) ${section('outside')}; exit 0 ;; esac`]),
    'cd "$neo_top" || exit 1',
    `${section('root')}; printf '%s\\n' "$neo_top"`,
    `${section('branch')}; g symbolic-ref --short -q HEAD || g rev-parse --short HEAD 2>/dev/null || echo '(no commits)'`,
  ];
}

// The base is either the shell's own $neo_base or a tree id the run recorded; anything
// else is refused rather than placed in the script.
function listingLines(baseExpression, paths = []) {
  const base = baseExpression === '$neo_base' ? '"$neo_base"' : shellQuote(baseExpression);
  if (base !== '"$neo_base"' && !/^[0-9a-f]{40,64}$/.test(baseExpression)) {
    throw new Error('A recorded snapshot is not a tree id.');
  }
  const pathspec = paths.length ? ` -- ${paths.map(shellQuote).join(' ')}` : '';
  return [
    `printf '%s\\n' "@@neoagent:listing "${base}`,
    `${GIT_DIFF} --raw --numstat ${base} "$neo_now"${pathspec} | head -n ${MAX_LISTED_FILES * 2}`,
  ];
}

// Unusual names come back quoted: they stay listed, but are not diffed.
function parseListing(lines, base) {
  const files = new Map();
  const entry = (name) => {
    if (!files.has(name)) files.set(name, { path: name, base });
    return files.get(name);
  };
  for (const line of lines) {
    const raw = /^:(\d+) (\d+) \S+ \S+ (\w)\S*\t(.+)$/.exec(line);
    if (raw) {
      const file = entry(raw[4]);
      file.status = raw[3];
      if (raw[1] !== raw[2] && raw[1] !== '000000' && raw[2] !== '000000') file.modeChange = `${raw[1]} -> ${raw[2]}`;
      continue;
    }
    const numstat = /^(\d+|-)\t(\d+|-)\t(.+)$/.exec(line);
    if (numstat) {
      const file = entry(numstat[3]);
      file.binary = numstat[1] === '-';
      file.added = Number(numstat[1]) || 0;
      file.removed = Number(numstat[2]) || 0;
    }
  }
  return [...files.values()];
}

function listedFiles(sections) {
  return sections
    .filter((entry) => entry.name.startsWith('listing '))
    .flatMap((entry) => parseListing(entry.lines, entry.name.slice('listing '.length)));
}

function pathFilters(paths, root) {
  const prefix = `${workspaceRelative(root).replace(/\/+$/, '')}/`;
  const list = Array.isArray(paths) ? paths : [paths];
  return list
    .filter((entry) => typeof entry === 'string' && entry.trim())
    .map((entry) => workspaceRelative(entry).replace(/^\.\//, '').replace(/\/+$/, ''))
    .map((entry) => (entry.startsWith(prefix) ? entry.slice(prefix.length) : entry));
}

function matchesFilters(file, filters) {
  return !filters.length || filters.some((filter) => file === filter
    || file.startsWith(`${filter}/`)
    || filter.endsWith(`/${file}`));
}

function fileLine(file) {
  const counts = file.binary ? 'binary' : `+${file.added} -${file.removed}`;
  return `${file.status || '?'} ${file.path} ${counts}${file.modeChange ? ` mode ${file.modeChange}` : ''}`;
}

function diffScript(root, now, files, capBytes) {
  return [
    `CDPATH= cd -- ${shellQuote(root)} || exit 1`,
    GIT_FUNCTION,
    ...files.flatMap((file, index) => [
      section(`file ${index}`),
      `${GIT_DIFF} --unified=2 ${shellQuote(file.base)} ${shellQuote(now)} -- ${shellQuote(file.path)} | head -c ${capBytes}`,
      'echo',
    ]),
  ].join('\n');
}

// The per-file header says what `diff --git`, `index`, `---`, and `+++` would.
function hunksOnly(lines) {
  const start = lines.findIndex((line) => line.startsWith('@@'));
  return start < 0 ? '' : lines.slice(start).join('\n').trimEnd();
}

// Small files are shown whole; what is left is shared among the large ones, so one
// generated file cannot crowd out the change that matters.
function shareBudget(entries, maxChars) {
  const headers = entries.reduce((sum, entry) => sum + entry.header.length + 1, 0);
  let remaining = Math.max(0, maxChars - headers);
  let left = entries.length;
  for (const entry of [...entries].sort((a, b) => a.body.length - b.body.length)) {
    entry.allowed = Math.min(entry.body.length, Math.floor(remaining / left));
    remaining -= entry.allowed;
    left -= 1;
  }
}

function cutBody(entry) {
  const clipped = entry.clipped || entry.allowed < entry.body.length;
  if (!clipped) return entry.body;
  const kept = entry.body.slice(0, entry.allowed);
  const end = kept.lastIndexOf('\n');
  return `${end > 0 ? kept.slice(0, end) : kept}\n...[cut: pass paths: ["${entry.file.path}"] to see more of this file]`;
}

async function renderDiff(shell, root, now, files, maxChars) {
  const diffable = files.filter((file) => !file.binary && !file.path.startsWith('"'));
  const shown = diffable.slice(0, MAX_DIFFED_FILES);
  if (!shown.length) return { diff: '', cut: false, omitted: [] };
  const capBytes = Math.floor(MAX_SCRIPT_BYTES / shown.length);
  const result = await shell.run(diffScript(root, now, shown, capBytes));
  const failure = commandError(result);
  if (failure) return { error: failure };

  const sections = parseSections(result.stdout);
  const entries = shown.map((file, index) => {
    const body = hunksOnly(firstSection(sections, `file ${index}`)?.lines || []);
    return {
      file,
      header: `=== ${fileLine(file)}`,
      body,
      clipped: Buffer.byteLength(body) >= capBytes - 1,
    };
  });
  shareBudget(entries, maxChars);
  const diff = entries.map((entry) => [entry.header, cutBody(entry)].filter(Boolean).join('\n')).join('\n');
  return {
    diff,
    cut: entries.some((entry) => entry.clipped || entry.allowed < entry.body.length),
    omitted: diffable.slice(MAX_DIFFED_FILES).map((file) => file.path),
  };
}

function readSnapshot(result, target) {
  const failure = commandError(result);
  if (failure) return { error: failure };
  const sections = parseSections(result.stdout);
  const location = locationError(sections, target);
  if (location) return { error: location };
  if (firstSection(sections, 'not-repo')) {
    return { error: `${workspaceRelative(target)} is not a git repository. Pass path with a repository directory.` };
  }
  if (firstSection(sections, 'bad-base')) return { error: 'base is not a commit in this repository.' };
  if (firstSection(sections, 'failed')) {
    return { error: `Could not read the working tree: ${sectionLines(sections, 'failed').join(' ')}` };
  }
  const now = sectionLines(sections, 'now')[0];
  if (!now) return { error: `Could not read the repository: ${String(result.stderr || '').slice(0, 300)}` };
  return {
    sections,
    now,
    root: sectionLines(sections, 'root')[0],
    branch: sectionLines(sections, 'branch')[0],
    porcelain: firstSection(sections, 'porcelain')?.lines.filter(Boolean) || [],
  };
}

async function describeRepository(shell, snapshot, files, { filters, maxChars, scope, extra = {} }) {
  const selected = files.filter((file) => matchesFilters(file.path, filters));
  const rendered = await renderDiff(shell, snapshot.root, snapshot.now, selected, maxChars);
  if (rendered.error) return { error: rendered.error };
  const listed = selected.slice(0, MAX_LISTED_FILES);
  return {
    scope,
    root: snapshot.root,
    branch: snapshot.branch,
    ...extra,
    files: listed.map(fileLine),
    ...(selected.length > listed.length ? { files_omitted: selected.length - listed.length } : {}),
    diff: rendered.diff,
    truncated: rendered.cut || rendered.omitted.length > 0 || selected.length > listed.length,
    ...(rendered.omitted.length ? { not_diffed: rendered.omitted } : {}),
    ...(selected.length ? {} : { note: 'No changes.' }),
  };
}

// Everything uncommitted in one repository, or everything since a ref.
async function diffAgainstBase(shell, args, maxChars) {
  const base = String(args.base ?? '').trim();
  if (base.startsWith('-')) return { error: 'base must be a git ref.' };
  const resolveBase = base
    ? `neo_base=$(g merge-base ${shellQuote(base)} HEAD 2>/dev/null || g rev-parse -q --verify ${shellQuote(`${base}^{commit}`)})`
    : 'neo_base=$(g rev-parse -q --verify HEAD || g hash-object -t tree /dev/null)';
  const script = [
    ...enterRepositoryLines(args.path),
    resolveBase,
    `[ -n "$neo_base" ] || { ${section('bad-base')}; exit 0; }`,
    ...snapshotLines(),
    ...listingLines('$neo_base'),
  ].join('\n');
  const snapshot = readSnapshot(await shell.run(script), args.path);
  if (snapshot.error) return snapshot;
  return describeRepository(shell, snapshot, listedFiles(snapshot.sections), {
    filters: pathFilters(args.paths, snapshot.root),
    maxChars,
    scope: base ? 'base' : 'uncommitted',
    extra: base ? { base } : {},
  });
}

// What this run changed in one repository: each file against the tree it had just
// before the run first touched it. Someone else's dirty files are not part of it.
// The harness recorded this root, and the run already wrote there, so it need not
// be in the workspace: a shell command may have cloned elsewhere.
async function diffRunChanges(shell, repository, args, maxChars) {
  const bySource = new Map();
  const paths = repository.paths.slice(0, MAX_RUN_PATHS);
  for (const { path: file, source } of paths) {
    if (!bySource.has(source)) bySource.set(source, []);
    bySource.get(source).push(file);
  }
  const script = [
    ...enterRepositoryLines(repository.root, { anywhere: true }),
    ...snapshotLines(),
    ...[...bySource].flatMap(([source, files]) => listingLines(source, files)),
  ].join('\n');
  const snapshot = readSnapshot(await shell.run(script), repository.root);
  if (snapshot.error) return snapshot;
  const owned = new Set(repository.paths.map((entry) => entry.path));
  const others = snapshot.porcelain.filter((line) => !owned.has(line.slice(3))).length;
  return describeRepository(shell, snapshot, listedFiles(snapshot.sections), {
    filters: pathFilters(args.paths, snapshot.root),
    maxChars,
    scope: 'run',
    extra: others ? { other_uncommitted_files: others } : {},
  });
}

// `repositories` are the ones this run changed: [{ root, paths: [{ path, source }] }].
async function repoDiff(shell, args = {}, repositories = []) {
  const requested = Number(args.max_chars);
  const maxChars = Number.isFinite(requested) && requested > 0
    ? Math.min(Math.floor(requested), MAX_CHARS)
    : DEFAULT_MAX_CHARS;
  const useRun = !args.base && args.scope !== 'uncommitted';
  const changed = useRun ? repositories.filter((repository) => repository.paths.length) : [];
  if (!changed.length) {
    const result = await diffAgainstBase(shell, args, maxChars);
    return useRun && args.scope === 'run' && !result.error
      ? { ...result, note: 'This run has recorded no changes, so this is everything uncommitted.' }
      : result;
  }
  if (changed.length === 1) return diffRunChanges(shell, changed[0], args, maxChars);
  const share = Math.floor(maxChars / changed.length);
  const results = [];
  for (const repository of changed) results.push(await diffRunChanges(shell, repository, args, share));
  return { scope: 'run', repositories: results };
}

module.exports = { repoDiff };
