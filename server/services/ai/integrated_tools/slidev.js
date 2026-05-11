'use strict';

const fs = require('fs');
const path = require('path');
const {
  copyAssetIntoJob,
  createArtifactDescriptor,
  createJobDir,
  ensureDir,
  ensureRepoNodeModulesLink,
  normalizeFilenameBase,
  promoteArtifactDescriptor,
  resolveRepoBinary,
  runCheckedCommand,
  shellEscape,
  writeTextFile,
} = require('./shared');

const SLIDEV_BIN = resolveRepoBinary('slidev');
const DEFAULT_EXPORT_FORMATS = ['pdf'];
const ALLOWED_EXPORT_FORMATS = new Set(['pdf', 'pptx', 'png']);
const ALLOWED_LAYOUTS = new Set(['cover', 'intro', 'statement', 'quote', 'section', 'two-cols', 'default']);

function normalizeArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeExportFormats(value) {
  const formats = normalizeArray(value)
    .map((item) => String(item || '').trim().toLowerCase())
    .filter((item) => ALLOWED_EXPORT_FORMATS.has(item));
  return formats.length > 0 ? [...new Set(formats)] : [...DEFAULT_EXPORT_FORMATS];
}

function buildFrontmatter(args = {}) {
  const lines = [
    '---',
    `theme: ${String(args.theme || 'default').trim() || 'default'}`,
  ];
  if (args.title) lines.push(`title: ${JSON.stringify(String(args.title).trim())}`);
  if (args.subtitle) lines.push(`info: ${JSON.stringify(String(args.subtitle).trim())}`);
  lines.push('layout: cover');
  lines.push('transition: fade-out');
  lines.push('mdc: true');
  lines.push('---');
  return lines.join('\n');
}

function materializeSlideAsset(value, assetsDir, workspaceManager, userId) {
  if (!value) return '';
  const text = String(value).trim();
  if (!text) return '';
  if (/^https?:\/\//i.test(text)) {
    return text;
  }
  const asset = copyAssetIntoJob(text, assetsDir, 'slide-asset', workspaceManager, userId);
  return `./assets/${asset.relativePath}`;
}

function buildStructuredDeckMarkdown(args, jobDir, workspaceManager, userId) {
  const slides = normalizeArray(args.slides);
  if (slides.length === 0) {
    throw new Error('generate_slide_deck requires a non-empty slides array or deck_markdown.');
  }
  const assetsDir = ensureDir(path.join(jobDir, 'assets'));
  const sections = [buildFrontmatter(args)];
  const coverTitle = String(args.title || 'Presentation').trim();
  const coverSubtitle = String(args.subtitle || '').trim();
  sections.push(`# ${coverTitle}${coverSubtitle ? `\n\n${coverSubtitle}` : ''}`);

  for (const slide of slides) {
    const title = String(slide?.title || '').trim();
    const layout = ALLOWED_LAYOUTS.has(String(slide?.layout || '').trim()) ? String(slide.layout).trim() : 'default';
    const body = String(slide?.body || '').trim();
    const notes = String(slide?.notes || '').trim();
    const bullets = normalizeArray(slide?.bullets)
      .map((item) => String(item || '').trim())
      .filter(Boolean);
    const imageRef = materializeSlideAsset(slide?.image_path || slide?.image_url, assetsDir, workspaceManager, userId);
    const slideLines = ['---'];
    if (layout !== 'default') slideLines.push(`layout: ${layout}`);
    if (slide?.className) slideLines.push(`class: ${JSON.stringify(String(slide.className).trim())}`);
    slideLines.push('---');
    if (title) slideLines.push(`# ${title}`);
    if (body) slideLines.push('', body);
    if (bullets.length > 0) {
      if (!body) slideLines.push('');
      slideLines.push(...bullets.map((item) => `- ${item}`));
    }
    if (imageRef) {
      slideLines.push('', `![](${imageRef})`);
    }
    if (notes) {
      slideLines.push('', `<!--\n${notes}\n-->`);
    }
    sections.push(slideLines.join('\n'));
  }

  return `${sections.join('\n\n')}\n`;
}

function buildDeckMarkdown(args, jobDir, workspaceManager, userId) {
  const rawMarkdown = String(args.deck_markdown || '').trim();
  if (rawMarkdown) {
    if (rawMarkdown.startsWith('---')) {
      return `${rawMarkdown}\n`;
    }
    return `${buildFrontmatter(args)}\n\n${rawMarkdown}\n`;
  }
  return buildStructuredDeckMarkdown(args, jobDir, workspaceManager, userId);
}

function resolveExportPath(jobDir, filenameBase, format) {
  if (format === 'png') {
    return path.join(jobDir, `${filenameBase}-png`);
  }
  return path.join(jobDir, `${filenameBase}.${format}`);
}

function collectPngArtifacts(outputDir) {
  if (!fs.existsSync(outputDir)) return [];
  return fs.readdirSync(outputDir)
    .filter((entry) => entry.toLowerCase().endsWith('.png'))
    .sort()
    .map((entry) => createArtifactDescriptor(path.join(outputDir, entry), {
      kind: 'image',
      label: entry,
      mimeType: 'image/png',
    }));
}

async function generateSlideDeck(args, context = {}) {
  if (!fs.existsSync(SLIDEV_BIN)) {
    throw new Error('Slidev CLI is not installed.');
  }
  const filenameBase = normalizeFilenameBase(args.filename_base || args.title || 'slide-deck', 'slide-deck');
  const workspaceManager = context.workspaceManager;
  const userId = context.userId;
  const jobDir = await createJobDir('slidev', filenameBase, workspaceManager, userId);
  ensureRepoNodeModulesLink(jobDir);
  const markdownPath = path.join(jobDir, `${filenameBase}.md`);
  const exportFormats = normalizeExportFormats(args.export_formats);
  const deckMarkdown = buildDeckMarkdown(args, jobDir, workspaceManager, userId);
  writeTextFile(markdownPath, deckMarkdown);

  const executor = context.cliExecutor;
  const commandOutputs = [];
  for (const format of exportFormats) {
    const outputPath = resolveExportPath(jobDir, filenameBase, format);
    const command = [
      shellEscape(SLIDEV_BIN),
      'export',
      shellEscape(markdownPath),
      '--format',
      shellEscape(format),
      '--output',
      shellEscape(outputPath),
    ].join(' ');
    const result = await runCheckedCommand(executor, command, {
      cwd: jobDir,
      timeout: 15 * 60 * 1000,
      errorPrefix: `Slidev export failed for ${format}.`,
    });
    commandOutputs.push({ format, result });
  }

  const descriptors = [
    createArtifactDescriptor(markdownPath, {
      kind: 'document',
      label: path.basename(markdownPath),
      mimeType: 'text/markdown',
    }),
  ];

  for (const format of exportFormats) {
    const outputPath = resolveExportPath(jobDir, filenameBase, format);
    if (format === 'png') {
      descriptors.push(...collectPngArtifacts(outputPath));
      continue;
    }
    descriptors.push(createArtifactDescriptor(outputPath, {
      kind: format === 'pptx' ? 'slides' : 'document',
      label: path.basename(outputPath),
    }));
  }

  const promotedArtifacts = descriptors.map((descriptor) => (
    promoteArtifactDescriptor(descriptor, context.artifactStore, context.userId)
  ));

  return {
    success: true,
    tool: 'generate_slide_deck',
    title: String(args.title || '').trim() || null,
    exportFormats,
    artifacts: promotedArtifacts,
    message: `Generated slide deck with ${exportFormats.join(', ')} output.`,
    logs: commandOutputs.map((item) => ({
      format: item.format,
      durationMs: item.result.durationMs,
    })),
  };
}

module.exports = {
  generateSlideDeck,
};
