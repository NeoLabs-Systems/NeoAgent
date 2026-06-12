'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');
const { parseSync } = require('oxc-parser');
const db = require('../../db/database');
const {
  getEmbedding,
  cosineSimilarity,
  serializeEmbedding,
  deserializeEmbedding,
  keywordSimilarity,
} = require('../memory/embeddings');

const CODE_EXTENSIONS = new Set(['.js', '.cjs', '.mjs', '.jsx', '.ts', '.tsx']);

function lineAtOffset(content, offset) {
  return content.slice(0, Math.max(0, offset)).split('\n').length;
}

function declarationInfo(node) {
  const target = node?.type === 'ExportNamedDeclaration' || node?.type === 'ExportDefaultDeclaration'
    ? node.declaration
    : node;
  if (!target) return null;
  if (['FunctionDeclaration', 'ClassDeclaration', 'TSEnumDeclaration', 'TSInterfaceDeclaration', 'TSTypeAliasDeclaration'].includes(target.type)) {
    return { node: target, name: target.id?.name || 'default', type: target.type };
  }
  if (target.type === 'VariableDeclaration') {
    const first = target.declarations?.[0];
    if (first?.id?.name) return { node: target, name: first.id.name, type: target.type };
  }
  return null;
}

class CodeNavigationService {
  constructor(options = {}) {
    this.workspaceManager = options.workspaceManager;
  }

  lexical(userId, options = {}) {
    const root = this.workspaceManager.resolvePath(userId, options.path || '.', 'path');
    const query = String(options.query || '').trim();
    if (!query) throw new Error('query is required.');
    const args = ['--json', '--line-number', '--max-count', '100'];
    if (options.fixed !== false) args.push('--fixed-strings');
    if (options.include) args.push('--glob', String(options.include));
    args.push(query, root);
    const result = spawnSync('rg', args, { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
    if (result.error?.code === 'ENOENT') {
      return this.workspaceManager.searchFiles(userId, options);
    }
    const matches = String(result.stdout || '').split('\n').filter(Boolean).flatMap((line) => {
      try {
        const event = JSON.parse(line);
        if (event.type !== 'match') return [];
        const data = event.data;
        return [{
          path: path.relative(root, data.path.text).split(path.sep).join('/'),
          line: data.line_number,
          excerpt: String(data.lines.text || '').trim().slice(0, 1000),
          submatches: data.submatches.map((item) => ({ start: item.start, end: item.end })),
        }];
      } catch {
        return [];
      }
    });
    return { mode: 'lexical', count: matches.length, results: matches };
  }

  extractStructure(userId, options = {}) {
    const absolute = this.workspaceManager.resolvePath(userId, options.path || '', 'path');
    const content = fs.readFileSync(absolute, 'utf8');
    if (!CODE_EXTENSIONS.has(path.extname(absolute).toLowerCase())) {
      throw new Error('Structural parsing currently supports JavaScript and TypeScript files.');
    }
    const parsed = parseSync(absolute, content);
    const symbols = [];
    for (const entry of parsed.program?.body || []) {
      const info = declarationInfo(entry);
      if (!info) continue;
      const startLine = lineAtOffset(content, info.node.start);
      const endLine = lineAtOffset(content, info.node.end);
      symbols.push({
        name: info.name,
        type: info.type,
        startLine,
        endLine,
        excerpt: content.slice(info.node.start, Math.min(info.node.end, info.node.start + 1600)),
      });
    }
    return {
      mode: 'structure',
      path: absolute,
      parseErrors: (parsed.errors || []).map((error) => String(error.message || error)).slice(0, 20),
      symbols,
    };
  }

  async indexWorkspace(userId, options = {}) {
    const root = this.workspaceManager.resolvePath(userId, options.path || '.', 'path');
    const files = [];
    const walk = (dir) => {
      if (files.length >= 500) return;
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.name === 'node_modules' || entry.name === '.git' || entry.name.startsWith('.neoagent-')) continue;
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(fullPath);
        else if (entry.isFile() && CODE_EXTENSIONS.has(path.extname(entry.name).toLowerCase())) files.push(fullPath);
      }
    };
    walk(root);
    let indexed = 0;
    for (const file of files) {
      if (fs.statSync(file).size > 512 * 1024) continue;
      const structure = this.extractStructure(userId, { path: file });
      const relative = path.relative(this.workspaceManager._ensureWorkspaceRootSync(userId), file).split(path.sep).join('/');
      for (const symbol of structure.symbols) {
        const hash = crypto.createHash('sha256').update(symbol.excerpt).digest('hex');
        const existing = db.prepare(
          `SELECT id, content_hash FROM workspace_code_index
           WHERE user_id = ? AND path = ? AND symbol = ? AND start_line = ?`
        ).get(userId, relative, symbol.name, symbol.startLine);
        if (existing?.content_hash === hash) continue;
        const embedding = await getEmbedding(`${symbol.name}\n${symbol.excerpt}`);
        db.prepare(
          `INSERT INTO workspace_code_index (
            user_id, path, symbol, symbol_type, start_line, end_line, content, content_hash, embedding
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id, path, symbol, start_line) DO UPDATE SET
            symbol_type = excluded.symbol_type,
            end_line = excluded.end_line,
            content = excluded.content,
            content_hash = excluded.content_hash,
            embedding = excluded.embedding,
            updated_at = datetime('now')`
        ).run(
          userId,
          relative,
          symbol.name,
          symbol.type,
          symbol.startLine,
          symbol.endLine,
          symbol.excerpt,
          hash,
          embedding ? serializeEmbedding(embedding) : null,
        );
        indexed += 1;
      }
    }
    return { filesScanned: files.length, symbolsIndexed: indexed };
  }

  async semantic(userId, options = {}) {
    const query = String(options.query || '').trim();
    if (!query) throw new Error('query is required.');
    const indexStatus = await this.indexWorkspace(userId, options);
    const queryEmbedding = await getEmbedding(query);
    const rows = db.prepare(
      `SELECT path, symbol, symbol_type, start_line, end_line, content, embedding
       FROM workspace_code_index WHERE user_id = ?`
    ).all(userId);
    const limit = Math.min(Math.max(Number(options.limit || 12), 1), 50);
    const results = rows.map((row) => {
      const vector = deserializeEmbedding(row.embedding);
      const score = queryEmbedding && vector
        ? cosineSimilarity(queryEmbedding, vector)
        : keywordSimilarity(query, `${row.symbol || ''} ${row.content}`);
      return {
        path: row.path,
        symbol: row.symbol,
        symbolType: row.symbol_type,
        startLine: row.start_line,
        endLine: row.end_line,
        score,
        excerpt: row.content.slice(0, 1600),
      };
    }).filter((item) => item.score > 0).sort((a, b) => b.score - a.score).slice(0, limit);
    return { mode: 'semantic', indexStatus, count: results.length, results };
  }

  navigate(userId, options = {}) {
    const mode = String(options.mode || 'lexical');
    if (mode === 'structure') return this.extractStructure(userId, options);
    if (mode === 'semantic') return this.semantic(userId, options);
    return this.lexical(userId, options);
  }
}

module.exports = {
  CodeNavigationService,
};
