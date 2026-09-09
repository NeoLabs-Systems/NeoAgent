'use strict';

const { FILES_APP } = require('./constants');

const FILE_TOOLS = Object.freeze([
  {
    name: 'nextcloud_list_files',
    access: 'read',
    description: 'List files and folders in a Nextcloud path. Omit path for the account root.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Folder path relative to the user root, for example Documents.' },
      },
    },
  },
  {
    name: 'nextcloud_search_files',
    access: 'read',
    description: 'Search Nextcloud files by name or content using unified search.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search text.' },
        limit: { type: 'number', description: 'Maximum results, default 20.' },
      },
      required: ['query'],
    },
  },
  {
    name: 'nextcloud_read_file',
    access: 'read',
    description: 'Read a small text file from Nextcloud. Use nextcloud_download_file for binary or large files.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'File path relative to the user root.' },
      },
      required: ['path'],
    },
  },
  {
    name: 'nextcloud_download_file',
    access: 'read',
    description: 'Download a Nextcloud file to a local destination path.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Remote Nextcloud file path.' },
        destination_path: { type: 'string', description: 'Absolute local file path to write.' },
      },
      required: ['path', 'destination_path'],
    },
  },
  {
    name: 'nextcloud_upload_file',
    access: 'write',
    description: 'Upload a local file into Nextcloud.',
    parameters: {
      type: 'object',
      properties: {
        file_path: { type: 'string', description: 'Absolute local file path to upload.' },
        path: { type: 'string', description: 'Destination Nextcloud path, including file name.' },
      },
      required: ['file_path', 'path'],
    },
  },
  {
    name: 'nextcloud_write_file',
    access: 'write',
    description: 'Create or overwrite a Nextcloud text file with the given content.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Destination Nextcloud path.' },
        content: { type: 'string', description: 'File contents to write.' },
      },
      required: ['path', 'content'],
    },
  },
  {
    name: 'nextcloud_mkdir',
    access: 'write',
    description: 'Create a Nextcloud folder.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Folder path to create.' },
      },
      required: ['path'],
    },
  },
  {
    name: 'nextcloud_move_file',
    access: 'write',
    description: 'Move or rename a Nextcloud file or folder.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Current Nextcloud path.' },
        destination: { type: 'string', description: 'New Nextcloud path.' },
        overwrite: { type: 'boolean', description: 'Overwrite an existing destination. Defaults to false.' },
      },
      required: ['path', 'destination'],
    },
  },
  {
    name: 'nextcloud_copy_file',
    access: 'write',
    description: 'Copy a Nextcloud file or folder.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Source Nextcloud path.' },
        destination: { type: 'string', description: 'Destination Nextcloud path.' },
        overwrite: { type: 'boolean', description: 'Overwrite an existing destination. Defaults to false.' },
      },
      required: ['path', 'destination'],
    },
  },
  {
    name: 'nextcloud_delete_file',
    access: 'write',
    description: 'Delete a Nextcloud file or folder. Deleted items go to trash when trash is enabled.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Nextcloud path to delete.' },
      },
      required: ['path'],
    },
  },
  {
    name: 'nextcloud_list_shares',
    access: 'read',
    description: 'List Nextcloud shares for the connected account, optionally filtered by path.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Optional file or folder path to filter shares.' },
      },
    },
  },
  {
    name: 'nextcloud_create_share',
    access: 'write',
    description: 'Create a Nextcloud share. share_type 3 is a public link, 0 is a user, 1 is a group.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'File or folder path to share.' },
        share_type: { type: 'number', description: 'Nextcloud share type. Defaults to 3 (public link).' },
        share_with: { type: 'string', description: 'User, group, or email for non-link shares.' },
        permissions: { type: 'number', description: 'Share permissions bitmask. Defaults to 1 (read).' },
        password: { type: 'string', description: 'Optional password for a public link.' },
        expire_date: { type: 'string', description: 'Optional expiration date YYYY-MM-DD.' },
        note: { type: 'string', description: 'Optional share note.' },
      },
      required: ['path'],
    },
  },
  {
    name: 'nextcloud_delete_share',
    access: 'write',
    description: 'Delete a Nextcloud share by share id.',
    parameters: {
      type: 'object',
      properties: {
        share_id: { type: 'string', description: 'Share id from nextcloud_list_shares.' },
      },
      required: ['share_id'],
    },
  },
  {
    name: 'nextcloud_list_trash',
    access: 'read',
    description: 'List items in the Nextcloud trash bin.',
    parameters: { type: 'object', properties: {} },
  },
  {
    name: 'nextcloud_restore_trash',
    access: 'write',
    description: 'Restore a Nextcloud trash item by the path returned from nextcloud_list_trash.',
    parameters: {
      type: 'object',
      properties: {
        trash_path: { type: 'string', description: 'Trash item path from nextcloud_list_trash.' },
      },
      required: ['trash_path'],
    },
  },
  {
    name: 'nextcloud_ocs_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Nextcloud OCS request under /ocs/v2.php/ for apps such as Notes or Deck. Talk messaging stays in Settings → Messaging.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
        path: { type: 'string', description: 'Path starting with /ocs/v2.php/.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional JSON request body.' },
      },
      required: ['method', 'path'],
    },
  },
].map((tool) => Object.freeze({ ...tool, appId: FILES_APP.id })));

module.exports = { FILE_TOOLS };
