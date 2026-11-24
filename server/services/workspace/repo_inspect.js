'use strict';

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

const MAX_LAYOUT_ENTRIES = 40;
const MAX_DIRTY_FILES = 20;
const MAX_LANGUAGES = 8;
const MAX_SCRIPTS = 8;
const MAX_SCRIPT_CHARS = 100;
const DOC_FILE = /^(readme|agents|claude|contributing|guidelines)(\.\w+)?$/i;
const MANIFESTS = new Set([
  'package.json', 'pnpm-workspace.yaml', 'pyproject.toml', 'setup.py', 'requirements.txt', 'go.mod', 'Cargo.toml',
  'pubspec.yaml', 'Gemfile', 'pom.xml', 'build.gradle', 'build.gradle.kts', 'composer.json', 'Makefile', 'CMakeLists.txt',
  'Dockerfile', 'tsconfig.json',
]);
const USEFUL_SCRIPT = /^(test|lint|build|check|typecheck|format)/;

// What repo_overview and run_tests both need to tell how a project runs.
function probeScript() {
  return [
    `${section('listing')}; ls -Ap | head -n 200`,
    `${section('package')}; [ -f package.json ] && head -c 65536 package.json; echo`,
    `${section('make')}; [ -f Makefile ] && grep -E '^(test|check)[A-Za-z0-9_-]*:' Makefile | head -n 5`,
    `${section('flutter')}; [ -f pubspec.yaml ] && grep -cE '^[[:space:]]*flutter:' pubspec.yaml`,
    `${section('pytest')}; [ -f pyproject.toml ] && grep -c pytest pyproject.toml`,
  ];
}

function parseProbe(sections) {
  const listing = sectionLines(sections, 'listing');
  let packageJson = null;
  try {
    packageJson = JSON.parse((firstSection(sections, 'package')?.lines || []).join('\n'));
  } catch {
    // A missing or broken manifest just says nothing about how to run things.
  }
  return {
    listing,
    names: new Set(listing.map((entry) => entry.replace(/\/$/, ''))),
    packageJson,
    makeTargets: sectionLines(sections, 'make').map((line) => line.split(':')[0]),
    flutter: Number(sectionLines(sections, 'flutter')[0]) > 0,
    pytest: Number(sectionLines(sections, 'pytest')[0]) > 0,
  };
}

function packageTestCommand({ names, packageJson }) {
  const script = packageJson?.scripts?.test;
  if (typeof script !== 'string' || /no test specified/i.test(script)) return null;
  if (names.has('pnpm-lock.yaml')) return 'pnpm test';
  if (names.has('yarn.lock')) return 'yarn test';
  // Plain `bun test` is bun's own runner, not this script.
  if (names.has('bun.lock') || names.has('bun.lockb')) return 'bun run test';
  return 'npm test';
}

// The project's own entry point wins over what its language would suggest.
function detectTestCommand(probe) {
  const { names, makeTargets, flutter, pytest } = probe;
  const fromPackage = packageTestCommand(probe);
  if (fromPackage) return { command: fromPackage, source: 'package.json' };
  if (makeTargets.includes('test')) return { command: 'make test', source: 'Makefile' };
  if (names.has('go.mod')) return { command: 'go test ./...', source: 'go.mod' };
  if (names.has('Cargo.toml')) return { command: 'cargo test', source: 'Cargo.toml' };
  if (names.has('pubspec.yaml')) return { command: flutter ? 'flutter test' : 'dart test', source: 'pubspec.yaml' };
  if (names.has('pytest.ini') || names.has('conftest.py') || names.has('tox.ini') || pytest) {
    return { command: 'python3 -m pytest', source: 'pytest config' };
  }
  if (names.has('tests') && (names.has('pyproject.toml') || names.has('setup.py') || names.has('requirements.txt'))) {
    return { command: 'python3 -m pytest', source: 'tests/' };
  }
  if (names.has('Gemfile') && names.has('spec')) return { command: 'bundle exec rspec', source: 'Gemfile' };
  if (names.has('gradlew')) return { command: './gradlew test', source: 'gradlew' };
  if (names.has('build.gradle') || names.has('build.gradle.kts')) return { command: 'gradle test', source: 'build.gradle' };
  if (names.has('pom.xml')) return { command: 'mvn test', source: 'pom.xml' };
  if (names.has('package.json') && (names.has('test') || names.has('tests'))) {
    return { command: 'node --test', source: 'test directory' };
  }
  return null;
}

async function detectProjectTests(shell, target) {
  const result = await shell.run([...enterScript(target, { anywhere: true }), ...probeScript()].join('\n'));
  const failure = commandError(result);
  if (failure) return { error: failure };
  const sections = parseSections(result.stdout);
  const location = locationError(sections, target);
  if (location) return { error: location };
  return { test: detectTestCommand(parseProbe(sections)) };
}

function overviewScript(target) {
  // Counts tracked files per top-level entry and per extension, in one pass.
  const tally = `awk -F/ '{ top[NF>1 ? $1 "/" : $1]++; n=split($NF, p, "."); if (n>1) ext[tolower(p[n])]++ } END { for (k in top) print "T", top[k], k; for (k in ext) print "E", ext[k], k }'`;
  return [
    ...enterScript(target),
    GIT_FUNCTION,
    `${section('root')}; pwd -P`,
    ...probeScript(),
    'if g rev-parse --is-inside-work-tree >/dev/null 2>&1; then',
    '  neo_top=$(g rev-parse --show-toplevel)',
    `  case "$neo_top/" in "$neo_root"/*) ;; *) ${section('outside')}; exit 0 ;; esac`,
    `  ${section('toplevel')}; printf '%s\\n' "$neo_top"`,
    `  ${section('branch')}; g symbolic-ref --short -q HEAD || g rev-parse --short HEAD 2>/dev/null || echo '(no commits)'`,
    `  ${section('head')}; g log -1 --format='%h %s' 2>/dev/null | cut -c 1-120`,
    `  ${section('upstream')}; g rev-parse --abbrev-ref '@{u}' 2>/dev/null && g rev-list --left-right --count '@{u}...HEAD' 2>/dev/null`,
    ...snapshotLines({ status: true }),
    `  ${section('dirty')}; tail -n +3 "$neo_tmp/snapshot" | awk 'NR<=${MAX_DIRTY_FILES} { print } END { print "total " NR }'`,
    `  ${section('tally')}; g ls-files | ${tally}`,
    'else',
    `  ${section('repos')}; for neo_d in */; do [ -e "$neo_d/.git" ] && printf '%s\\n' "$neo_d"; done 2>/dev/null | head -n 20`,
    `  ${section('tally')}; find . -maxdepth 4 \\( -name node_modules -o -name .git -o -name .cache \\) -prune -o -type f -print 2>/dev/null | head -n 5000 | sed 's|^\\./||' | ${tally}`,
    'fi',
  ].join('\n');
}

function parseTally(lines) {
  const tops = new Map();
  const extensions = [];
  for (const line of lines) {
    const match = /^([TE]) (\d+) (.+)$/.exec(line);
    if (!match) continue;
    if (match[1] === 'T') tops.set(match[3], Number(match[2]));
    else extensions.push({ name: match[3], files: Number(match[2]) });
  }
  extensions.sort((left, right) => right.files - left.files || left.name.localeCompare(right.name));
  return { tops, extensions };
}

function layoutEntries(listing, tops) {
  const entries = listing
    .filter((entry) => entry !== '.git/' && entry !== '.git')
    .map((entry) => (tops.get(entry) > 1 ? `${entry} (${tops.get(entry)})` : entry));
  const shown = entries.slice(0, MAX_LAYOUT_ENTRIES);
  return entries.length > shown.length ? [...shown, `...and ${entries.length - shown.length} more`] : shown;
}

function usefulScripts(packageJson) {
  const scripts = Object.entries(packageJson?.scripts || {})
    .filter(([name, value]) => USEFUL_SCRIPT.test(name) && typeof value === 'string')
    .slice(0, MAX_SCRIPTS)
    .map(([name, value]) => [name, value.length > MAX_SCRIPT_CHARS ? `${value.slice(0, MAX_SCRIPT_CHARS)}...` : value]);
  return scripts.length ? Object.fromEntries(scripts) : undefined;
}

function gitSummary(sections) {
  const toplevel = sectionLines(sections, 'toplevel')[0];
  if (!toplevel) return null;
  const dirtyLines = sectionLines(sections, 'dirty');
  const total = Number(/^total (\d+)$/.exec(dirtyLines[dirtyLines.length - 1] || '')?.[1] || 0);
  const [upstream, counts] = sectionLines(sections, 'upstream');
  const [behind, ahead] = String(counts || '').split(/\s+/).map(Number);
  return {
    toplevel,
    branch: sectionLines(sections, 'branch')[0],
    head: sectionLines(sections, 'head')[0],
    ...(upstream ? { upstream, ahead, behind } : {}),
    dirty: total,
    ...(total ? { dirty_files: dirtyLines.slice(0, -1).map((line) => line.trimEnd()) } : {}),
    ...(total > MAX_DIRTY_FILES ? { dirty_files_omitted: total - MAX_DIRTY_FILES } : {}),
  };
}

async function repoOverview(shell, args = {}) {
  const result = await shell.run(overviewScript(args.path));
  const failure = commandError(result);
  if (failure) return { error: failure };
  const sections = parseSections(result.stdout);
  const location = locationError(sections, args.path);
  if (location) return { error: location };
  if (firstSection(sections, 'failed')) return { error: `Could not snapshot the repository: ${sectionLines(sections, 'failed').join(' ')}` };

  const probe = parseProbe(sections);
  const { tops, extensions } = parseTally(sectionLines(sections, 'tally'));
  const repos = sectionLines(sections, 'repos');
  const test = detectTestCommand(probe);
  return {
    path: workspaceRelative(args.path),
    git: gitSummary(sections),
    ...(repos.length ? { repos } : {}),
    layout: layoutEntries(probe.listing, tops),
    languages: extensions.slice(0, MAX_LANGUAGES).map((entry) => `${entry.name}: ${entry.files}`),
    manifests: probe.listing.filter((entry) => MANIFESTS.has(entry)),
    docs: probe.listing.filter((entry) => DOC_FILE.test(entry)),
    test: test || 'not detected: pass a command to run_tests',
    scripts: usefulScripts(probe.packageJson),
  };
}

module.exports = { detectProjectTests, repoOverview };
