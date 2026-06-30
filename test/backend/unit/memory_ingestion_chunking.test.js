'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { chunkDocument } = require('../../../server/services/memory/ingestion_chunking');

test('chunkDocument preserves existing raw text chunking behavior', () => {
  const chunks = chunkDocument({
    sourceType: 'docs',
    title: 'Project notes',
    content: 'Intro paragraph.\n\nSecond paragraph.',
  });

  assert.equal(chunks.length, 1);
  assert.equal(chunks[0].content, 'Intro paragraph.\n\nSecond paragraph.');
  assert.equal(chunks[0].metadata.boundary, 'structural');
});

test('chunkDocument chunks layout segments by hierarchy and omits headers and footers', () => {
  const chunks = chunkDocument({
    sourceType: 'docs',
    title: 'Quarterly plan',
    content: [
      'Company header',
      'Quarterly Plan',
      'Goals',
      'Grow enterprise accounts.',
      'Risks',
      'Capacity is constrained.',
      'Page 1',
    ].join('\n'),
    payload: {
      segments: [
        { id: 'h1', type: 'PageHeader', text: 'Company header', pageNumber: 1 },
        { id: 't1', type: 'Title', text: 'Quarterly Plan', pageNumber: 1 },
        { id: 's1', type: 'SectionHeader', text: 'Goals', pageNumber: 1 },
        { id: 'p1', type: 'Text', text: 'Grow enterprise accounts.', pageNumber: 1 },
        { id: 's2', type: 'SectionHeader', text: 'Risks', pageNumber: 1 },
        { id: 'p2', type: 'Text', text: 'Capacity is constrained.', pageNumber: 1 },
        { id: 'f1', type: 'PageFooter', text: 'Page 1', pageNumber: 1 },
      ],
    },
  });

  assert.equal(chunks.length, 2);
  assert.match(chunks[0].content, /Quarterly Plan/);
  assert.match(chunks[0].content, /Grow enterprise accounts/);
  assert.match(chunks[1].content, /Risks/);
  assert.doesNotMatch(chunks.map((chunk) => chunk.content).join('\n'), /Company header|Page 1/);
  assert.deepEqual(chunks[0].metadata.segmentTypes, ['Title', 'SectionHeader', 'Text']);
  assert.deepEqual(chunks[0].metadata.pageNumbers, [1]);
});

test('chunkDocument keeps asset captions together and records layout provenance', () => {
  const chunks = chunkDocument({
    sourceType: 'files',
    title: 'Architecture PDF',
    content: [
      'Architecture Overview',
      'The service has three tiers.',
      'Figure 1. Request flow',
      'Diagram of the API, workers, and database.',
      'The database stores provenance.',
    ].join('\n'),
    payload: {
      segments: [
        { id: 'title', type: 'Title', text: 'Architecture Overview', pageNumber: 1 },
        { id: 'text-1', type: 'Text', text: 'The service has three tiers.', pageNumber: 1 },
        {
          id: 'cap-1',
          type: 'Caption',
          text: 'Figure 1. Request flow',
          pageNumber: 2,
          bbox: { left: 50, top: 420, width: 300, height: 24 },
        },
        {
          id: 'pic-1',
          type: 'Picture',
          text: 'Diagram of the API, workers, and database.',
          pageNumber: 2,
          bbox: { x1: 40, y1: 120, x2: 560, y2: 410 },
        },
        { id: 'text-2', type: 'Text', text: 'The database stores provenance.', pageNumber: 2 },
      ],
    },
  });

  const pictureChunk = chunks.find((chunk) => chunk.metadata.segmentIds.includes('pic-1'));
  assert.ok(pictureChunk);
  assert.match(pictureChunk.content, /Figure 1\. Request flow/);
  assert.match(pictureChunk.content, /Diagram of the API/);
  assert.deepEqual(pictureChunk.metadata.pageNumbers, [1, 2]);
  assert.equal(pictureChunk.metadata.bboxes.length, 2);
  assert.deepEqual(pictureChunk.metadata.bboxes[1].bbox, {
    left: 40,
    top: 120,
    width: 520,
    height: 290,
  });
});

test('chunkDocument falls back to raw text when segments are empty or malformed', () => {
  const chunks = chunkDocument({
    sourceType: 'docs',
    title: 'Fallback',
    content: 'Fallback content survives.',
    payload: {
      segments: [
        { type: 'Text', text: '' },
        null,
        'bad',
      ],
    },
  });

  assert.equal(chunks.length, 1);
  assert.equal(chunks[0].content, 'Fallback content survives.');
  assert.equal(chunks[0].metadata.boundary, 'structural');
});

test('chunkDocument splits oversized layout segments', () => {
  const longText = Array(1200).fill('word').join(' ');
  const chunks = chunkDocument({
    sourceType: 'docs',
    title: 'Long segment',
    content: longText,
    payload: {
      segments: [
        { id: 'long-1', type: 'Text', text: longText, pageNumber: 1 },
      ],
    },
  });

  assert.ok(chunks.length > 1);
  assert.ok(chunks.every((chunk) => chunk.content.length <= 2200));
  assert.ok(chunks.every((chunk) => chunk.metadata.segmentIds.includes('long-1')));
});
