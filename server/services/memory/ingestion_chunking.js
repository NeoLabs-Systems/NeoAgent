'use strict';

const crypto = require('node:crypto');

const TARGET_CHARS = 1400;
const MAX_CHARS = 2200;

function contentHash(content) {
  return crypto.createHash('sha256').update(content).digest('hex');
}

function messageBlocks(document) {
  const messages = Array.isArray(document?.payload?.messages)
    ? document.payload.messages
    : [];
  return messages
    .map((message) => {
      const speaker = String(message.speaker || message.role || message.author || '').trim();
      const timestamp = String(message.timestamp || message.createdAt || '').trim();
      const content = String(message.content || message.text || message.body || '').trim();
      if (!content) return null;
      const prefix = [timestamp, speaker].filter(Boolean).join(' ');
      return {
        content,
        rendered: prefix ? `${prefix}\n${content}` : content,
        messageId: String(message.id || message.messageId || '').trim() || null,
      };
    })
    .filter(Boolean);
}

function rawStructuralBlocks(text) {
  return String(text || '')
    .replace(/\r\n?/g, '\n')
    .split(/\n{2,}|(?=^#{1,6}\s)/gm)
    .map((block) => block.trim())
    .filter(Boolean);
}

function rawEmailBlocks(text) {
  return String(text || '')
    .replace(/\r\n?/g, '\n')
    .split(/\n(?=On\s.*wrote:|\s*>\s|-----Original Message-----|________________________________)/g)
    .map((block) => block.trim())
    .filter(Boolean);
}

function rawCodeBlocks(text) {
  return String(text || '')
    .replace(/\r\n?/g, '\n')
    .split(/\n(?=(?:export\s+)?(?:class|function|const|let|var|import)\s)/g)
    .map((block) => block.trim())
    .filter(Boolean);
}

function findBlockPositions(originalContent, blocks) {
  let searchFrom = 0;
  return blocks.map((block) => {
    const pos = originalContent.indexOf(block, searchFrom);
    const charStart = pos >= 0 ? pos : searchFrom;
    const charEnd = charStart + block.length;
    searchFrom = charEnd;
    return { content: block, charStart, charEnd };
  });
}

function splitOversizedWithPos({ content, charStart }) {
  if (content.length <= MAX_CHARS) {
    return [{ content, charStart, charEnd: charStart + content.length }];
  }
  const parts = [];
  let offset = 0;
  while (offset < content.length) {
    const slice = content.slice(offset, offset + MAX_CHARS);
    parts.push({
      content: slice,
      charStart: charStart + offset,
      charEnd: charStart + offset + slice.length,
    });
    offset += MAX_CHARS;
  }
  return parts;
}

function packBlocksWithPositions(blocksWithPos) {
  const chunks = [];
  let group = [];
  let groupLen = 0;

  for (const bwp of blocksWithPos.flatMap(splitOversizedWithPos)) {
    const addLen = (groupLen ? 2 : 0) + bwp.content.length;
    if (group.length && groupLen + addLen > TARGET_CHARS) {
      chunks.push(group);
      group = [bwp];
      groupLen = bwp.content.length;
    } else {
      group.push(bwp);
      groupLen += addLen;
    }
  }
  if (group.length) chunks.push(group);

  return chunks.map((g) => ({
    content: g.map((b) => b.content).join('\n\n'),
    charStart: g[0].charStart,
    charEnd: g[g.length - 1].charEnd,
  }));
}

function chunkDocument(document) {
  const content = String(document?.content || '').trim();
  if (!content) return [];

  const messages = messageBlocks(document);
  if (messages.length) {
    let searchOffset = 0;
    return messages.map((message, chunkIndex) => {
      let charStart = content.indexOf(message.content, searchOffset);
      if (charStart < 0) charStart = searchOffset;
      const charEnd = Math.min(content.length, charStart + message.content.length);
      searchOffset = charEnd;
      return {
        chunkIndex,
        charStart,
        charEnd,
        content: message.rendered,
        contentHash: contentHash(message.rendered),
        metadata: {
          boundary: 'message',
          messageId: message.messageId,
        },
      };
    });
  }

  const sourceType = String(document?.sourceType || document?.normalizedType || '').toLowerCase();
  const title = String(document?.title || '').toLowerCase();

  let rawBlocks;
  let boundaryType;

  if (sourceType.includes('email') || title.endsWith('.eml') || title.includes('message')) {
    rawBlocks = rawEmailBlocks(content);
    boundaryType = 'email_thread';
  } else if (
    sourceType.includes('code') ||
    title.endsWith('.js') ||
    title.endsWith('.ts') ||
    title.endsWith('.py') ||
    title.endsWith('.java')
  ) {
    rawBlocks = rawCodeBlocks(content);
    boundaryType = 'code_structure';
  } else {
    rawBlocks = rawStructuralBlocks(content);
    boundaryType = 'structural';
  }

  const blocksWithPos = findBlockPositions(content, rawBlocks);
  const packed = packBlocksWithPositions(blocksWithPos);

  return packed.map((chunk, chunkIndex) => ({
    chunkIndex,
    charStart: chunk.charStart,
    charEnd: chunk.charEnd,
    content: chunk.content,
    contentHash: contentHash(chunk.content),
    metadata: { boundary: boundaryType },
  }));
}

function overlapWindowChunks(chunks) {
  if (chunks.length < 2) return [];
  return chunks.slice(0, -1).map((chunk, i) => {
    const next = chunks[i + 1];
    const combined = `${chunk.content}\n\n${next.content}`;
    return {
      chunkIndex: -(i + 1),
      charStart: chunk.charStart,
      charEnd: next.charEnd,
      content: combined.slice(0, MAX_CHARS * 2),
      contentHash: contentHash(combined),
      metadata: { boundary: 'overlap_window', baseChunkIndex: i },
    };
  });
}

module.exports = {
  chunkDocument,
  overlapWindowChunks,
};
