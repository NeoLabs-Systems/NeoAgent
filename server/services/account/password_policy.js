'use strict';

const MIN_PASSWORD_LENGTH = 8;
const MIN_PASSWORD_SCORE = 3;

const COMMON_PATTERNS = [
  'password',
  '123456',
  'qwerty',
  'letmein',
  'welcome',
  'admin',
  'neoagent',
];

function countMatches(password, pattern) {
  const match = String(password || '').match(pattern);
  return match ? match.length : 0;
}

function hasSequentialPattern(password) {
  const value = String(password || '').toLowerCase();
  const sequences = [
    'abcdefghijklmnopqrstuvwxyz',
    '0123456789',
    'qwertyuiopasdfghjklzxcvbnm',
  ];
  return sequences.some((sequence) => {
    for (let index = 0; index <= sequence.length - 4; index += 1) {
      const fragment = sequence.slice(index, index + 4);
      const reverse = fragment.split('').reverse().join('');
      if (value.includes(fragment) || value.includes(reverse)) {
        return true;
      }
    }
    return false;
  });
}

function hasRepeatedRuns(password) {
  return /(.)\1{2,}/.test(String(password || ''));
}

function normalizeContextValue(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function evaluatePasswordStrength(password, context = {}) {
  const value = String(password || '');
  const normalized = value.toLowerCase();
  const length = value.length;
  const lowerCount = countMatches(value, /[a-z]/g);
  const upperCount = countMatches(value, /[A-Z]/g);
  const digitCount = countMatches(value, /[0-9]/g);
  const symbolCount = countMatches(value, /[^A-Za-z0-9]/g);
  const uniqueChars = new Set(value).size;
  const varietyCount = [lowerCount, upperCount, digitCount, symbolCount]
    .filter((count) => count > 0)
    .length;

  const identifiers = [
    normalizeContextValue(context.username),
    normalizeContextValue(context.email),
    normalizeContextValue(String(context.email || '').split('@')[0]),
  ].filter((item) => item.length >= 3);

  const containsPersonalInfo = identifiers.some((item) => normalized.includes(item));
  const usesCommonPattern = COMMON_PATTERNS.some((item) => normalized.includes(item));
  const sequential = hasSequentialPattern(value);
  const repeatedRuns = hasRepeatedRuns(value);

  let score = 0;
  if (length >= MIN_PASSWORD_LENGTH) score += 1;
  if (length >= 12) score += 1;
  if (varietyCount >= 3) score += 1;
  if (varietyCount === 4 || length >= 16 || uniqueChars >= 10) score += 1;
  if (containsPersonalInfo || usesCommonPattern || sequential || repeatedRuns) {
    score -= 1;
  }
  score = Math.max(0, Math.min(4, score));

  const feedback = [];
  if (length < MIN_PASSWORD_LENGTH) {
    feedback.push(`Use at least ${MIN_PASSWORD_LENGTH} characters.`);
  } else if (length < 12) {
    feedback.push('A longer password is harder to guess.');
  }
  if (varietyCount < 3 && length < 16) {
    feedback.push('Mix uppercase, lowercase, numbers, or symbols.');
  }
  if (containsPersonalInfo) {
    feedback.push('Avoid using your username or email in the password.');
  }
  if (usesCommonPattern || sequential || repeatedRuns) {
    feedback.push('Avoid common words, repeated characters, or obvious sequences.');
  }
  if (feedback.length === 0 && score >= MIN_PASSWORD_SCORE) {
    feedback.push('Password looks strong.');
  }

  const label =
    score >= 4 ? 'strong'
      : score >= 3 ? 'good'
        : score >= 2 ? 'fair'
          : score >= 1 ? 'weak'
            : 'very weak';

  return {
    score,
    label,
    length,
    hasMinimumLength: length >= MIN_PASSWORD_LENGTH,
    isAcceptable: length >= MIN_PASSWORD_LENGTH && score >= MIN_PASSWORD_SCORE,
    feedback,
  };
}

function passwordStrengthError(result) {
  const details = Array.isArray(result?.feedback) ? result.feedback[0] : '';
  return details
    ? `Password is too weak. ${details}`
    : 'Password is too weak.';
}

module.exports = {
  MIN_PASSWORD_LENGTH,
  MIN_PASSWORD_SCORE,
  evaluatePasswordStrength,
  passwordStrengthError,
};
