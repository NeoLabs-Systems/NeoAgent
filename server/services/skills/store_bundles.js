const fs = require('fs');
const path = require('path');

const BUNDLED_SKILL_SOURCE_ROOT = path.join(
  __dirname,
  '..',
  '..',
  'catalog_sources',
  'store-bundles',
  'skills',
);

const CATEGORY_ICONS = {
  creative: '🎨',
  'data-science': '📓',
  email: '✉️',
  github: '🐙',
  leisure: '📍',
  mcp: '🔌',
  media: '🎬',
  'note-taking': '📒',
  productivity: '📋',
  research: '🔬',
  'software-development': '🛠️',
};

const TOKEN_DISPLAY_NAMES = {
  ai: 'AI',
  api: 'API',
  arxiv: 'arXiv',
  ascii: 'ASCII',
  codebase: 'Codebase',
  codex: 'Codex',
  documents: 'Documents',
  gif: 'GIF',
  github: 'GitHub',
  himalaya: 'Himalaya',
  js: 'JS',
  jupyter: 'Jupyter',
  kernel: 'Kernel',
  linear: 'Linear',
  llm: 'LLM',
  mcp: 'MCP',
  nearby: 'Nearby',
  nano: 'Nano',
  notion: 'Notion',
  ocr: 'OCR',
  p5js: 'p5.js',
  pdf: 'PDF',
  polymarket: 'Polymarket',
  pr: 'PR',
  web: 'Web',
};

function stripQuotes(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

function readFrontmatter(filePath) {
  // Normalize CRLF so Windows-checked-out skill files parse the same as LF.
  const content = fs.readFileSync(filePath, 'utf-8').replace(/\r\n/g, '\n');
  const match = content.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!match) {
    throw new Error(`Bundled skill is missing frontmatter: ${filePath}`);
  }

  const data = {};
  for (const line of match[1].split('\n')) {
    if (!line || /^\s/.test(line)) continue;
    const colon = line.indexOf(':');
    if (colon === -1) continue;
    const key = line.slice(0, colon).trim();
    const rawValue = line.slice(colon + 1).trim();
    if (!rawValue) continue;
    data[key] = stripQuotes(rawValue);
  }
  return data;
}

function discoverBundledSkillPaths(rootDirectory = BUNDLED_SKILL_SOURCE_ROOT) {
  const discovered = [];

  function visit(directory) {
    const entries = fs.readdirSync(directory, { withFileTypes: true })
      .sort((left, right) => left.name.localeCompare(right.name));
    const skillFile = entries.find(
      (entry) => entry.isFile() && entry.name === 'SKILL.md',
    );
    if (skillFile) {
      const frontmatter = readFrontmatter(path.join(directory, skillFile.name));
      if (String(frontmatter.catalog || 'true').toLowerCase() !== 'false') {
        discovered.push(path.relative(rootDirectory, directory).split(path.sep).join('/'));
      }
    }
    for (const entry of entries) {
      if (entry.isDirectory()) {
        visit(path.join(directory, entry.name));
      }
    }
  }

  if (fs.existsSync(rootDirectory)) {
    visit(rootDirectory);
  }
  return discovered.sort((left, right) => left.localeCompare(right));
}

function toDisplayName(skillPath, frontmatterName) {
  if (frontmatterName && /[A-Z]/.test(frontmatterName)) {
    return frontmatterName;
  }
  const slug = skillPath.split('/').pop() || frontmatterName || skillPath;
  return slug
    .split('-')
    .map((token) => TOKEN_DISPLAY_NAMES[token] || `${token.slice(0, 1).toUpperCase()}${token.slice(1)}`)
    .join(' ');
}

function buildBundledCatalogEntry(skillPath) {
  const sourceDir = path.join(BUNDLED_SKILL_SOURCE_ROOT, skillPath);
  const skillFile = path.join(sourceDir, 'SKILL.md');
  const frontmatter = readFrontmatter(skillFile);
  const category = skillPath.split('/')[0];

  return {
    id: skillPath.replace(/\//g, '-'),
    name: toDisplayName(skillPath, frontmatter.name),
    description: frontmatter.description || `Bundled store skill from ${skillPath}.`,
    category,
    icon: CATEGORY_ICONS[category] || '🧩',
    source: 'store',
    bundleSourceDir: sourceDir,
  };
}

const BUNDLED_SKILL_PATHS = discoverBundledSkillPaths();
const BUNDLED_SKILLS_CATALOG = BUNDLED_SKILL_PATHS.map(buildBundledCatalogEntry);

module.exports = {
  BUNDLED_SKILLS_CATALOG,
  BUNDLED_SKILL_PATHS,
  BUNDLED_SKILL_SOURCE_ROOT,
  discoverBundledSkillPaths,
};
