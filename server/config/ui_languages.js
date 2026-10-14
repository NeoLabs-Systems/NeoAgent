'use strict';

// Languages the client UI ships translations for. Also drives which locales'
// calendar and timezone names are recognized as non-entities in memory text.
const UI_LANGUAGE_CODES = new Set([
  'en', 'de', 'bg', 'hr', 'cs', 'da', 'nl', 'et', 'fi', 'fr', 'el', 'hu', 'ga', 'it', 'lv', 'lt', 'mt', 'pl', 'pt', 'ro', 'sk', 'sl', 'es', 'sv',
]);

module.exports = { UI_LANGUAGE_CODES };
