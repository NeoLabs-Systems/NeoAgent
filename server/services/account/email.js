'use strict';

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function isValidEmail(value) {
  const email = normalizeEmail(value);
  return email.length <= 320
    && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    && !email.includes('..');
}

function requireValidEmail(value) {
  const email = normalizeEmail(value);
  if (!isValidEmail(email)) {
    const error = new Error('A valid email is required');
    error.statusCode = 400;
    throw error;
  }
  return email;
}

module.exports = {
  isValidEmail,
  normalizeEmail,
  requireValidEmail,
};
