'use strict';

const { getTerminalEnv, TERMINAL_ENV_HOST } = require('../../../../utils/deployment');

// Workspace files tools: schemas plus the metadata the harness reads.

// These read the server's own disk. With a guest computer that is not where the
// agent's files are, so they would only ever report nothing.
const onServerDisk = () => getTerminalEnv() === TERMINAL_ENV_HOST;

module.exports = [
  {
    name: 'read_file',
    selection: 'coding',
    resultShape: 'file',
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['filesystem', 'read', 'code'],
    prerequisites: ['computer'],
    policy: { safe: true },
    whenToUse: ['instead of cat, head, or sed in the shell'],
    whenNotToUse: ['several files at once (read_files)', 'the content is already in this conversation'],
    description: 'Read one workspace file, or a line range of it. Without a range a long file stops after 400 lines; rangeShown and totalLines say where to continue.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Absolute or relative path inside the per-user workspace' },
        file_path: { type: 'string', description: 'Alias for path; accepted for compatibility with model tool calls' },
        start_line: { type: 'number', description: 'Starting line number (1-indexed, inclusive)' },
        end_line: { type: 'number', description: 'Ending line number (1-indexed, inclusive)' },
        line_start: { type: 'number', description: 'Alias for start_line; accepted for compatibility with model tool calls' },
        line_count: { type: 'number', description: 'Number of lines to read starting at start_line/line_start' },
        encoding: { type: 'string', description: 'File encoding (default utf-8)' }
      },
      required: []
    }
  },
  {
    name: 'read_files',
    resultShape: 'files',
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['filesystem', 'read', 'code'],
    prerequisites: ['computer'],
    whenToUse: ['two or more files or ranges whose paths you already know, in one call'],
    description: 'Read up to 8 workspace files or line ranges in one call. They share a size limit, so ask for ranges when the files are long.',
    parameters: {
      type: 'object',
      properties: {
        files: {
          type: 'array',
          description: 'Files to read. Each item may be a path string or an object with path/file_path plus optional start_line/end_line or line_start/line_count.',
          items: {
            oneOf: [
              { type: 'string', description: 'Path inside the per-user workspace' },
              {
                type: 'object',
                properties: {
                  path: { type: 'string', description: 'Absolute or relative path inside the per-user workspace' },
                  file_path: { type: 'string', description: 'Alias for path' },
                  start_line: { type: 'number', description: 'Starting line number (1-indexed, inclusive)' },
                  end_line: { type: 'number', description: 'Ending line number (1-indexed, inclusive)' },
                  line_start: { type: 'number', description: 'Alias for start_line' },
                  line_count: { type: 'number', description: 'Number of lines to read from start_line/line_start' },
                  encoding: { type: 'string', description: 'File encoding (default utf-8)' }
                },
                required: []
              }
            ]
          }
        },
        paths: {
          type: 'array',
          items: { type: 'string' },
          description: 'Convenience alias for reading whole files by path.'
        },
        encoding: { type: 'string', description: 'Default file encoding for items without encoding (default utf-8)' }
      },
      required: []
    }
  },
  {
    name: 'read_artifact',
    selection: 'always',
    resultShape: 'artifact',
    group: 'files', access: 'read', latencyClass: 'local',
    capabilities: ['artifact', 'read'],
    policy: { external: true },
    whenToUse: ['read the rest of a tool result that was cut, by line range'],
    description: 'Read an owned text artifact by stable artifact ID. Use this for ranged inspection of command-output logs and of tool results that were cut short (full_result.artifact_id), without rerunning the call. Binary artifacts return metadata only.',
    parameters: {
      type: 'object',
      properties: {
        artifact_id: { type: 'string', description: 'Owned artifact ID returned by a previous tool result' },
        start_line: { type: 'number', description: 'Starting line number (1-indexed, inclusive)' },
        end_line: { type: 'number', description: 'Ending line number (1-indexed, inclusive; at most 500 lines)' }
      },
      required: ['artifact_id']
    }
  },
  {
    name: 'write_file',
    selection: 'coding',
    group: 'files', access: 'write', sideEffect: 'workspace', stateScope: 'workspace', latencyClass: 'local', untrusted: false,
    capabilities: ['filesystem', 'write', 'create', 'code'],
    prerequisites: ['computer'],
    policy: { category: 'file_write' },
    whenToUse: ['create a new file, or replace one entirely'],
    whenNotToUse: ['changing part of an existing file (edit_file)'],
    description: 'Write or append content to a file, creating parent directories. Write the complete content: nothing is summarized or filled in for you.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'File path' },
        file_path: { type: 'string', description: 'Alias for path; accepted for compatibility with model tool calls' },
        content: { type: 'string', description: 'Content to write' },
        mode: { type: 'string', enum: ['write', 'append'], description: 'Write mode (default write)' }
      },
      required: ['content']
    }
  },
  {
    name: 'edit_file',
    selection: 'coding',
    group: 'files', access: 'write', sideEffect: 'workspace', stateScope: 'workspace', latencyClass: 'local', untrusted: false,
    capabilities: ['filesystem', 'edit', 'patch', 'code'],
    prerequisites: ['computer'],
    policy: { category: 'file_write' },
    whenToUse: ['any change to part of a file, instead of sed or rewriting it', 'several changes to one file: put them in one call'],
    description: 'Replace exact text in one file. Edits apply in order and all or nothing. Each oldText must match exactly one location unless replace_all is true; a failed match writes nothing and reports the nearby lines. Keep indentation exact.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'File path' },
        file_path: { type: 'string', description: 'Alias for path; accepted for compatibility with model tool calls' },
        edits: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              oldText: { type: 'string', description: 'The exact text to replace.' },
              newText: { type: 'string', description: 'The replacement text.' },
              old_text: { type: 'string', description: 'Alias for oldText' },
              new_text: { type: 'string', description: 'Alias for newText' },
              replace_all: { type: 'boolean', description: 'Replace every occurrence when oldText matches more than one location (default false).' }
            },
            required: []
          },
          description: 'Replacements to apply, all or none.'
        }
      },
      required: ['edits']
    }
  },
  {
    name: 'replace_file_range',
    resultShape: 'file_range',
    group: 'files', access: 'write', sideEffect: 'workspace', stateScope: 'workspace', latencyClass: 'local', untrusted: false,
    capabilities: ['filesystem', 'edit', 'code'],
    prerequisites: ['computer'],
    policy: { category: 'file_write' },
    description: 'Replace a 1-indexed inclusive line range in a workspace file. Use this when you know line numbers and exact-text edit_file would be brittle. Read the target range first, then replace only the intended lines.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'File path inside the per-user workspace' },
        file_path: { type: 'string', description: 'Alias for path; accepted for compatibility with model tool calls' },
        start_line: { type: 'number', description: 'Starting line number (1-indexed, inclusive)' },
        end_line: { type: 'number', description: 'Ending line number (1-indexed, inclusive)' },
        startLine: { type: 'number', description: 'Alias for start_line' },
        endLine: { type: 'number', description: 'Alias for end_line' },
        content: { type: 'string', description: 'Replacement content for the range. Empty string deletes the range.' }
      },
      required: ['content']
    }
  },
  {
    name: 'list_directory',
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['filesystem', 'list', 'folder'],
    prerequisites: ['computer'],
    policy: { safe: true },
    description: 'List workspace files and directories with metadata. Omit path to list the workspace root.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Directory path inside the workspace (default ".")' },
        recursive: { type: 'boolean', description: 'List recursively' },
        depth: { type: 'number', description: 'Maximum recursion depth (default 1, max 5)' }
      },
      required: []
    }
  },
  {
    name: 'search_files',
    selection: 'coding',
    resultShape: 'file_search',
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['filesystem', 'search', 'grep', 'code'],
    prerequisites: ['computer'],
    whenToUse: ['find code, a symbol, or a phrase, instead of grep or find in the shell'],
    whenNotToUse: ['the file is already known and only needs reading'],
    description: 'Search file contents with ripgrep or grep, skipping ignored and generated files. Returns matches grouped by file: a file is named on its first line only, and context lines are numbered like "13-". Lower-case queries ignore case.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'File or directory to search (default the workspace root)' },
        query: { type: 'string', description: 'Exact text to find, or a pattern when regex is true' },
        regex: { type: 'boolean', description: 'Treat query as a regular expression (default false)' },
        include: { type: 'string', description: 'Only files matching this glob, such as "*.js" or "src/**/*.ts"' },
        context: { type: 'number', description: 'Lines to show around each match (default 0, max 5)' },
        case_sensitive: { type: 'boolean', description: 'Override the case rule' },
        max_results: { type: 'number', description: 'Most matches to return (default 50, max 200)' },
        maxDepth: { type: 'number', description: 'Maximum directory depth' },
        maxFileSize: { type: 'number', description: 'Largest file to scan in bytes (default 1048576, ripgrep only)' }
      },
      required: ['query']
    }
  },
  {
    name: 'code_navigate',
    availableWhen: onServerDisk,
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['code', 'symbols', 'definition', 'references'],
    prerequisites: ['computer'],
    whenNotToUse: ['searching for text (search_files)'],
    description: 'Navigate source code by AST-derived JavaScript/TypeScript symbols or workspace-scoped semantic retrieval. Returns excerpts and line references instead of complete files.',
    parameters: {
      type: 'object',
      properties: {
        mode: { type: 'string', enum: ['structure', 'semantic'], description: 'Search mode.' },
        path: { type: 'string', description: 'Workspace file or directory.' },
        query: { type: 'string', description: 'Required for semantic mode.' },
        limit: { type: 'number', description: 'Maximum semantic results.' }
      },
      required: ['mode', 'path']
    }
  },
  {
    name: 'query_structured_data',
    availableWhen: onServerDisk,
    group: 'files', access: 'read', stateScope: 'workspace', latencyClass: 'local',
    capabilities: ['csv', 'json', 'sql', 'data'],
    prerequisites: ['computer'],
    description: 'Read workspace CSV, TSV, JSON, or SQLite data using format-aware parsers. SQLite statements must be read-only and parameters are bound separately.',
    parameters: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Workspace data file.' },
        sql: { type: 'string', description: 'Read-only SQLite query.' },
        parameters: { type: 'object', description: 'Named SQLite query parameters.' },
        columns: { type: 'array', items: { type: 'string' }, description: 'Columns to return for CSV, TSV, or JSON.' },
        equals: { type: 'object', description: 'Exact field filters for CSV, TSV, or JSON.' },
        limit: { type: 'number', description: 'Maximum rows, capped at 1000.' }
      },
      required: ['path']
    }
  },
  {
    name: 'workspace_rollback',
    group: 'files', access: 'write', sideEffect: 'workspace', stateScope: 'workspace', latencyClass: 'local', untrusted: false,
    capabilities: ['git', 'undo', 'rollback', 'restore', 'checkpoint'],
    prerequisites: ['computer'],
    policy: { category: 'file_write' },
    whenToUse: ['your changes made things worse and you cannot fix them forward'],
    description: 'Automatic rollback is disabled in shared workspaces because ownership of changes cannot be proven. Use repo_diff and correct specific edits forward.',
    parameters: { type: 'object', properties: {} },
  },
];
