const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');

const SKILLS_DIR = path.join(AGENT_DATA_DIR, 'skills');

const TEXT_BUNDLE_EXTENSIONS = new Set([
  '.css',
  '.env',
  '.html',
  '.js',
  '.json',
  '.md',
  '.py',
  '.sh',
  '.toml',
  '.txt',
  '.yaml',
  '.yml',
]);

const DOC_BUNDLE_EXTENSIONS = new Set([
  '.css',
  '.env',
  '.html',
  '.json',
  '.md',
  '.toml',
  '.txt',
  '.yaml',
  '.yml',
]);

function getCatalogInstallPath(skill) {
  return skill.bundleSourceDir
    ? path.join(SKILLS_DIR, skill.id)
    : path.join(SKILLS_DIR, `${skill.id}.md`);
}

function injectCatalogMetadata(content, skill) {
  const match = String(content || '').match(/^---\n([\s\S]*?)\n---(\n?[\s\S]*)$/);
  if (!match) {
    return content;
  }

  const lines = [];
  let skippingIndentedBlock = false;
  for (const line of match[1].split('\n')) {
    if (skippingIndentedBlock) {
      if (/^\s/.test(line)) {
        continue;
      }
      skippingIndentedBlock = false;
    }
    if (/^metadata\s*:/.test(line)) {
      skippingIndentedBlock = true;
      continue;
    }
    if (/^author\s*:.*neoagent/i.test(line) || /^author\s*:.*hermes/i.test(line)) {
      continue;
    }
    if (/^store_id\s*:/.test(line)) {
      continue;
    }
    lines.push(line);
  }

  const additions = [];
  if (!lines.some((line) => /^category\s*:/i.test(line))) {
    additions.push(`category: ${skill.category}`);
  }
  if (!lines.some((line) => /^source\s*:/i.test(line))) {
    additions.push(`source: ${skill.source || 'store'}`);
  }
  additions.push(`store_id: ${skill.id}`);

  return `---\n${lines.concat(additions).join('\n')}\n---${match[2]}`;
}

function prependStoreNotes(body) {
  const note = [
    '## NeoAgent Notes',
    '',
    'Map any generic tool references in this skill to NeoAgent equivalents:',
    '- shell and scripts: `execute_command`',
    '- local files and code search: `read_file`, `search_files`, `write_file`, `edit_file`',
    '- remote pages and APIs: `http_request`, `web_search`, and `browser_*` tools',
    '',
  ].join('\n');

  if (/^## NeoAgent Notes$/m.test(body)) {
    return body;
  }
  return `${note}\n${body.replace(/^\n+/, '')}`;
}

function normalizeBundledText(content, skill, fileName) {
  let next = String(content || '');
  const isSkillFile = fileName === 'SKILL.md';
  const extension = path.extname(fileName).toLowerCase();
  const isDocLike = DOC_BUNDLE_EXTENSIONS.has(extension) || isSkillFile;

  if (isSkillFile) {
    const match = next.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
    if (match) {
      next = injectCatalogMetadata(next, skill);
      const parts = next.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
      if (parts) {
        next = `---\n${parts[1]}\n---\n\n${prependStoreNotes(parts[2])}`;
      }
    }
  }

  next = next
    .replace(/~\/\.hermes\b/g, '~/.neoagent')
    .replace(/\bHERMES_HOME\b/g, 'NEOAGENT_HOME')
    .replace(/\bHermesAgent\/([0-9.]+)/g, 'NeoAgent/$1')
    .replace(/\bHermes Agent\b/g, 'NeoAgent')
    .replace(
      /\bRun the Google Workspace setup again from this same Hermes profile\b/g,
      'Run the Google Workspace setup again from this same NeoAgent profile',
    );

  if (isDocLike) {
    next = next
      .replace(/\bhermes-agent\b/g, 'neoagent')
      .replace(/\bHermes\b/g, 'NeoAgent')
      .replace(/\bhermes\b/g, 'neoagent');
  }

  return next;
}

function shouldTransformBundleFile(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  return TEXT_BUNDLE_EXTENSIONS.has(extension) || path.basename(filePath) === 'SKILL.md';
}

function copyCatalogBundle(sourceDir, destinationDir, skill) {
  fs.rmSync(destinationDir, { recursive: true, force: true });
  fs.mkdirSync(destinationDir, { recursive: true });

  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    const sourcePath = path.join(sourceDir, entry.name);
    const destinationPath = path.join(destinationDir, entry.name);
    if (entry.isDirectory()) {
      copyCatalogBundle(sourcePath, destinationPath, skill);
      continue;
    }
    if (shouldTransformBundleFile(sourcePath)) {
      const content = fs.readFileSync(sourcePath, 'utf-8');
      fs.writeFileSync(
        destinationPath,
        normalizeBundledText(content, skill, entry.name),
        'utf-8',
      );
      continue;
    }
    fs.copyFileSync(sourcePath, destinationPath);
  }
}

async function reloadSkillRunner(skillRunner) {
  if (!skillRunner || typeof skillRunner.loadSkills !== 'function') {
    return;
  }
  await skillRunner.loadSkills();
}

function getInstalledCatalogIdsFromRunner(skillRunner) {
  if (!skillRunner || typeof skillRunner.getAll !== 'function') {
    return new Set();
  }
  return new Set(
    skillRunner
      .getAll()
      .map((skill) => skill.metadata?.store_id)
      .filter((value) => typeof value === 'string' && value.trim().length > 0),
  );
}

function listInstalledCatalogIdsFromFilesystem(catalog) {
  const installed = new Set();
  if (!fs.existsSync(SKILLS_DIR)) {
    return installed;
  }

  const knownIds = new Set(catalog.map((skill) => skill.id));
  for (const entry of fs.readdirSync(SKILLS_DIR, { withFileTypes: true })) {
    const candidate = entry.isDirectory()
      ? entry.name
      : entry.isFile() && entry.name.endsWith('.md')
        ? entry.name.replace(/\.md$/i, '')
        : null;
    if (candidate && knownIds.has(candidate)) {
      installed.add(candidate);
    }
  }
  return installed;
}

function listInstalledCatalogIds(catalog, skillRunner) {
  const installed = getInstalledCatalogIdsFromRunner(skillRunner);
  for (const legacyId of listInstalledCatalogIdsFromFilesystem(catalog)) {
    installed.add(legacyId);
  }
  return installed;
}

function listCatalog(catalog, skillRunner) {
  const installed = listInstalledCatalogIds(catalog, skillRunner);
  return catalog.map((skill) => ({
    id: skill.id,
    name: skill.name,
    description: skill.description,
    category: skill.category,
    icon: skill.icon,
    installed: installed.has(skill.id),
  }));
}

async function installCatalogSkill(skill, skillRunner) {
  if (!fs.existsSync(SKILLS_DIR)) {
    fs.mkdirSync(SKILLS_DIR, { recursive: true });
  }

  const installPath = getCatalogInstallPath(skill);
  if (skill.bundleSourceDir) {
    copyCatalogBundle(skill.bundleSourceDir, installPath, skill);
    await reloadSkillRunner(skillRunner);
    return {
      installPath,
      skillPath: path.join(installPath, 'SKILL.md'),
    };
  }

  fs.writeFileSync(installPath, injectCatalogMetadata(skill.content, skill), 'utf-8');
  await reloadSkillRunner(skillRunner);
  return {
    installPath,
    skillPath: installPath,
  };
}

async function uninstallCatalogSkill(skill, skillRunner) {
  const installPath = getCatalogInstallPath(skill);
  if (skill.bundleSourceDir) {
    fs.rmSync(installPath, { recursive: true, force: true });
  } else if (fs.existsSync(installPath)) {
    fs.unlinkSync(installPath);
  }
  await reloadSkillRunner(skillRunner);
  return { installPath };
}

module.exports = {
  SKILLS_DIR,
  copyCatalogBundle,
  getCatalogInstallPath,
  injectCatalogMetadata,
  installCatalogSkill,
  listCatalog,
  listInstalledCatalogIds,
  normalizeBundledText,
  uninstallCatalogSkill,
};
