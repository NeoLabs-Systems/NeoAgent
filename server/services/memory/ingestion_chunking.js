'use strict';

const crypto = require('node:crypto');

const TARGET_CHARS = 1400;
const MAX_CHARS = 2200;
const TARGET_SEGMENT_WORDS = 260;

const SEGMENT_TYPES = new Set([
  'Caption',
  'Footnote',
  'Formula',
  'ListItem',
  'Page',
  'PageFooter',
  'PageHeader',
  'Picture',
  'SectionHeader',
  'Table',
  'Text',
  'Title',
]);

const SEGMENT_ALIASES = Object.freeze({
  caption: 'Caption',
  footnote: 'Footnote',
  formula: 'Formula',
  listitem: 'ListItem',
  list_item: 'ListItem',
  'list item': 'ListItem',
  page: 'Page',
  pagefooter: 'PageFooter',
  page_footer: 'PageFooter',
  'page footer': 'PageFooter',
  pageheader: 'PageHeader',
  page_header: 'PageHeader',
  'page header': 'PageHeader',
  picture: 'Picture',
  image: 'Picture',
  figure: 'Picture',
  sectionheader: 'SectionHeader',
  section_header: 'SectionHeader',
  'section header': 'SectionHeader',
  table: 'Table',
  text: 'Text',
  title: 'Title',
});

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

function wordCount(text) {
  return (String(text || '').trim().match(/\S+/g) || []).length;
}

function normalizeSegmentType(value) {
  const raw = String(value || '').trim();
  if (SEGMENT_TYPES.has(raw)) return raw;
  return SEGMENT_ALIASES[raw.toLowerCase()] || 'Text';
}

function normalizeNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function normalizeBoundingBox(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const left = normalizeNumber(value.left ?? value.x ?? value.x1);
  const top = normalizeNumber(value.top ?? value.y ?? value.y1);
  const width = normalizeNumber(value.width ?? (
    value.x2 != null && left != null ? Number(value.x2) - left : null
  ));
  const height = normalizeNumber(value.height ?? (
    value.y2 != null && top != null ? Number(value.y2) - top : null
  ));
  if ([left, top, width, height].some((number) => number == null)) return null;
  return { left, top, width, height };
}

function segmentEmbedContent(segment) {
  return [
    segment.llm,
    segment.markdown,
    segment.html,
    segment.text,
    segment.content,
  ].map((value) => String(value || '').trim()).find(Boolean) || '';
}

function normalizeLayoutSegments(document) {
  const segments = Array.isArray(document?.payload?.segments)
    ? document.payload.segments
    : [];
  const normalized = [];
  for (const segment of segments) {
    if (!segment || typeof segment !== 'object' || Array.isArray(segment)) continue;
    const content = segmentEmbedContent(segment);
    if (!content) continue;
    const segmentType = normalizeSegmentType(segment.type || segment.segmentType || segment.segment_type);
    normalized.push({
      id: String(segment.id || segment.segmentId || segment.segment_id || '').trim() || null,
      type: segmentType,
      content,
      wordCount: wordCount(content),
      pageNumber: normalizeNumber(segment.pageNumber ?? segment.page_number),
      pageWidth: normalizeNumber(segment.pageWidth ?? segment.page_width),
      pageHeight: normalizeNumber(segment.pageHeight ?? segment.page_height),
      bbox: normalizeBoundingBox(segment.bbox || segment.boundingBox || segment.bounding_box),
      confidence: normalizeNumber(segment.confidence),
    });
  }
  return normalized;
}

function segmentHierarchyLevel(type) {
  if (type === 'Title') return 3;
  if (type === 'SectionHeader') return 2;
  return 1;
}

function isAssetType(type) {
  return type === 'Picture' || type === 'Table';
}

function hasAdjacentAssetCaptionPair(segments) {
  return segments.some((segment, index) => {
    const nextType = segments[index + 1]?.type;
    return (isAssetType(segment.type) && nextType === 'Caption')
      || (segment.type === 'Caption' && isAssetType(nextType));
  });
}

function findSegmentPosition(content, rendered, searchOffset) {
  const pos = content.indexOf(rendered, searchOffset);
  if (pos >= 0) return { charStart: pos, charEnd: pos + rendered.length };

  const compactRendered = String(rendered || '').replace(/\s+/g, ' ').trim();
  if (compactRendered && compactRendered.length <= 160) {
    const compactContent = content.replace(/\s+/g, ' ');
    const compactPos = compactContent.indexOf(compactRendered);
    if (compactPos >= 0) {
      return {
        charStart: Math.min(compactPos, content.length),
        charEnd: Math.min(compactPos + compactRendered.length, content.length),
      };
    }
  }

  return {
    charStart: Math.min(searchOffset, content.length),
    charEnd: Math.min(searchOffset + rendered.length, content.length),
  };
}

function metadataForSegments(segments, boundary = 'layout_segments') {
  const pageNumbers = [...new Set(
    segments.map((segment) => segment.pageNumber).filter((number) => number != null),
  )];
  const segmentTypes = [...new Set(segments.map((segment) => segment.type))];
  const resolvedBoundary = boundary === 'layout_segments' && hasAdjacentAssetCaptionPair(segments)
    ? 'asset_caption_pair'
    : boundary;
  return {
    boundary: resolvedBoundary,
    segmentTypes,
    segmentIds: segments.map((segment) => segment.id).filter(Boolean),
    segments: segments.map((segment) => ({
      id: segment.id,
      type: segment.type,
      pageNumber: segment.pageNumber,
      pageWidth: segment.pageWidth,
      pageHeight: segment.pageHeight,
      confidence: segment.confidence,
    })),
    pageNumbers,
    pages: pageNumbers,
    bboxes: segments
      .map((segment) => segment.bbox && {
        segmentId: segment.id,
        type: segment.type,
        pageNumber: segment.pageNumber,
        bbox: segment.bbox,
      })
      .filter(Boolean),
  };
}

function finalizeSegmentChunk(chunks, group, content, searchState, boundary = 'layout_segments') {
  if (!group.length) return;
  const rendered = group.map((segment) => segment.content).join('\n\n');
  const position = findSegmentPosition(content, rendered, searchState.offset);
  searchState.offset = Math.max(searchState.offset, position.charEnd);
  const metadata = metadataForSegments(group, boundary);
  for (const part of splitOversizedWithPos({
    content: rendered,
    charStart: position.charStart,
  })) {
    chunks.push({
      content: part.content,
      charStart: part.charStart,
      charEnd: Math.min(part.charEnd, position.charEnd),
      metadata,
    });
  }
}

function chunkLayoutSegments(document, content) {
  const segments = normalizeLayoutSegments(document);
  if (!segments.length) return null;

  const chunks = [];
  let group = [];
  let groupWordCount = 0;
  let previousHierarchyLevel = 1;
  const searchState = { offset: 0 };

  const finalize = (boundary = 'layout_segments') => {
    finalizeSegmentChunk(chunks, group, content, searchState, boundary);
    group = [];
    groupWordCount = 0;
  };

  for (let i = 0; i < segments.length; i += 1) {
    const segment = segments[i];
    if (segment.type === 'PageHeader' || segment.type === 'PageFooter') {
      continue;
    }

    const hierarchyLevel = segmentHierarchyLevel(segment.type);
    if (segment.type === 'Title' || segment.type === 'SectionHeader') {
      if (group.length && hierarchyLevel > previousHierarchyLevel) {
        finalize('section');
      }
      group.push(segment);
      groupWordCount += segment.wordCount;
      previousHierarchyLevel = hierarchyLevel;
      continue;
    }

    let keepWithNext = false;
    if (isAssetType(segment.type)) {
      keepWithNext = segments[i + 1]?.type === 'Caption';
    } else if (segment.type === 'Caption') {
      keepWithNext = isAssetType(segments[i + 1]?.type);
    }

    const nextSegment = keepWithNext ? segments[i + 1] : null;
    const pairedWordCount = segment.wordCount + (nextSegment?.wordCount || 0);
    const wouldOverflow = group.length && groupWordCount + pairedWordCount > TARGET_SEGMENT_WORDS;

    if (wouldOverflow) finalize('layout_segments');

    group.push(segment);
    groupWordCount += segment.wordCount;

    if (groupWordCount > TARGET_SEGMENT_WORDS && !keepWithNext) {
      finalize('layout_segments');
    }

    previousHierarchyLevel = hierarchyLevel;
  }

  finalize('layout_segments');

  return chunks.map((chunk, chunkIndex) => ({
    chunkIndex,
    charStart: chunk.charStart,
    charEnd: chunk.charEnd,
    content: chunk.content,
    contentHash: contentHash(chunk.content),
    metadata: chunk.metadata,
  }));
}

function chunkDocument(document) {
  const content = String(document?.content || '').trim();
  if (!content) return [];

  const layoutChunks = chunkLayoutSegments(document, content);
  if (layoutChunks) return layoutChunks;

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
