'use strict';

const fs = require('fs');
const path = require('path');
const { readZipEntries } = require('../../utils/zip_reader');
const { scrubInvisible } = require('../../utils/untrusted_text');
const { normalizeSkillName } = require('../ai/toolRunner');
const { parseFrontmatter, prependNeoAgentNotes } = require('./skills_sh');

// A skill library is a zip of skill folders, each holding a SKILL.md, the way
// a `.claude/skills` folder is laid out. Every skill installs as an ordinary
// user skill tagged with the library's name, so the app can group them.
const MAX_SKILLS = 300;
const TEXT_EXTENSIONS = new Set([
  '.css', '.csv', '.html', '.js', '.json', '.md', '.mjs', '.py', '.sh', '.toml', '.ts', '.txt', '.xml', '.yaml', '.yml',
]);
const IGNORED_SEGMENTS = new Set(['__MACOSX', '.git', 'node_modules']);

function libraryError(message, status = 400) {
  const error = new Error(message);
  error.status = status;
  return error;
}

/** "via-main.zip" -> "via-main"; anything unusable becomes "skill-library". */
function libraryNameFrom(value) {
  const stem = String(value || '').replace(/\.zip$/i, '').trim();
  return normalizeSkillName(stem) || 'skill-library';
}

// Drops entries that could escape a folder, can't be file names, or are
// archive clutter.
function safeEntries(entries) {
  return entries.filter((entry) => {
    // eslint-disable-next-line no-control-regex
    if (/[\u0000-\u001f]/.test(entry.path)) return false;
    const parts = entry.path.split('/');
    if (entry.path.startsWith('/') || parts.some((part) => part === '..' || part === '')) return false;
    if (parts.some((part) => IGNORED_SEGMENTS.has(part))) return false;
    return parts[parts.length - 1] !== '.DS_Store';
  });
}

/**
 * Finds the skill folders in an archive. A SKILL.md inside another skill's
 * folder belongs to that skill (a bundled example, say), not a skill of its own.
 */
function findSkills(entries) {
  const roots = entries
    .filter((entry) => path.posix.basename(entry.path).toLowerCase() === 'skill.md')
    .map((entry) => ({ dir: path.posix.dirname(entry.path), file: entry }))
    .sort((a, b) => a.dir.split('/').length - b.dir.split('/').length);
  const skills = [];
  for (const root of roots) {
    const nested = skills.some((skill) => skill.dir === '.' || root.dir.startsWith(`${skill.dir}/`));
    if (nested) continue;
    const prefix = root.dir === '.' ? '' : `${root.dir}/`;
    skills.push({
      dir: root.dir,
      file: root.file,
      extras: entries.filter((entry) => entry !== root.file && entry.path.startsWith(prefix)),
    });
  }
  return skills;
}

function decodeExtra(entry) {
  const isText = TEXT_EXTENSIONS.has(path.posix.extname(entry.path).toLowerCase());
  return isText ? scrubInvisible(entry.data.toString('utf8')) : entry.data;
}

function installSkillLibrary(runner, userId, { buffer, filename, name } = {}) {
  const entries = safeEntries(readZipEntries(buffer));
  const found = findSkills(entries);
  if (found.length === 0) {
    throw libraryError('No skills found. The zip needs folders that each contain a SKILL.md.', 422);
  }
  if (found.length > MAX_SKILLS) {
    throw libraryError(`The archive has ${found.length} skills; the limit is ${MAX_SKILLS}`, 413);
  }

  // One skill is just a skill; several make a library.
  const library = found.length > 1 ? libraryNameFrom(name || filename) : '';
  const installed = [];
  const skipped = [];
  const seen = new Set();
  for (const skill of found) {
    const content = scrubInvisible(skill.file.data.toString('utf8'));
    const parsed = parseFrontmatter(content);
    const folderName = skill.dir === '.' ? libraryNameFrom(filename) : path.posix.basename(skill.dir);
    const skillName = normalizeSkillName(parsed?.data.name || folderName);
    if (!skillName) {
      skipped.push({ name: folderName, reason: 'No usable skill name' });
      continue;
    }
    // Repos often carry the same skill in two places; the first one wins.
    if (seen.has(skillName)) {
      skipped.push({ name: skillName, reason: 'Another skill in this zip has the same name' });
      continue;
    }
    seen.add(skillName);

    // Uploading the same library again replaces its skills; a name the user
    // already has from anywhere else is left alone.
    const existing = runner.getAll(userId).find((item) => item.name === skillName && item.ownerType === 'user');
    if (existing) {
      if (!library || existing.metadata?.library !== library) {
        skipped.push({ name: skillName, reason: 'You already have a skill with this name' });
        continue;
      }
      runner.deleteSkill(userId, skillName);
    }

    const result = runner.createSkill(
      userId,
      skillName,
      String(parsed?.data.description || '').replace(/\s+/g, ' ').trim(),
      prependNeoAgentNotes(parsed ? parsed.body : content),
      library ? { source: 'library', library } : { source: 'user' },
    );
    if (result.error) {
      skipped.push({ name: skillName, reason: result.error });
      continue;
    }

    const root = path.dirname(result.path);
    const prefix = skill.dir === '.' ? '' : `${skill.dir}/`;
    for (const extra of skill.extras) {
      const target = path.resolve(root, extra.path.slice(prefix.length));
      if (!target.startsWith(`${root}${path.sep}`)) continue;
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, decodeExtra(extra));
    }
    installed.push(result.name);
  }

  // A re-upload is the library's new contents: skills it no longer has go.
  const removed = [];
  if (library) {
    for (const stale of librarySkills(runner, userId, library)) {
      if (seen.has(stale.name)) continue;
      runner.deleteSkill(userId, stale.name);
      removed.push(stale.name);
    }
  }

  return { library, installed, skipped, removed };
}

function librarySkills(runner, userId, library) {
  return runner.getAll(userId).filter(
    (skill) => skill.ownerType === 'user' && skill.metadata?.library === library,
  );
}

function setSkillLibraryEnabled(runner, userId, library, enabled) {
  const skills = librarySkills(runner, userId, library);
  if (skills.length === 0) throw libraryError(`No skill library named '${library}'`, 404);
  for (const skill of skills) runner.setSkillEnabled(userId, skill.name, enabled);
  return { success: true, library, count: skills.length };
}

function deleteSkillLibrary(runner, userId, library) {
  const skills = librarySkills(runner, userId, library);
  if (skills.length === 0) throw libraryError(`No skill library named '${library}'`, 404);
  for (const skill of skills) runner.deleteSkill(userId, skill.name);
  return { success: true, library, deleted: skills.map((skill) => skill.name) };
}

module.exports = {
  deleteSkillLibrary,
  findSkills,
  installSkillLibrary,
  libraryNameFrom,
  setSkillLibraryEnabled,
};
