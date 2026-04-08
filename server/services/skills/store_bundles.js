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

const BUNDLED_SKILL_PATHS = [
  'creative/ascii-art',
  'creative/ascii-video',
  'creative/excalidraw',
  'creative/manim-video',
  'creative/p5js',
  'creative/popular-web-designs',
  'creative/songwriting-and-ai-music',
  'data-science/jupyter-live-kernel',
  'email/himalaya',
  'github/codebase-inspection',
  'github/github-auth',
  'github/github-code-review',
  'github/github-issues',
  'github/github-pr-workflow',
  'github/github-repo-management',
  'leisure/find-nearby',
  'mcp/mcporter',
  'mcp/native-mcp',
  'media/gif-search',
  'media/youtube-content',
  'note-taking/obsidian',
  'productivity/linear',
  'productivity/nano-pdf',
  'productivity/notion',
  'productivity/ocr-and-documents',
  'research/arxiv',
  'research/blogwatcher',
  'research/llm-wiki',
  'research/polymarket',
  'software-development/plan',
  'software-development/requesting-code-review',
  'software-development/subagent-driven-development',
  'software-development/systematic-debugging',
  'software-development/test-driven-development',
  'software-development/writing-plans',
];

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
  const content = fs.readFileSync(filePath, 'utf-8');
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

const BUNDLED_SKILLS_CATALOG = BUNDLED_SKILL_PATHS.map(buildBundledCatalogEntry);

module.exports = {
  BUNDLED_SKILLS_CATALOG,
  BUNDLED_SKILL_PATHS,
  BUNDLED_SKILL_SOURCE_ROOT,
};
