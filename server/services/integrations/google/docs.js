'use strict';

const { google } = require('googleapis');

const docsToolDefinitions = [
  {
    name: 'google_workspace_docs_get_document',
    description: 'Read a Google Doc and return its plain-text content.',
    parameters: {
      type: 'object',
      properties: {
        document_id: { type: 'string', description: 'Google Docs document ID.' },
      },
      required: ['document_id'],
    },
  },
  {
    name: 'google_workspace_docs_create_document',
    description: 'Create a Google Doc, optionally with initial content.',
    parameters: {
      type: 'object',
      properties: {
        title: { type: 'string', description: 'Document title.' },
        initial_text: { type: 'string', description: 'Optional starter content.' },
      },
      required: ['title'],
    },
  },
  {
    name: 'google_workspace_docs_append_text',
    description: 'Append text to the end of a Google Doc.',
    parameters: {
      type: 'object',
      properties: {
        document_id: { type: 'string', description: 'Google Docs document ID.' },
        text: { type: 'string', description: 'Text to append.' },
      },
      required: ['document_id', 'text'],
    },
  },
  {
    name: 'google_workspace_docs_replace_text',
    description: 'Replace matching text throughout a Google Doc.',
    parameters: {
      type: 'object',
      properties: {
        document_id: { type: 'string', description: 'Google Docs document ID.' },
        search_text: { type: 'string', description: 'Text to search for.' },
        replace_text: { type: 'string', description: 'Replacement text.' },
      },
      required: ['document_id', 'search_text', 'replace_text'],
    },
  },
];

function documentToText(document) {
  const content = Array.isArray(document.body?.content)
    ? document.body.content
    : [];
  return content
    .flatMap((block) =>
      Array.isArray(block.paragraph?.elements) ? block.paragraph.elements : [],
    )
    .map((element) => element.textRun?.content || '')
    .join('')
    .trim();
}

async function executeDocsTool(toolName, args, auth) {
  const docs = google.docs({ version: 'v1', auth });

  switch (toolName) {
    case 'google_workspace_docs_get_document': {
      const response = await docs.documents.get({
        documentId: String(args.document_id || ''),
      });
      return {
        documentId: response.data.documentId || String(args.document_id || ''),
        title: response.data.title || '',
        text: documentToText(response.data),
      };
    }

    case 'google_workspace_docs_create_document': {
      const createResponse = await docs.documents.create({
        requestBody: { title: String(args.title || '') },
      });
      const documentId = createResponse.data.documentId || '';
      if (args.initial_text) {
        await docs.documents.batchUpdate({
          documentId,
          requestBody: {
            requests: [
              {
                insertText: {
                  endOfSegmentLocation: {},
                  text: String(args.initial_text),
                },
              },
            ],
          },
        });
      }
      return {
        documentId,
        title: createResponse.data.title || String(args.title || ''),
      };
    }

    case 'google_workspace_docs_append_text': {
      await docs.documents.batchUpdate({
        documentId: String(args.document_id || ''),
        requestBody: {
          requests: [
            {
              insertText: {
                endOfSegmentLocation: {},
                text: String(args.text || ''),
              },
            },
          ],
        },
      });
      return { documentId: String(args.document_id || ''), appended: true };
    }

    case 'google_workspace_docs_replace_text': {
      const response = await docs.documents.batchUpdate({
        documentId: String(args.document_id || ''),
        requestBody: {
          requests: [
            {
              replaceAllText: {
                containsText: {
                  text: String(args.search_text || ''),
                  matchCase: true,
                },
                replaceText: String(args.replace_text || ''),
              },
            },
          ],
        },
      });
      const replies = Array.isArray(response.data.replies)
        ? response.data.replies
        : [];
      return {
        documentId: String(args.document_id || ''),
        occurrencesChanged: Number(
          replies[0]?.replaceAllText?.occurrencesChanged || 0,
        ),
      };
    }

    default:
      return null;
  }
}

module.exports = {
  docsToolDefinitions,
  executeDocsTool,
};
