'use strict';

const { coerceWritableText } = require('../../../workspace/text_edits');
const { searchWorkspace } = require('../../../workspace/code_search');
const { createWorkspaceShell } = require('../../../workspace/workspace_shell');

const READ_LINE_LIMIT = 400;
const READ_CHAR_LIMIT = 16000;
const READ_MANY_CHAR_LIMIT = 20000;
const MAX_READ_FILES = 8;

function firstStringArg(args = {}, names = []) {
  for (const name of names) {
    const value = args?.[name];
    if (typeof value === 'string' && value.trim()) return value;
  }
  return '';
}

function normalizeReadFileArgs(args = {}) {
  const startLine = args.start_line ?? args.line_start ?? args.startLine ?? args.lineStart;
  let endLine = args.end_line ?? args.line_end ?? args.endLine ?? args.lineEnd;
  const lineCount = args.line_count ?? args.lineCount;
  if (endLine == null && startLine != null && lineCount != null) {
    const start = Number(startLine);
    const count = Number(lineCount);
    if (Number.isInteger(start) && Number.isInteger(count) && count > 0) {
      endLine = start + count - 1;
    }
  }
  return {
    path: firstStringArg(args, ['path', 'file_path', 'filePath', 'filename']),
    encoding: args.encoding || 'utf-8',
    start_line: startLine,
    end_line: endLine,
  };
}

// A whole-file read of something long is rarely what was meant: it stops at a line
// limit and says where it stopped. An explicit range only answers to the size limit.
// Cuts land on line boundaries, so what is shown can be edited and continued from.
function boundedRead(result, { hasRange, charLimit }) {
  if (typeof result?.content !== 'string' || result.error) return result;
  if (result.content.includes('\0')) {
    return { path: result.path, binary: true, byteSize: result.byteSize, content: '[binary file: not shown]' };
  }
  const layerCut = result.content.endsWith('\n...[truncated]');
  const content = layerCut ? result.content.slice(0, -'\n...[truncated]'.length) : result.content;
  const lines = content.split('\n');
  // A final newline does not start another line.
  const lineCount = lines[lines.length - 1] === '' ? lines.length - 1 : lines.length;
  const start = result.rangeShown?.[0] ?? 1;
  const totalLines = result.totalLines ?? (layerCut ? undefined : lineCount);
  let kept = !hasRange && lineCount > READ_LINE_LIMIT ? READ_LINE_LIMIT : lines.length;
  let shown = lines.slice(0, kept).join('\n');
  if (shown.length > charLimit) {
    const end = shown.lastIndexOf('\n', charLimit);
    shown = end > 0 ? shown.slice(0, end) : shown.slice(0, charLimit);
    kept = shown.split('\n').length;
  }
  if (!layerCut && shown === content) return result;
  return {
    ...result,
    content: shown,
    truncated: true,
    rangeShown: [start, start + kept - 1],
    ...(totalLines === undefined ? {} : { totalLines }),
  };
}

const { rollbackWorkspace } = require('../../runtime/workspace_checkpoint');

const handlers = {
  async workspace_rollback(args, ctx) {
    const session = ctx.engine.getRunMeta(ctx.runId)?.session;
    if (!session) return { success: false, error: 'This run has no workspace checkpoint to go back to.' };
    return rollbackWorkspace(session);
  },

  async read_file(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, workspaceRoot } = ctx;
    try {
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    const normalizedArgs = normalizeReadFileArgs(args);
    if (!normalizedArgs.path) {
      return {
        error: 'read_file requires path or file_path. Keep source files in the workspace; for repository work clone or move the checkout into the workspace before using file tools.',
      };
    }
    const result = await workspace.readFile(userId, {
      ...normalizedArgs,
      deviceTarget,
      workspaceRoot,
    });
    return boundedRead(result, {
      hasRange: normalizedArgs.start_line != null || normalizedArgs.end_line != null,
      charLimit: READ_CHAR_LIMIT,
    });
    } catch (err) {
    return { error: err.message };
    }
  },

  async read_files(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, workspaceRoot } = ctx;
    try {
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    const entries = Array.isArray(args.files)
      ? args.files
      : (Array.isArray(args.paths) ? args.paths : []);
    if (!entries.length) {
      return { error: 'read_files requires a non-empty files or paths array.' };
    }
    const charLimit = Math.floor(READ_MANY_CHAR_LIMIT / Math.min(entries.length, MAX_READ_FILES));
    const results = await Promise.all(entries.slice(0, MAX_READ_FILES).map(async (entry, index) => {
      const fileArgs = typeof entry === 'string'
        ? { path: entry }
        : (entry && typeof entry === 'object' ? entry : {});
      const normalizedArgs = normalizeReadFileArgs({
        ...fileArgs,
        encoding: fileArgs.encoding || args.encoding || 'utf-8',
      });
      if (!normalizedArgs.path) {
        return {
          index,
          success: false,
          error: 'Each read_files item requires path or file_path.',
        };
      }
      const result = boundedRead(await workspace.readFile(userId, {
        ...normalizedArgs,
        deviceTarget,
        workspaceRoot,
      }), {
        hasRange: normalizedArgs.start_line != null || normalizedArgs.end_line != null,
        charLimit,
      });
      return {
        index,
        requestedPath: normalizedArgs.path,
        success: !result?.error,
        ...result,
      };
    }));
    return {
      success: results.every((result) => result.success !== false && !result.error),
      count: results.length,
      truncated: entries.length > MAX_READ_FILES,
      results,
    };
    } catch (err) {
    return { error: err.message };
    }
  },

  async read_artifact(args, ctx) {
    const { artifactStore, userId } = ctx;
    try {
    if (!artifactStore) return { error: 'Artifact store is unavailable.' };
    return artifactStore.readTextArtifact(userId, args.artifact_id, {
      startLine: args.start_line,
      endLine: args.end_line,
    });
    } catch (err) {
    return { error: err.message };
    }
  },

  async write_file(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, withFileDiagnostics, workspaceRoot } = ctx;
    try {
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    const targetPath = args.path || args.file_path;
    if (!targetPath) return { success: false, error: 'write_file requires path or file_path.' };
    if (args.content == null) {
      return { success: false, error: 'write_file requires a content argument; nothing was written.' };
    }
    return await withFileDiagnostics(await workspace.writeFile(userId, {
      path: targetPath,
      content: coerceWritableText(args.content),
      mode: args.mode,
      deviceTarget,
      workspaceRoot,
    }), targetPath);
    } catch (err) {
    return { error: err.message };
    }
  },

  async edit_file(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, withFileDiagnostics, workspaceRoot } = ctx;
    try {
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    const targetPath = args.path || args.file_path;
    if (!targetPath) return { success: false, error: 'edit_file requires path or file_path.' };
    const edits = Array.isArray(args.edits)
      ? args.edits.map((edit) => ({
        ...edit,
        oldText: edit?.oldText ?? edit?.old_text,
        newText: edit?.newText ?? edit?.new_text,
        replaceAll: (edit?.replaceAll ?? edit?.replace_all) === true,
      }))
      : [];
    return await withFileDiagnostics(await workspace.editFile(userId, {
      path: targetPath,
      edits,
      deviceTarget,
      workspaceRoot,
    }), targetPath);
    } catch (err) {
    return { error: err.message };
    }
  },

  async replace_file_range(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, withFileDiagnostics, workspaceRoot } = ctx;
    try {
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    if (typeof workspace.replaceFileRange !== 'function') {
      return { error: 'Workspace service does not support replace_file_range.' };
    }
    const targetPath = args.path || args.file_path;
    if (!targetPath) return { success: false, error: 'replace_file_range requires path or file_path.' };
    return await withFileDiagnostics(await workspace.replaceFileRange(userId, {
      path: targetPath,
      start_line: args.start_line ?? args.startLine,
      end_line: args.end_line ?? args.endLine,
      content: args.content,
      deviceTarget,
      workspaceRoot,
    }), targetPath);
    } catch (err) {
    return { error: err.message };
    }
  },

  async list_directory(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, workspaceRoot } = ctx;
    try {
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    return await workspace.listDirectory(userId, {
      path: args.path,
      depth: args.depth,
      recursive: args.recursive,
      deviceTarget,
      workspaceRoot,
    });
    } catch (err) {
    return { error: err.message };
    }
  },

  async search_files(args, ctx) {
    const { computerWorkspace, deviceTarget, userId, workspaceRoot } = ctx;
    try {
    const shell = await createWorkspaceShell(ctx);
    if (shell) return await searchWorkspace(shell, args);
    // No computer to run on, so only the server's own workspace can be searched.
    const workspace = computerWorkspace();
    if (!workspace) return { error: 'Workspace service is unavailable.' };
    return await workspace.searchFiles(userId, {
      path: args.path,
      query: args.query,
      include: args.include,
      maxDepth: args.maxDepth ?? args.max_depth,
      maxFileSize: args.maxFileSize ?? args.max_file_size,
      deviceTarget,
      workspaceRoot,
    });
    } catch (err) {
    return { error: err.message };
    }
  },

  async code_navigate(args, ctx) {
    const { app, userId } = ctx;
    const service = app?.locals?.codeNavigationService;
    if (!service) return { error: 'Code navigation service is unavailable.' };
    try {
    return await service.navigate(userId, args);
    } catch (err) {
    return { error: err.message };
    }
  },

  async query_structured_data(args, ctx) {
    const { app, userId } = ctx;
    const service = app?.locals?.structuredDataService;
    if (!service) return { error: 'Structured data service is unavailable.' };
    try {
    return service.query(userId, args);
    } catch (err) {
    return { error: err.message };
    }
  },
};

module.exports = { handlers };
