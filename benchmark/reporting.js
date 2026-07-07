'use strict';

const path = require('node:path');
const sharp = require('sharp');
const { ensureDir, writeJson, writeText } = require('./utils');

function round(value, digits = 4) {
  return Number.isFinite(Number(value)) ? Number(Number(value).toFixed(digits)) : null;
}

function mostCommon(values) {
  const counts = new Map();
  for (const value of values) {
    if (!value) continue;
    counts.set(value, (counts.get(value) || 0) + 1);
  }
  let best = null;
  let bestCount = 0;
  for (const [value, count] of counts) {
    if (count > bestCount) {
      best = value;
      bestCount = count;
    }
  }
  return best;
}

function scoreGroup(rows) {
  const correct = rows.filter((row) => row.label === 'CORRECT').length;
  const wrong = rows.filter((row) => row.label === 'WRONG').length;
  const error = rows.filter((row) => row.label === 'ERROR').length;
  const total = rows.length;
  return {
    total,
    correct,
    wrong,
    error,
    // Errors count against accuracy rather than being excluded, so a broken run can't
    // look better than it is.
    accuracy: total ? round(correct / total) : null,
  };
}

function escapeXml(value) {
  return String(value || '').replace(/[<>&'"]/g, (character) => ({
    '<': '&lt;',
    '>': '&gt;',
    '&': '&amp;',
    '\'': '&apos;',
    '"': '&quot;',
  }[character]));
}

function buildBenchmarkSummary(rows, config) {
  const latencies = rows.map((row) => Number(row.latencyMs || 0)).filter((value) => value > 0);
  const totalTokens = rows.reduce((sum, row) => sum + (
    Number(row.answerUsage?.inputTokens || 0)
    + Number(row.answerUsage?.outputTokens || 0)
    + Number(row.judgeUsage?.inputTokens || 0)
    + Number(row.judgeUsage?.outputTokens || 0)
  ), 0);

  const categories = new Map();
  for (const row of rows) {
    const category = row.questionType || 'uncategorized';
    if (!categories.has(category)) categories.set(category, []);
    categories.get(category).push(row);
  }

  return {
    generatedAt: new Date().toISOString(),
    serverBaseUrl: config.serverBaseUrl,
    dataset: 'LoCoMo',
    answerModelId: mostCommon(rows.map((row) => row.answerModelId)),
    judgeModelId: mostCommon(rows.map((row) => row.judgeModelId)),
    totals: {
      ...scoreGroup(rows),
      averageLatencyMs: latencies.length ? round(latencies.reduce((sum, value) => sum + value, 0) / latencies.length, 0) : null,
      totalTokens,
    },
    categories: [...categories.entries()]
      .map(([questionType, categoryRows]) => ({ questionType, ...scoreGroup(categoryRows) }))
      .sort((left, right) => left.questionType.localeCompare(right.questionType)),
  };
}

function renderSummaryMarkdown(summary) {
  const lines = [
    '# NeoAgent LoCoMo Memory Benchmark',
    '',
    `Generated at: ${summary.generatedAt}`,
    `Target server: ${summary.serverBaseUrl}`,
    `Answer model: ${summary.answerModelId || 'n/a'}`,
    `Judge model: ${summary.judgeModelId || 'n/a'}`,
    '',
    '## Overall',
    '',
    `- Questions: ${summary.totals.total}`,
    `- Correct: ${summary.totals.correct}`,
    `- Wrong: ${summary.totals.wrong}`,
    `- Errors: ${summary.totals.error}`,
    `- Accuracy: ${summary.totals.accuracy == null ? 'n/a' : `${(summary.totals.accuracy * 100).toFixed(1)}%`}`,
    `- Average latency: ${summary.totals.averageLatencyMs == null ? 'n/a' : `${summary.totals.averageLatencyMs}ms`}`,
    `- Total tokens: ${summary.totals.totalTokens}`,
    '',
    '## By category',
    '',
    '| Category | Questions | Correct | Wrong | Errors | Accuracy |',
    '| --- | ---: | ---: | ---: | ---: | ---: |',
  ];

  for (const category of summary.categories) {
    lines.push(
      `| ${category.questionType} | ${category.total} | ${category.correct} | ${category.wrong} | `
      + `${category.error} | ${category.accuracy == null ? 'n/a' : `${(category.accuracy * 100).toFixed(1)}%`} |`,
    );
  }

  lines.push('');
  return `${lines.join('\n')}\n`;
}

function renderDashboardSvg(summary) {
  const width = 1440;
  const margin = 72;
  const headerY = 82;
  const metricsY = 198;
  const metricCardWidth = 306;
  const metricCardHeight = 126;
  const metricGap = 24;
  const barsY = metricsY + metricCardHeight + 72;
  const barHeight = 46;
  const barGap = 20;
  const emptyStateHeight = 136;
  const barsSectionHeight = summary.categories.length
    ? (summary.categories.length * barHeight) + ((summary.categories.length - 1) * barGap)
    : emptyStateHeight;
  const height = Math.max(760, barsY + barsSectionHeight + 90);
  const barMaxWidth = width - (margin * 2) - 260;

  const accuracyPct = summary.totals.accuracy == null ? null : Math.round(summary.totals.accuracy * 1000) / 10;
  const metrics = [
    { label: 'Questions', value: summary.totals.total, tone: '#d7e3ff' },
    { label: 'Correct', value: summary.totals.correct, tone: '#9ad18b' },
    { label: 'Wrong', value: summary.totals.wrong, tone: '#f6a68d' },
    { label: 'Accuracy', value: accuracyPct == null ? 'n/a' : `${accuracyPct}%`, tone: '#e7bf57' },
  ];

  const metricCards = metrics.map((metric, index) => {
    const x = margin + (index * (metricCardWidth + metricGap));
    return `
      <g transform="translate(${x} ${metricsY})">
        <rect width="${metricCardWidth}" height="${metricCardHeight}" rx="24" fill="rgba(8,14,27,0.74)" stroke="rgba(162,186,232,0.16)" />
        <text x="28" y="42" font-size="20" font-weight="600" fill="${metric.tone}">${escapeXml(metric.label)}</text>
        <text x="28" y="92" font-size="52" font-weight="800" fill="#f8fafc">${escapeXml(String(metric.value))}</text>
      </g>
    `;
  }).join('\n');

  const bars = summary.categories.map((category, index) => {
    const y = barsY + (index * (barHeight + barGap));
    const pct = category.accuracy == null ? 0 : category.accuracy;
    const barWidth = Math.max(4, Math.round(barMaxWidth * pct));
    const label = `${category.questionType} (${category.correct}/${category.total})`;
    return `
      <g transform="translate(${margin} ${y})">
        <text x="0" y="18" font-size="17" fill="#dce7ff">${escapeXml(label)}</text>
        <rect x="260" y="0" width="${barMaxWidth}" height="30" rx="8" fill="rgba(148,171,214,0.15)" />
        <rect x="260" y="0" width="${barWidth}" height="30" rx="8" fill="url(#line)" />
        <text x="${260 + barMaxWidth + 12}" y="22" font-size="17" font-weight="700" fill="#fff0bf">${category.accuracy == null ? 'n/a' : `${(category.accuracy * 100).toFixed(0)}%`}</text>
      </g>
    `;
  }).join('\n');

  const emptyState = summary.categories.length
    ? ''
    : `
      <g transform="translate(${margin} ${barsY})">
        <rect width="${width - (margin * 2)}" height="${emptyStateHeight}" rx="24" fill="rgba(7,12,24,0.68)" stroke="rgba(150,176,223,0.14)" />
        <text x="32" y="56" font-size="28" font-weight="700" fill="#f6f8ff">No questions scored yet</text>
        <text x="32" y="90" font-size="18" fill="#9eb0d0">Run "npm run benchmark:run" to populate this dashboard.</text>
      </g>
    `;

  const subtitle = summary.answerModelId
    ? `Answer: ${summary.answerModelId}  •  Judge: ${summary.judgeModelId || 'n/a'}`
    : 'No run yet';
  const runMeta = [
    `Generated ${summary.generatedAt}`,
    `Tokens ${summary.totals.totalTokens}`,
    summary.totals.averageLatencyMs == null ? 'Latency n/a' : `Avg latency ${summary.totals.averageLatencyMs}ms`,
  ].join('  •  ');

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#08111f" />
      <stop offset="52%" stop-color="#10243c" />
      <stop offset="100%" stop-color="#173b5d" />
    </linearGradient>
    <linearGradient id="line" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#6ee7f9" />
      <stop offset="50%" stop-color="#a3e635" />
      <stop offset="100%" stop-color="#facc15" />
    </linearGradient>
  </defs>
  <rect width="${width}" height="${height}" fill="url(#bg)" />
  <circle cx="1220" cy="96" r="190" fill="rgba(110,231,249,0.08)" />
  <circle cx="180" cy="${height - 110}" r="170" fill="rgba(250,204,21,0.08)" />

  <text x="${margin}" y="${headerY}" font-size="54" font-weight="800" fill="#ffffff">NeoAgent LoCoMo Memory Benchmark</text>
  <rect x="${margin}" y="${headerY + 20}" width="520" height="10" rx="5" fill="url(#line)" />
  <text x="${margin}" y="${headerY + 74}" font-size="22" fill="#d7e3ff">${escapeXml(subtitle)}</text>
  <text x="${margin}" y="${headerY + 108}" font-size="18" fill="#9eb0d0">${escapeXml(runMeta)}</text>

  ${metricCards}

  <text x="${margin}" y="${barsY - 20}" font-size="24" font-weight="700" fill="#f7fbff">Accuracy by category</text>

  ${bars}
  ${emptyState}
</svg>`;
}

async function writeReportArtifacts({ rows, config }) {
  const outputs = config.outputs;
  const summary = buildBenchmarkSummary(rows, config);
  const markdown = renderSummaryMarkdown(summary);
  const svg = renderDashboardSvg(summary);

  await Promise.all([
    ensureDir(path.dirname(outputs.resultsJsonPath)),
    ensureDir(path.dirname(outputs.dashboardPngPath)),
  ]);
  await writeJson(outputs.resultsJsonPath, rows);
  await writeJson(outputs.summaryJsonPath, summary);
  await writeText(outputs.summaryMarkdownPath, markdown);
  await sharp(Buffer.from(svg)).png().toFile(outputs.dashboardPngPath);

  return {
    summary,
    outputs,
  };
}

module.exports = {
  buildBenchmarkSummary,
  renderDashboardSvg,
  renderSummaryMarkdown,
  writeReportArtifacts,
};
