'use strict';

const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');
const { coerceStringList, ensureParentDir, summarizeFile } = require('./common');

const driveToolDefinitions = [
  {
    name: 'google_workspace_drive_search_files',
    description: 'List or search Drive files visible to the connected account.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Drive search query. Empty returns recent files.',
        },
        page_size: {
          type: 'number',
          description: 'Maximum files to return (default 10).',
        },
      },
    },
  },
  {
    name: 'google_workspace_drive_upload_file',
    description: 'Upload a local file to Google Drive.',
    parameters: {
      type: 'object',
      properties: {
        file_path: {
          type: 'string',
          description: 'Absolute local file path to upload.',
        },
        name: { type: 'string', description: 'Optional Drive file name override.' },
        mime_type: { type: 'string', description: 'Optional MIME type override.' },
        parent_ids: {
          type: 'array',
          items: { type: 'string' },
          description: 'Optional Drive folder IDs.',
        },
      },
      required: ['file_path'],
    },
  },
  {
    name: 'google_workspace_drive_download_file',
    description: 'Download a Drive file to a local destination.',
    parameters: {
      type: 'object',
      properties: {
        file_id: { type: 'string', description: 'Drive file ID.' },
        destination_path: {
          type: 'string',
          description: 'Absolute local file path to write.',
        },
      },
      required: ['file_id', 'destination_path'],
    },
  },
  {
    name: 'google_workspace_drive_export_file',
    description: 'Export a native Google file like Docs or Sheets to a local file.',
    parameters: {
      type: 'object',
      properties: {
        file_id: { type: 'string', description: 'Drive file ID.' },
        mime_type: {
          type: 'string',
          description: 'Export MIME type, e.g. application/pdf.',
        },
        destination_path: {
          type: 'string',
          description: 'Absolute local file path to write.',
        },
      },
      required: ['file_id', 'mime_type', 'destination_path'],
    },
  },
  {
    name: 'google_workspace_drive_create_share_link',
    description: 'Create a Drive sharing permission and return the resulting link.',
    parameters: {
      type: 'object',
      properties: {
        file_id: { type: 'string', description: 'Drive file ID.' },
        role: {
          type: 'string',
          description: 'Permission role, e.g. reader or writer.',
        },
        type: {
          type: 'string',
          description: 'Permission type, e.g. anyone or user.',
        },
        email_address: {
          type: 'string',
          description: 'Required when type=user.',
        },
      },
      required: ['file_id'],
    },
  },
];

async function validateExistingReadableFilePath(filePath) {
  const normalized = String(filePath || '').trim();
  if (!normalized) {
    throw new Error('file_path is required.');
  }
  if (normalized.split(/[\\/]+/).includes('..')) {
    throw new Error('file_path must not contain parent traversal segments.');
  }
  const resolved = path.resolve(normalized);
  const stats = await fs.promises.stat(resolved);
  if (!stats.isFile()) {
    throw new Error('file_path must point to a readable file.');
  }
  await fs.promises.access(resolved, fs.constants.R_OK);
  return resolved;
}

function requireNonEmptyString(value, label) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    throw new Error(`${label} is required.`);
  }
  return normalized;
}

function requireDestinationPath(value, label) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    throw new Error(`${label} is required.`);
  }
  return path.resolve(normalized);
}

async function executeDriveTool(toolName, args, auth) {
  const drive = google.drive({ version: 'v3', auth });

  switch (toolName) {
    case 'google_workspace_drive_search_files': {
      const response = await drive.files.list({
        q: String(args.query || '').trim() || undefined,
        pageSize: Math.max(1, Math.min(Number(args.page_size) || 10, 50)),
        orderBy: 'modifiedTime desc',
        fields:
          'files(id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,parents),nextPageToken',
      });
      const files = Array.isArray(response.data.files) ? response.data.files : [];
      return { count: files.length, files: files.map(summarizeFile) };
    }

    case 'google_workspace_drive_upload_file': {
      const filePath = await validateExistingReadableFilePath(args.file_path);
      const response = await drive.files.create({
        requestBody: {
          name: args.name || undefined,
          parents: coerceStringList(args.parent_ids),
        },
        media: {
          mimeType: args.mime_type || undefined,
          body: fs.createReadStream(filePath),
        },
        fields:
          'id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,parents',
      });
      return summarizeFile(response.data);
    }

    case 'google_workspace_drive_download_file': {
      const fileId = requireNonEmptyString(args.file_id, 'file_id');
      const destinationPath = requireDestinationPath(
        args.destination_path,
        'destination_path',
      );
      ensureParentDir(destinationPath);
      const response = await drive.files.get(
        { fileId, alt: 'media' },
        { responseType: 'arraybuffer' },
      );
      const data = Buffer.from(response.data);
      await fs.promises.writeFile(destinationPath, data);
      return {
        fileId,
        destinationPath,
        bytesWritten: data.byteLength,
      };
    }

    case 'google_workspace_drive_export_file': {
      const fileId = requireNonEmptyString(args.file_id, 'file_id');
      const mimeType = requireNonEmptyString(args.mime_type, 'mime_type');
      const destinationPath = requireDestinationPath(
        args.destination_path,
        'destination_path',
      );
      ensureParentDir(destinationPath);
      const response = await drive.files.export(
        {
          fileId,
          mimeType,
        },
        { responseType: 'arraybuffer' },
      );
      await fs.promises.writeFile(destinationPath, Buffer.from(response.data));
      return {
        fileId,
        destinationPath,
        mimeType,
      };
    }

    case 'google_workspace_drive_create_share_link': {
      const fileId = requireNonEmptyString(args.file_id, 'file_id');
      const type = requireNonEmptyString(args.type, 'type');
      if (type === 'user') {
        requireNonEmptyString(args.email_address, 'email_address');
      }
      await drive.permissions.create({
        fileId,
        requestBody: {
          role: String(args.role || 'reader'),
          type,
          ...(args.email_address
            ? { emailAddress: String(args.email_address) }
            : {}),
        },
      });
      const fileResponse = await drive.files.get({
        fileId,
        fields: 'id,name,webViewLink,webContentLink',
      });
      return summarizeFile(fileResponse.data);
    }

    default:
      return null;
  }
}

module.exports = {
  driveToolDefinitions,
  executeDriveTool,
};
