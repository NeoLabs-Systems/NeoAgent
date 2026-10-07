'use strict';

const fs = require('fs');
const path = require('path');
const { scrubInvisible } = require('../../utils/untrusted_text');
const { prependStoreNotes } = require('./store_service');

// skills.sh is a directory of agent skills hosted in public GitHub repos. Its
// search API names a skill by repo ("owner/repo") plus the skill's id; the
// files themselves are fetched straight from GitHub.
const SKILLS_SH_SEARCH_URL = 'https://skills.sh/api/search';
const GITHUB_API_URL = 'https://api.github.com';
const GITHUB_RAW_URL = 'https://raw.githubusercontent.com';
const REQUEST_TIMEOUT_MS = 15000;
const SEARCH_LIMIT = 30;
const MAX_BUNDLE_FILES = 200;
const MAX_FILE_BYTES = 1024 * 1024;
const MAX_BUNDLE_BYTES = 8 * 1024 * 1024;
const MAX_FRONTMATTER_PROBES = 40;
const SEGMENT_RE = /^[A-Za-z0-9._-]+$/;
const TEXT_EXTENSIONS = new Set([
  '.css', '.html', '.js', '.json', '.md', '.mjs', '.py', '.sh', '.toml', '.ts', '.txt', '.xml', '.yaml', '.yml',
]);

function compact(value) {
  return String(value || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

function isRepoSource(source) {
  const parts = String(source || '').split('/');
  return parts.length === 2 && parts.every((part) => SEGMENT_RE.test(part));
}

// Accepts what people copy from skills.sh: a skill page URL, an
// "owner/repo/skill" id, or the `npx skills add <repo> --skill <name>` command.
function parseSkillsShRef(input) {
  const text = String(input || '').trim();
  const command = text.match(/skills\s+add\s+(\S+)\s+(?:--skill|-s)\s+(\S+)/);
  if (command) {
    const source = command[1]
      .replace(/^https?:\/\/(www\.)?github\.com\//i, '')
      .replace(/\.git$/i, '')
      .replace(/\/+$/, '');
    const name = command[2].replace(/^['"]|['"]$/g, '');
    return isRepoSource(source) ? { source, skillId: name, name } : null;
  }
  const id = text.replace(/^https?:\/\/(www\.)?skills\.sh\//i, '').replace(/[?#].*$/, '').replace(/\/+$/, '');
  const parts = id.split('/');
  if (parts.length !== 3 || !parts.every((part) => SEGMENT_RE.test(part))) return null;
  return { source: `${parts[0]}/${parts[1]}`, skillId: parts[2], name: parts[2] };
}

async function fetchOk(url, { json = false, binary = false } = {}) {
  const headers = { 'User-Agent': 'NeoAgent' };
  if (url.startsWith(GITHUB_API_URL)) {
    headers.Accept = 'application/vnd.github+json';
    if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }
  const response = await fetch(url, { headers, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
  if (!response.ok) {
    const error = new Error(`${new URL(url).host} returned ${response.status}`);
    error.status = response.status === 404 ? 404 : 502;
    throw error;
  }
  if (json) return response.json();
  if (binary) return Buffer.from(await response.arrayBuffer());
  return response.text();
}

async function searchSkillsSh(query) {
  const ref = parseSkillsShRef(query);
  if (ref) {
    return [{ id: `${ref.source}/${ref.skillId}`, ...ref, installs: null }];
  }
  if (String(query || '').trim().length < 2) return [];
  const url = `${SKILLS_SH_SEARCH_URL}?q=${encodeURIComponent(query.trim())}&limit=${SEARCH_LIMIT}`;
  const data = await fetchOk(url, { json: true });
  return (Array.isArray(data?.skills) ? data.skills : [])
    .filter((skill) => isRepoSource(skill?.source) && skill?.skillId)
    .map((skill) => ({
      id: `${skill.source}/${skill.skillId}`,
      source: skill.source,
      skillId: String(skill.skillId),
      name: String(skill.name || skill.skillId),
      installs: Number.isFinite(skill.installs) ? skill.installs : null,
    }));
}

// Top-level frontmatter keys only. Handles quoted values and YAML block
// scalars (`>` / `|`), which is how longer skill descriptions are written.
function parseFrontmatter(content) {
  const match = String(content || '').replace(/\r\n/g, '\n').match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) return null;
  const data = {};
  const lines = match[1].split('\n');
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    const keyMatch = line.match(/^([A-Za-z_][\w-]*)\s*:\s*(.*)$/);
    if (!keyMatch) continue;
    let value = keyMatch[2].trim();
    if (/^[>|][-+]?$/.test(value)) {
      const block = [];
      while (index + 1 < lines.length && (/^\s/.test(lines[index + 1]) || !lines[index + 1])) {
        block.push(lines[++index].trim());
      }
      value = value.startsWith('|') ? block.join('\n').trim() : block.join(' ').replace(/\s+/g, ' ').trim();
    } else if (/^(['"]).*\1$/.test(value)) {
      value = value.slice(1, -1);
    }
    data[keyMatch[1]] = value;
  }
  return { data, body: match[2] };
}

async function readRepoTree(source) {
  const tree = await fetchOk(`${GITHUB_API_URL}/repos/${source}/git/trees/HEAD?recursive=1`, { json: true });
  return Array.isArray(tree?.tree) ? tree.tree : [];
}

function rawUrl(source, filePath) {
  return `${GITHUB_RAW_URL}/${source}/HEAD/${filePath.split('/').map(encodeURIComponent).join('/')}`;
}

// The skills.sh id is derived from the skill's frontmatter name, and its index
// can trail the repo, so an exact name match wins and a directory or
// punctuation-insensitive match is the fallback.
async function locateSkillFile(source, ref, tree) {
  const skillFiles = tree
    .filter((entry) => entry.type === 'blob' && path.posix.basename(entry.path) === 'SKILL.md')
    .map((entry) => entry.path);
  if (skillFiles.length === 0) return null;

  const wanted = new Set([compact(ref.skillId), compact(ref.name)]);
  const byDir = skillFiles.filter((file) => wanted.has(compact(path.posix.basename(path.posix.dirname(file)))));
  const probes = byDir.concat(skillFiles.filter((file) => !byDir.includes(file))).slice(0, MAX_FRONTMATTER_PROBES);

  for (const file of probes) {
    const content = await fetchOk(rawUrl(source, file));
    const name = parseFrontmatter(content)?.data.name;
    if (name && (name === ref.name || name === ref.skillId || wanted.has(compact(name)))) {
      return { file, content };
    }
  }
  if (byDir.length === 1) {
    return { file: byDir[0], content: await fetchOk(rawUrl(source, byDir[0])) };
  }
  return skillFiles.length === 1
    ? { file: skillFiles[0], content: await fetchOk(rawUrl(source, skillFiles[0])) }
    : null;
}

async function downloadSkillsShSkill(ref) {
  if (!isRepoSource(ref?.source) || !ref?.skillId) {
    const error = new Error('A skills.sh skill needs a GitHub repo and a skill id');
    error.status = 400;
    throw error;
  }
  const tree = await readRepoTree(ref.source);
  const located = await locateSkillFile(ref.source, { name: ref.name || ref.skillId, skillId: ref.skillId }, tree);
  if (!located) {
    const error = new Error(`No skill named '${ref.name || ref.skillId}' found in ${ref.source}`);
    error.status = 404;
    throw error;
  }

  const skillDir = path.posix.dirname(located.file);
  const prefix = skillDir === '.' ? '' : `${skillDir}/`;
  const extras = tree.filter((entry) => (
    entry.type === 'blob'
    && entry.path !== located.file
    && entry.path.startsWith(prefix)
  ));
  if (extras.length > MAX_BUNDLE_FILES) {
    const error = new Error(`Skill has ${extras.length} files; the limit is ${MAX_BUNDLE_FILES}`);
    error.status = 413;
    throw error;
  }

  const files = [];
  let totalBytes = Buffer.byteLength(located.content);
  for (const entry of extras) {
    if (Number(entry.size) > MAX_FILE_BYTES) continue;
    totalBytes += Number(entry.size || 0);
    if (totalBytes > MAX_BUNDLE_BYTES) {
      const error = new Error('Skill files exceed the 8 MB install limit');
      error.status = 413;
      throw error;
    }
    const relativePath = entry.path.slice(prefix.length);
    const isText = TEXT_EXTENSIONS.has(path.posix.extname(relativePath).toLowerCase());
    const data = await fetchOk(rawUrl(ref.source, entry.path), { binary: !isText });
    files.push({ relativePath, data: isText ? scrubInvisible(data) : data });
  }
  return { skillContent: scrubInvisible(located.content), files };
}

async function installSkillsShSkill(runner, userId, ref) {
  const { skillContent, files } = await downloadSkillsShSkill(ref);
  const parsed = parseFrontmatter(skillContent);
  if (!parsed?.data.name) {
    const error = new Error('Skill file has no frontmatter name');
    error.status = 422;
    throw error;
  }

  const result = runner.createSkill(
    userId,
    parsed.data.name,
    String(parsed.data.description || '').replace(/\s+/g, ' ').trim(),
    prependStoreNotes(parsed.body),
    { source: 'skills.sh', skills_sh_id: `${ref.source}/${ref.skillId}` },
  );
  if (result.error) {
    const error = new Error(result.error);
    error.status = 409;
    throw error;
  }

  const root = path.dirname(result.path);
  for (const file of files) {
    const target = path.resolve(root, file.relativePath);
    if (!target.startsWith(`${root}${path.sep}`)) continue;
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, file.data);
  }
  return { name: result.name, fileCount: files.length + 1 };
}

module.exports = {
  installSkillsShSkill,
  parseFrontmatter,
  parseSkillsShRef,
  searchSkillsSh,
};
