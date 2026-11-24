'use strict';

const PROVIDER_KEY = 'neocloud';
const APP = Object.freeze({
  id: 'files',
  label: 'NeoCloud',
  description: 'Read and manage files, create PDFs, and send documents for e-signature in a connected NeoCloud account.',
});
const SCOPES = Object.freeze(['files:read', 'files:write', 'signing:read', 'signing:write']);

const ITEM_ID = { type: 'string', description: 'NeoCloud file or folder ID, from neocloud_list_files or neocloud_search_files.' };
const REQUEST_ID = { type: 'string', description: 'Signature request ID, from neocloud_request_signatures or neocloud_list_signature_requests.' };
const CONTENT = {
  content: { type: 'string', description: 'UTF-8 text content (Markdown, plain text, CSV, JSON, ...).' },
  content_base64: { type: 'string', description: 'Base64 content for binary files. Use instead of content.' },
};

const TOOLS = Object.freeze([
  {
    name: 'neocloud_list_files',
    access: 'read',
    scope: 'files:read',
    description: 'List the files and folders in a NeoCloud folder. Paths are the user-visible paths, for example /Contracts. Omit path for the root. Returns each item\'s id, name, path, type, size, mimeType and modifiedAt. Files in encrypted vaults are never listed.',
    parameters: {
      type: 'object',
      properties: { path: { type: 'string', description: 'Folder path such as /Contracts. Defaults to /.' } },
    },
  },
  {
    name: 'neocloud_search_files',
    access: 'read',
    scope: 'files:read',
    description: 'Search NeoCloud files and folders by name. Use to find a file\'s id when the user names a file but not its folder.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search text, for example part of a file name.' },
        limit: { type: 'number', description: 'Maximum results, default 20.' },
      },
      required: ['query'],
    },
  },
  {
    name: 'neocloud_read_file',
    access: 'read',
    scope: 'files:read',
    description: 'Read a NeoCloud file\'s content by id. Text files up to 1 MB come back as UTF-8 (encoding "utf8"); other files up to 5 MB as base64 (encoding "base64"). Larger files are refused. Also returns the revision to pass as base_revision when updating.',
    parameters: { type: 'object', properties: { file_id: ITEM_ID }, required: ['file_id'] },
  },
  {
    name: 'neocloud_create_file',
    access: 'write',
    scope: 'files:write',
    description: 'Create a new file in NeoCloud at a full path such as /Notes/Ideas.md. Missing parent folders are created. Fails with ALREADY_EXISTS when the file exists unless overwrite is true. To change an existing file, prefer neocloud_update_file, which keeps version history.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Full file path including the name, for example /Notes/Ideas.md.' },
        ...CONTENT,
        overwrite: { type: 'boolean', description: 'Replace an existing file at path. Default false.' },
      },
      required: ['path'],
    },
  },
  {
    name: 'neocloud_update_file',
    access: 'write',
    scope: 'files:write',
    description: 'Replace the content of an existing NeoCloud file by id, saving a new version (older versions stay in the history). Pass base_revision from neocloud_read_file to avoid overwriting someone else\'s change; a stale revision fails with CONFLICT.',
    parameters: {
      type: 'object',
      properties: {
        file_id: ITEM_ID,
        ...CONTENT,
        base_revision: { type: 'string', description: 'Revision returned by neocloud_read_file.' },
      },
      required: ['file_id'],
    },
  },
  {
    name: 'neocloud_create_folder',
    access: 'write',
    scope: 'files:write',
    description: 'Create a NeoCloud folder at a full path such as /Projects/2026, including missing parents. Succeeds when the folder already exists.',
    parameters: {
      type: 'object',
      properties: { path: { type: 'string', description: 'Folder path, for example /Projects/2026.' } },
      required: ['path'],
    },
  },
  {
    name: 'neocloud_move_file',
    access: 'write',
    scope: 'files:write',
    description: 'Rename and/or move a NeoCloud file or folder by id. Set name to rename, parent_path to move into another folder, or both.',
    parameters: {
      type: 'object',
      properties: {
        file_id: ITEM_ID,
        name: { type: 'string', description: 'New name, including the extension for files.' },
        parent_path: { type: 'string', description: 'Destination folder path, for example /Archive.' },
      },
      required: ['file_id'],
    },
  },
  {
    name: 'neocloud_delete_file',
    access: 'write',
    scope: 'files:write',
    description: 'Move a NeoCloud file or folder to the trash by id. It is never deleted permanently; the user can restore it from the trash in NeoCloud.',
    parameters: { type: 'object', properties: { file_id: ITEM_ID }, required: ['file_id'] },
  },
  {
    name: 'neocloud_create_pdf',
    access: 'write',
    scope: 'files:write',
    description: 'Write a document in Markdown and save it to NeoCloud as an A4 PDF. Supports headings, paragraphs, bold, italic, bulleted and numbered lists and horizontal rules (no tables or images). To have the document signed, use neocloud_request_signatures with document instead, which also adds the signature block.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Full PDF path, for example /Documents/Offer.pdf.' },
        title: { type: 'string', description: 'Document title shown in the PDF.' },
        markdown: { type: 'string', description: 'The document body in Markdown.' },
        overwrite: { type: 'boolean', description: 'Replace an existing file at path. Default false.' },
      },
      required: ['path', 'markdown'],
    },
  },
  {
    name: 'neocloud_request_signatures',
    access: 'write',
    scope: 'signing:write',
    description: 'Send a document for e-signature with NeoCloud and get each signer\'s private signing link. Either write a contract from Markdown (document: path, title, markdown), which NeoCloud saves as a PDF with a signature block at the end, or use an existing PDF by file_id, which gets a signature page appended. Every signer gets a signature field, their printed name and the date. Signers need no NeoCloud account. Returns signers[].url: these links are private, each lets exactly that person sign, and they are only returned now, so give them to the user (for example to forward to a friend) and do not post them anywhere else. Leave send_email off unless the user asks NeoCloud to email the signers.',
    parameters: {
      type: 'object',
      properties: {
        document: {
          type: 'object',
          description: 'A new contract to write and save as PDF. Use instead of file_id.',
          properties: {
            path: { type: 'string', description: 'Where to save the PDF, for example /Contracts/Bike sale.pdf.' },
            title: { type: 'string', description: 'Contract title.' },
            markdown: { type: 'string', description: 'Contract text in Markdown (headings, paragraphs, bold, italic, lists). Do not add signature lines; NeoCloud adds the signature block.' },
          },
          required: ['path', 'title', 'markdown'],
        },
        file_id: { type: 'string', description: 'ID of an existing PDF in NeoCloud. Use instead of document.' },
        title: { type: 'string', description: 'Title of the signature request. Defaults to the document title.' },
        signers: {
          type: 'array',
          description: 'People who must sign, in signing order.',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Full name, printed under the signature.' },
              email: { type: 'string', description: 'Optional email, needed for send_email and reminders.' },
            },
            required: ['name'],
          },
        },
        message: { type: 'string', description: 'Optional note shown to signers.' },
        send_email: { type: 'boolean', description: 'Email the signing links to signers with an email. Default false.' },
        expires_in_days: { type: 'number', description: 'Days until the links expire.' },
        signing_order: { type: 'string', enum: ['parallel', 'sequential'], description: 'parallel (default): everyone can sign at once. sequential: one after another in list order.' },
      },
      required: ['signers'],
    },
  },
  {
    name: 'neocloud_list_signature_requests',
    access: 'read',
    scope: 'signing:read',
    description: 'List NeoCloud signature requests with their status and who has signed. Use to answer "has my friend signed yet?".',
    parameters: {
      type: 'object',
      properties: {
        status: { type: 'string', description: 'Optional status filter, for example pending, completed, cancelled or expired.' },
        limit: { type: 'number', description: 'Maximum results, default 20.' },
      },
    },
  },
  {
    name: 'neocloud_get_signature_request',
    access: 'read',
    scope: 'signing:read',
    description: 'Get one NeoCloud signature request with each signer\'s status and signedAt. Once completed it includes finalFileId, the signed PDF, which neocloud_read_file can read. Signing links are not included; use neocloud_new_signing_link for a fresh one.',
    parameters: { type: 'object', properties: { request_id: REQUEST_ID }, required: ['request_id'] },
  },
  {
    name: 'neocloud_remind_signers',
    access: 'write',
    scope: 'signing:write',
    description: 'Email a reminder to the signers who have not signed yet. Only works for signers with an email address and when NeoCloud can send mail; otherwise send the user a new link with neocloud_new_signing_link instead.',
    parameters: { type: 'object', properties: { request_id: REQUEST_ID }, required: ['request_id'] },
  },
  {
    name: 'neocloud_new_signing_link',
    access: 'write',
    scope: 'signing:write',
    description: 'Create a new private signing link for one signer; their old link stops working. Use when a link was lost or shared by mistake. Give the returned url to the user only.',
    parameters: {
      type: 'object',
      properties: {
        request_id: REQUEST_ID,
        signer_id: { type: 'string', description: 'Signer ID from the signature request.' },
      },
      required: ['request_id', 'signer_id'],
    },
  },
  {
    name: 'neocloud_cancel_signature_request',
    access: 'write',
    scope: 'signing:write',
    description: 'Cancel a pending NeoCloud signature request. All its signing links stop working.',
    parameters: { type: 'object', properties: { request_id: REQUEST_ID }, required: ['request_id'] },
  },
].map((tool) => Object.freeze({ ...tool, appId: APP.id })));

module.exports = { APP, PROVIDER_KEY, SCOPES, TOOLS };
