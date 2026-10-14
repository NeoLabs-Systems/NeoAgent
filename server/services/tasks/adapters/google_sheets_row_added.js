'use strict';

const { connectionConfig, requiredText, summaryParts } = require('./shared');

const MAX_ROWS_PER_RUN = 50;

function rowCountFingerprint(count) {
  return `sheet_rows:${String(count).padStart(9, '0')}`;
}

function rowCountOf(checkpoint) {
  const match = /^sheet_rows:(\d+)$/.exec(String(checkpoint || ''));
  return match ? Number(match[1]) : null;
}

// The checkpoint is the row count. Fewer rows than before only moves it, so
// rows added after a deletion still count as new.
module.exports = {
  type: 'google_sheets_row_added',
  label: 'Google Sheets Row Added',
  providerKey: 'google_workspace',
  appKey: 'sheets',
  configHint: '{ connectionId, spreadsheetId, range: A1 range of the table, e.g. "Sheet1!A:E" }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'google_workspace', 'sheets'),
      spreadsheetId: requiredText(config.spreadsheetId || config.spreadsheet_id, 200, 'Spreadsheet ID is required.'),
      range: requiredText(config.range, 200, 'Sheet range is required, for example Sheet1!A:E.'),
    };
  },
  summarize(config = {}) {
    return summaryParts('Google Sheets new rows', [config.range]);
  },
  poll: {
    intervalMinutes: 5,
    cursor: 'list',
    async fetchRows({ tool, config, checkpoint }) {
      const result = await tool('google_workspace_sheets_get_values', {
        spreadsheet_id: config.spreadsheetId,
        range: config.range,
      });
      const values = Array.isArray(result?.values) ? result.values : [];
      const previous = rowCountOf(checkpoint);
      const fingerprint = rowCountFingerprint(values.length);
      if (previous === null || values.length <= previous) {
        return [{ fingerprint, timestamp: new Date().toISOString(), silent: true }];
      }
      return [{
        fingerprint,
        timestamp: new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'google_sheets',
            event: 'rows_added',
            range: result.range || config.range,
            header: values[0] || [],
            firstRowNumber: previous + 1,
            rows: values.slice(previous, previous + MAX_ROWS_PER_RUN),
            addedCount: values.length - previous,
          },
        },
      }];
    },
  },
};
