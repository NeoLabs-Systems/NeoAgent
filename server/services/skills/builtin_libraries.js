'use strict';

const fs = require('fs');
const path = require('path');
const { normalizeSkillName } = require('../ai/toolRunner');
const { parseFrontmatter } = require('./skills_sh');
const { findSkills, installLibraryEntries } = require('./skill_library');

// Skill libraries shipped with NeoAgent. Each folder under this directory is
// one library: a library.json plus skill folders, installed together as one
// library of ordinary user skills (see skill_library.js).
const LIBRARIES_DIR = path.join(__dirname, '..', '..', 'catalog_sources', 'skill-libraries');
const MANIFEST_FILE = 'library.json';

function notFound(id) {
  const error = new Error(`No built-in skill library named '${id}'`);
  error.status = 404;
  return error;
}

/** Every file under `root` as a `{ path, data }` entry with a posix path. */
function readEntries(root, relative = '') {
  const entries = [];
  for (const item of fs.readdirSync(path.join(root, relative), { withFileTypes: true })) {
    const child = relative ? `${relative}/${item.name}` : item.name;
    if (item.isDirectory()) entries.push(...readEntries(root, child));
    else if (item.isFile()) entries.push({ path: child, data: fs.readFileSync(path.join(root, child)) });
  }
  return entries;
}

function loadLibrary(id) {
  const root = path.join(LIBRARIES_DIR, id);
  const manifest = JSON.parse(fs.readFileSync(path.join(root, MANIFEST_FILE), 'utf8'));
  const skills = findSkills(readEntries(root)).map((skill) => {
    const parsed = parseFrontmatter(skill.file.data.toString('utf8'));
    return {
      name: normalizeSkillName(parsed?.data.name || path.posix.basename(skill.dir)),
      description: String(parsed?.data.description || '').replace(/\s+/g, ' ').trim(),
    };
  });
  return {
    id,
    title: String(manifest.title || id),
    description: String(manifest.description || ''),
    homepage: String(manifest.homepage || ''),
    license: String(manifest.license || ''),
    revision: String(manifest.revision || ''),
    skills,
  };
}

// The catalog ships with the code, so it is read once per process.
let catalog = null;

function builtinSkillLibraries() {
  if (!catalog) {
    catalog = fs.existsSync(LIBRARIES_DIR)
      ? fs.readdirSync(LIBRARIES_DIR, { withFileTypes: true })
        .filter((item) => item.isDirectory() && fs.existsSync(path.join(LIBRARIES_DIR, item.name, MANIFEST_FILE)))
        .map((item) => loadLibrary(item.name))
        .sort((a, b) => a.title.localeCompare(b.title))
      : [];
  }
  return catalog;
}

/** Installs (or reinstalls) every skill of a built-in library for one user. */
function installBuiltinSkillLibrary(runner, userId, id) {
  // Only ids from the catalog reach the file system.
  if (!builtinSkillLibraries().some((library) => library.id === id)) throw notFound(id);
  const entries = readEntries(path.join(LIBRARIES_DIR, id))
    .filter((entry) => entry.path !== MANIFEST_FILE);
  return installLibraryEntries(runner, userId, entries, { library: id, keepLibrary: true });
}

module.exports = {
  builtinSkillLibraries,
  installBuiltinSkillLibrary,
};
