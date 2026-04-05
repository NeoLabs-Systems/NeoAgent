'use strict';

const { google } = require('googleapis');

const sheetsToolDefinitions = [
  {
    name: 'google_workspace_sheets_get_values',
    description: 'Read a range from a Google Sheet.',
    parameters: {
      type: 'object',
      properties: {
        spreadsheet_id: { type: 'string', description: 'Spreadsheet ID.' },
        range: {
          type: 'string',
          description: 'A1 notation range, e.g. Sheet1!A1:D10.',
        },
      },
      required: ['spreadsheet_id', 'range'],
    },
  },
  {
    name: 'google_workspace_sheets_update_values',
    description: 'Overwrite a range in a Google Sheet.',
    parameters: {
      type: 'object',
      properties: {
        spreadsheet_id: { type: 'string', description: 'Spreadsheet ID.' },
        range: { type: 'string', description: 'A1 notation range.' },
        values: {
          type: 'array',
          items: {
            type: 'array',
            items: { type: 'string' },
          },
          description: '2D values array.',
        },
      },
      required: ['spreadsheet_id', 'range', 'values'],
    },
  },
  {
    name: 'google_workspace_sheets_append_rows',
    description: 'Append rows to a Google Sheet range.',
    parameters: {
      type: 'object',
      properties: {
        spreadsheet_id: { type: 'string', description: 'Spreadsheet ID.' },
        range: {
          type: 'string',
          description: 'A1 notation range, e.g. Sheet1!A:C.',
        },
        rows: {
          type: 'array',
          items: {
            type: 'array',
            items: { type: 'string' },
          },
          description: 'Rows to append.',
        },
      },
      required: ['spreadsheet_id', 'range', 'rows'],
    },
  },
  {
    name: 'google_workspace_sheets_create_spreadsheet',
    description: 'Create a new Google Spreadsheet.',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Spreadsheet title.' },
        sheet_titles: {
          type: 'array',
          items: { type: 'string' },
          description: 'Optional sheet titles to create.',
        },
      },
      required: ['title'],
    },
  },
];

async function executeSheetsTool(toolName, args, auth) {
  const sheets = google.sheets({ version: 'v4', auth });

  switch (toolName) {
    case 'google_workspace_sheets_get_values': {
      const response = await sheets.spreadsheets.values.get({
        spreadsheetId: String(args.spreadsheet_id || ''),
        range: String(args.range || ''),
      });
      return {
        range: response.data.range || String(args.range || ''),
        majorDimension: response.data.majorDimension || 'ROWS',
        values: Array.isArray(response.data.values) ? response.data.values : [],
      };
    }

    case 'google_workspace_sheets_update_values': {
      const response = await sheets.spreadsheets.values.update({
        spreadsheetId: String(args.spreadsheet_id || ''),
        range: String(args.range || ''),
        valueInputOption: 'USER_ENTERED',
        requestBody: {
          values: Array.isArray(args.values) ? args.values : [],
        },
      });
      return {
        updatedRange: response.data.updatedRange || String(args.range || ''),
        updatedRows: response.data.updatedRows || 0,
        updatedColumns: response.data.updatedColumns || 0,
        updatedCells: response.data.updatedCells || 0,
      };
    }

    case 'google_workspace_sheets_append_rows': {
      const response = await sheets.spreadsheets.values.append({
        spreadsheetId: String(args.spreadsheet_id || ''),
        range: String(args.range || ''),
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
        requestBody: {
          values: Array.isArray(args.rows) ? args.rows : [],
        },
      });
      return {
        tableRange: response.data.tableRange || null,
        updates: response.data.updates || null,
      };
    }

    case 'google_workspace_sheets_create_spreadsheet': {
      const response = await sheets.spreadsheets.create({
        requestBody: {
          properties: { title: String(args.title || '') },
          sheets: Array.isArray(args.sheet_titles)
            ? args.sheet_titles
                .map((title) => String(title || '').trim())
                .filter(Boolean)
                .map((title) => ({ properties: { title } }))
            : undefined,
        },
      });
      return {
        spreadsheetId: response.data.spreadsheetId || null,
        spreadsheetUrl: response.data.spreadsheetUrl || null,
        title: response.data.properties?.title || String(args.title || ''),
      };
    }

    default:
      return null;
  }
}

module.exports = {
  executeSheetsTool,
  sheetsToolDefinitions,
};
