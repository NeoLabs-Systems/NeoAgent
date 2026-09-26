'use strict';

// During research, Jev rates what a read brought back against the task:
// which search results probably lead to the needed information, and whether
// a fetched page actually holds it. The rating travels with the tool result,
// so the model opens the promising page first and moves on from a useless one
// instead of spending turns reading it.
const PAGE_CHARS = 12000;
const TASK_CHARS = 1500;
const TARGET_LIMIT = 8;

function pageText(toolName, args, result) {
  if (toolName === 'browser_navigate') return result.pageContent;
  if (toolName === 'browser_extract') {
    return Array.isArray(result.results) ? result.results.join('\n') : result.result;
  }
  if (toolName === 'http_request') {
    const method = String(args?.method || 'GET').toUpperCase();
    if (method !== 'GET') return '';
    return typeof result.body === 'string' ? result.body : JSON.stringify(result.body || '');
  }
  return '';
}

function buildResearchDecision({ task, targets = [], toolName, args, result }) {
  if (!result || typeof result !== 'object' || result.error) return null;
  const taskState = { task: String(task || '').slice(0, TASK_CHARS) };

  if (toolName === 'web_search') {
    const results = Array.isArray(result.results) ? result.results : [];
    if (results.length === 0) return null;
    return {
      state: {
        ...taskState,
        results: results.map(({ title, url, description }) => ({ title, url, description })),
      },
      questions: Object.fromEntries(results.map((_, index) => [
        `result_${index}`,
        {
          type: 'noul',
          instructions: `The page behind \`results[${index}]\` probably contains information that \`task\` needs.`,
        },
      ])),
    };
  }

  const text = String(pageText(toolName, args, result) || '').trim();
  if (!text) return null;
  const pageTargets = targets.slice(0, TARGET_LIMIT);
  const questions = {
    has_needed_info: {
      type: 'noul',
      instructions: '`page` contains at least part of the information that `task` needs.',
    },
    blocked_or_empty: {
      type: 'noul',
      instructions: '`page` is a login wall, cookie wall, bot check, error page, or has no real content.',
    },
  };
  pageTargets.forEach((target, index) => {
    questions[`target_${index}`] = {
      type: 'noul',
      instructions: `\`page\` contains the information \`task\` needs about \`targets[${index}]\`.`,
    };
  });
  return {
    state: { ...taskState, ...(pageTargets.length ? { targets: pageTargets } : {}), page: text.slice(0, PAGE_CHARS) },
    questions,
  };
}

function round(value) {
  return Math.round(value * 100) / 100;
}

// Search results come back sorted by the rating; a page gets a
// task_relevance summary. Both are placed first so compaction keeps them.
function applyResearchRating({ toolName, result, answers, targets = [] }) {
  if (toolName === 'web_search') {
    const results = result.results
      .map((item, index) => ({ task_relevance: round(answers[`result_${index}`].noul), ...item }))
      .sort((left, right) => right.task_relevance - left.task_relevance);
    return { ...result, results };
  }
  const rating = {
    has_needed_info: round(answers.has_needed_info.noul),
    blocked_or_empty: round(answers.blocked_or_empty.noul),
  };
  const pageTargets = targets.slice(0, TARGET_LIMIT);
  if (pageTargets.length) {
    rating.targets_covered = pageTargets.filter((_, index) => answers[`target_${index}`].noul >= 0.5);
    rating.targets_missing = pageTargets.filter((_, index) => answers[`target_${index}`].noul < 0.5);
  }
  return { task_relevance: rating, ...result };
}

module.exports = {
  applyResearchRating,
  buildResearchDecision,
};
