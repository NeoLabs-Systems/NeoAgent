'use strict';

function normalizeMediaMode(value) {
  return String(value || '').trim().toLowerCase() === 'composed' ? 'composed' : 'auto';
}

function normalizeInputMode(value) {
  return String(value || '').trim().toLowerCase() === 'hands_free' ? 'hands_free' : 'ptt';
}

module.exports = {
  normalizeInputMode,
  normalizeMediaMode,
};
