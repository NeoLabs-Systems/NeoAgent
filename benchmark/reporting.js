'use strict';

const path = require('node:path');
const sharp = require('sharp');
const { ensureDir, writeJson, writeText } = require('./utils');

function round(value, digits = 3) {
  return Number.isFinite(Number(value))
    ? Number(Number(value).toFixed(digits))
    : null;
}

function resolveSummaryModelIds(results, config) {
  if (Array.isArray(config.selectedModels) && config.selectedModels.length > 0) {
    return config.selectedModels.map((model) => model.id);
  }
  return [...new Set(results.map((result) => result.modelId).filter(Boolean))];
}

function formatBenchmarkType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'first_party') return 'First-party';
  if (normalized === 'public') return 'Public';
  return normalized
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function buildBenchmarkSummary(results, config) {
  const suites = new Map();
  const totals = {
    cases: results.length,
    passed: 0,
    failed: 0,
    blocked: 0,
    skipped: 0,
    error: 0,
    score: 0,
    scoredCases: 0,
    latencyMs: 0,
    totalTokens: 0,
    estimatedCostUsd: 0,
    pricedCases: 0,
  };

  for (const result of results) {
    if (!suites.has(result.suiteId)) {
      suites.set(result.suiteId, {
        suiteId: result.suiteId,
        suiteLabel: result.suiteLabel,
        benchmarkType: result.benchmarkType,
        modelDriven: result.modelDriven === true,
        cases: 0,
        passed: 0,
        failed: 0,
        blocked: 0,
        skipped: 0,
        error: 0,
        score: 0,
        scoredCases: 0,
        totalTokens: 0,
        estimatedCostUsd: 0,
        pricedCases: 0,
      });
    }
    const suite = suites.get(result.suiteId);
    suite.cases += 1;
    if (Object.prototype.hasOwnProperty.call(suite, result.status)) {
      suite[result.status] += 1;
    }
    if (Object.prototype.hasOwnProperty.call(totals, result.status)) {
      totals[result.status] += 1;
    }
    if (Number.isFinite(result.score)) {
      suite.score += Number(result.score);
      suite.scoredCases += 1;
      totals.score += Number(result.score);
      totals.scoredCases += 1;
    }
    suite.totalTokens += Number(result.tokenUsage?.totalTokens || 0);
    totals.totalTokens += Number(result.tokenUsage?.totalTokens || 0);
    totals.latencyMs += Number(result.latencyMs || 0);
    if (Number.isFinite(result.estimatedCostUsd)) {
      suite.estimatedCostUsd += Number(result.estimatedCostUsd);
      suite.pricedCases += 1;
      totals.estimatedCostUsd += Number(result.estimatedCostUsd);
      totals.pricedCases += 1;
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    serverBaseUrl: config.serverBaseUrl,
    modelIds: resolveSummaryModelIds(results, config),
    totals: {
      ...totals,
      averageScore: totals.scoredCases ? round(totals.score / totals.scoredCases) : null,
      estimatedCostUsd: totals.pricedCases ? round(totals.estimatedCostUsd, 4) : null,
    },
    suites: [...suites.values()].map((suite) => ({
      ...suite,
      averageScore: suite.scoredCases ? round(suite.score / suite.scoredCases) : null,
      estimatedCostUsd: suite.pricedCases ? round(suite.estimatedCostUsd, 4) : null,
    })).sort((left, right) => left.suiteId.localeCompare(right.suiteId)),
  };
}

function renderSummaryMarkdown(summary) {
  const lines = [
    '# NeoAgent Benchmark Summary',
    '',
    `Generated at: ${summary.generatedAt}`,
    `Target server: ${summary.serverBaseUrl}`,
    summary.modelIds.length ? `Models: ${summary.modelIds.join(', ')}` : 'Models: model-independent suites only',
    '',
    '## Totals',
    '',
    `- Cases: ${summary.totals.cases}`,
    `- Passed: ${summary.totals.passed}`,
    `- Failed: ${summary.totals.failed}`,
    `- Blocked: ${summary.totals.blocked}`,
    `- Skipped: ${summary.totals.skipped}`,
    `- Errors: ${summary.totals.error}`,
    `- Average score: ${summary.totals.averageScore == null ? 'n/a' : summary.totals.averageScore}`,
    `- Total tokens: ${summary.totals.totalTokens}`,
    `- Estimated cost (USD): ${summary.totals.estimatedCostUsd == null ? 'n/a' : summary.totals.estimatedCostUsd}`,
    '',
    '## Suites',
    '',
    '| Suite | Type | Cases | Passed | Failed | Blocked | Avg score | Tokens | Cost (USD) |',
    '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
  ];

  for (const suite of summary.suites) {
    lines.push(
      `| ${suite.suiteLabel} | ${suite.benchmarkType} | ${suite.cases} | ${suite.passed} | ${suite.failed} | ${suite.blocked} | ${suite.averageScore == null ? 'n/a' : suite.averageScore} | ${suite.totalTokens} | ${suite.estimatedCostUsd == null ? 'n/a' : suite.estimatedCostUsd} |`,
    );
  }

  lines.push('');
  return `${lines.join('\n')}\n`;
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

function formatMetric(value, options = {}) {
  if (value == null || value === '') return options.fallback || 'n/a';
  const prefix = options.prefix || '';
  const suffix = options.suffix || '';
  return `${prefix}${value}${suffix}`;
}

function selectDashboardSuites(summary) {
  return summary.suites.filter((suite) => (suite.passed + suite.failed) > 0);
}

function renderDashboardSvg(summary) {
  const dashboardSuites = selectDashboardSuites(summary);
  const width = 1440;
  const margin = 72;
  const metricGap = 24;
  const metricCardWidth = 306;
  const metricCardHeight = 126;
  const suiteCardHeight = 108;
  const suiteGap = 18;
  const headerY = 82;
  const metricsY = 198;
  const suitesY = metricsY + metricCardHeight + 72;
  const footerHeight = 90;
  const emptyStateHeight = 136;
  const suiteSectionHeight = dashboardSuites.length
    ? (dashboardSuites.length * suiteCardHeight) + ((dashboardSuites.length - 1) * suiteGap)
    : emptyStateHeight;
  const height = Math.max(760, suitesY + suiteSectionHeight + footerHeight);
  const completedCases = summary.totals.passed + summary.totals.failed;
  const metrics = [
    {
      label: 'Completed cases',
      value: completedCases,
      accent: '#f8fafc',
      tone: '#d7e3ff',
    },
    {
      label: 'Passed',
      value: summary.totals.passed,
      accent: '#d7ffcc',
      tone: '#9ad18b',
    },
    {
      label: 'Failed',
      value: summary.totals.failed,
      accent: '#ffd3c2',
      tone: '#f6a68d',
    },
    {
      label: 'Average score',
      value: summary.totals.averageScore == null ? 'n/a' : summary.totals.averageScore,
      accent: '#fff0bf',
      tone: '#e7bf57',
    },
  ];

  const metricCards = metrics.map((metric, index) => {
    const x = margin + (index * (metricCardWidth + metricGap));
    return `
      <g transform="translate(${x} ${metricsY})">
        <rect width="${metricCardWidth}" height="${metricCardHeight}" rx="24" fill="rgba(8,14,27,0.74)" stroke="rgba(162,186,232,0.16)" />
        <text x="28" y="42" font-size="20" font-weight="600" fill="${metric.tone}">${escapeXml(metric.label)}</text>
        <text x="28" y="92" font-size="52" font-weight="800" fill="${metric.accent}">${escapeXml(String(metric.value))}</text>
      </g>
    `;
  }).join('\n');

  const suiteCards = dashboardSuites.map((suite, index) => {
    const y = suitesY + (index * (suiteCardHeight + suiteGap));
    return `
      <g transform="translate(${margin} ${y})">
        <rect width="${width - (margin * 2)}" height="${suiteCardHeight}" rx="22" fill="rgba(7,12,24,0.72)" stroke="rgba(150,176,223,0.14)" />
        <text x="28" y="37" font-size="26" font-weight="700" fill="#f8fbff">${escapeXml(suite.suiteLabel)}</text>
        <text x="28" y="66" font-size="16" fill="#9eb0d0">${escapeXml(formatBenchmarkType(suite.benchmarkType))}</text>

        <text x="640" y="34" font-size="16" fill="#8da0c5">Completed</text>
        <text x="640" y="64" font-size="28" font-weight="700" fill="#f0f5ff">${suite.passed + suite.failed}/${suite.cases}</text>

        <text x="820" y="34" font-size="16" fill="#8da0c5">Pass / fail</text>
        <text x="820" y="64" font-size="28" font-weight="700" fill="#d8ffe0">${suite.passed}<tspan fill="#ffd0c2"> / ${suite.failed}</tspan></text>

        <text x="1010" y="34" font-size="16" fill="#8da0c5">Score</text>
        <text x="1010" y="64" font-size="28" font-weight="700" fill="#fff0bf">${suite.averageScore == null ? 'n/a' : suite.averageScore}</text>
        <text x="1010" y="86" font-size="15" fill="#dce7ff">Tokens ${suite.totalTokens}</text>

        <text x="1205" y="34" font-size="16" fill="#8da0c5">Cost</text>
        <text x="1205" y="64" font-size="28" font-weight="700" fill="#f6f0d0">${escapeXml(formatMetric(suite.estimatedCostUsd, { prefix: '$' }))}</text>
      </g>
    `;
  }).join('\n');

  const emptyState = dashboardSuites.length
    ? ''
    : `
      <g transform="translate(${margin} ${suitesY})">
        <rect width="${width - (margin * 2)}" height="${emptyStateHeight}" rx="24" fill="rgba(7,12,24,0.68)" stroke="rgba(150,176,223,0.14)" />
        <text x="32" y="56" font-size="28" font-weight="700" fill="#f6f8ff">No completed suites yet</text>
        <text x="32" y="90" font-size="18" fill="#9eb0d0">Blocked, skipped, and error-only suites are intentionally omitted from the dashboard image.</text>
      </g>
    `;

  const subtitle = summary.modelIds.length
    ? summary.modelIds.join(', ')
    : 'Model-independent benchmark run';
  const runMeta = [
    `Generated ${summary.generatedAt}`,
    `Tokens ${summary.totals.totalTokens}`,
    `Cost ${formatMetric(summary.totals.estimatedCostUsd, { prefix: '$' })}`,
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

  <text x="${margin}" y="${headerY}" font-size="54" font-weight="800" fill="#ffffff">NeoAgent Benchmark Dashboard</text>
  <rect x="${margin}" y="${headerY + 20}" width="520" height="10" rx="5" fill="url(#line)" />
  <text x="${margin}" y="${headerY + 74}" font-size="22" fill="#d7e3ff">${escapeXml(subtitle)}</text>
  <text x="${margin}" y="${headerY + 108}" font-size="18" fill="#9eb0d0">${escapeXml(runMeta)}</text>

  ${metricCards}

  <text x="${margin}" y="${suitesY - 20}" font-size="24" font-weight="700" fill="#f7fbff">Completed suites</text>
  <text x="${margin + 188}" y="${suitesY - 20}" font-size="18" fill="#9eb0d0">Only suites with at least one passed or failed case are shown here.</text>

  ${suiteCards}
  ${emptyState}
</svg>`;
}

async function writeReportArtifacts({ results, config }) {
  const outputs = config.suitePaths.outputs;
  const summary = buildBenchmarkSummary(results, config);
  const markdown = renderSummaryMarkdown(summary);
  const svg = renderDashboardSvg(summary);

  await Promise.all([
    ensureDir(path.dirname(outputs.resultsJsonPath)),
    ensureDir(path.dirname(outputs.dashboardPngPath)),
  ]);
  await writeJson(outputs.resultsJsonPath, results);
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
