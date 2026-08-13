'use strict';

class ComputerWorkspaceClient {
  constructor(options = {}) {
    this.runtimeManager = options.runtimeManager;
  }

  #request(userId, method, pathname, body, options = {}) {
    return this.runtimeManager.requestComputer(userId, method, pathname, body, options);
  }

  async #readContent(userId, filePath) {
    const result = await this.#request(
      userId,
      'GET',
      `/workspace/files/content?path=${encodeURIComponent(String(filePath || ''))}`,
    );
    return {
      ...result,
      content: String(result.content || ''),
    };
  }

  async readFile(userId, options = {}) {
    try {
      const result = await this.#readContent(userId, options.path);
      let content = String(result.content || '');
      const lines = content.split('\n');
      const start = options.start_line == null ? 1 : Number(options.start_line);
      const end = options.end_line == null ? lines.length : Number(options.end_line);
      if (!Number.isInteger(start) || start < 1 || !Number.isInteger(end) || end < start) {
        return { error: 'Invalid line range.', path: result.path };
      }
      const range = lines.slice(start - 1, end);
      content = range.join('\n');
      return {
        path: `/home/neo/workspace/${result.path}`,
        content: content.length > 20000 ? `${content.slice(0, 20000)}\n...[truncated]` : content,
        byteSize: Number(result.size || Buffer.byteLength(content)),
        totalLines: lines.length,
        rangeShown: [start, Math.min(end, lines.length)],
      };
    } catch (error) {
      return { error: error.message, path: options.path || null };
    }
  }

  async writeFile(userId, options = {}) {
    try {
      let content = String(options.content ?? '');
      if (String(options.mode || '').toLowerCase() === 'append') {
        const current = await this.#readContent(userId, options.path);
        content = `${current.content}${content}`;
      }
      const result = await this.#request(userId, 'PUT', '/workspace/files/content', {
        path: options.path,
        content,
      });
      return { ...result, path: `/home/neo/workspace/${result.path}` };
    } catch (error) {
      return { success: false, error: error.message, path: options.path || null };
    }
  }

  async editFile(userId, options = {}) {
    let current;
    try {
      current = await this.#readContent(userId, options.path);
    } catch (error) {
      return { error: error.message, path: options.path || null };
    }
    let content = String(current.content || '');
    let modified = false;
    const report = [];
    for (const edit of Array.isArray(options.edits) ? options.edits : []) {
      if (typeof edit?.oldText !== 'string' || !content.includes(edit.oldText)) {
        report.push({ success: false, error: 'Target text not found.' });
        continue;
      }
      content = content.split(edit.oldText).join(String(edit.newText || ''));
      modified = true;
      report.push({ success: true });
    }
    if (!modified) return { success: false, report, path: current.path };
    const result = await this.writeFile(userId, { path: options.path, content });
    return { ...result, report };
  }

  async replaceFileRange(userId, options = {}) {
    let current;
    try {
      current = await this.#readContent(userId, options.path);
    } catch (error) {
      return { error: error.message, path: options.path || null };
    }
    const lines = String(current.content || '').split('\n');
    const start = Number(options.start_line ?? options.startLine);
    const end = Number(options.end_line ?? options.endLine ?? start);
    if (!Number.isInteger(start) || !Number.isInteger(end) || start < 1 || end < start) {
      return { success: false, error: 'Invalid line range.', path: current.path };
    }
    lines.splice(start - 1, end - start + 1, ...String(options.content ?? '').split('\n'));
    return this.writeFile(userId, { path: options.path, content: lines.join('\n') });
  }

  async listDirectory(userId, options = {}) {
    try {
      const result = await this.#request(
        userId,
        'GET',
        `/workspace/files?path=${encodeURIComponent(String(options.path || '.'))}`,
      );
      return {
        path: `/home/neo/workspace/${result.path || ''}`,
        entries: result.entries,
      };
    } catch (error) {
      return { error: error.message, entries: [] };
    }
  }

  async searchFiles(userId, options = {}) {
    try {
      return await this.#request(userId, 'POST', '/workspace/search', {
        path: options.path || '.',
        glob: options.glob || options.pattern || '',
        query: options.query || '',
        maxResults: options.max_results || options.maxResults || 100,
      });
    } catch (error) {
      return { error: error.message, results: [] };
    }
  }
}

module.exports = { ComputerWorkspaceClient };
