'use strict';

// Media tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'generate_image',
    group: 'media', access: 'write', sideEffect: 'artifact', latencyClass: 'slow', repeatable: true,
    capabilities: ['image', 'generate', 'picture'],
    description: 'Generate an image from a description. Saves the image locally and returns the file path — send it via send_message with media_path to share it on WhatsApp, Discord, etc.',
    parameters: {
      type: 'object',
      properties: {
        prompt: { type: 'string', description: 'Detailed description of the image to generate' },
        n: { type: 'number', description: 'Number of images to generate (default 1, max 4)' }
      },
      required: ['prompt']
    }
  },
  {
    name: 'generate_table',
    group: 'media', access: 'write', sideEffect: 'artifact', latencyClass: 'local', repeatable: true, untrusted: false,
    capabilities: ['table', 'generate'],
    description: 'Format data into a markdown table. The resulting markdown will be returned to you. You MUST include it in your next message to the user so they can see it.',
    parameters: {
      type: 'object',
      properties: {
        markdown_table: { type: 'string', description: 'The complete markdown table structure' }
      },
      required: ['markdown_table']
    }
  },
  {
    name: 'generate_graph',
    group: 'media', access: 'write', sideEffect: 'artifact', latencyClass: 'local', repeatable: true, untrusted: false,
    capabilities: ['graph', 'chart', 'generate'],
    description: 'Generate a chart using Mermaid.js syntax. Returns the mermaid code block to you. You MUST include it in your next message to the user (via ```mermaid ... ```) so they can see it.',
    parameters: {
      type: 'object',
      properties: {
        mermaid_code: { type: 'string', description: 'The raw Mermaid JS syntax code (e.g. graph TD\\nA-->B)' }
      },
      required: ['mermaid_code']
    }
  },
  {
    name: 'analyze_image',
    group: 'media', access: 'read', stateScope: 'workspace', latencyClass: 'remote',
    capabilities: ['image', 'vision', 'analyze'],
    description: 'Analyze an image file using the best available vision-capable model. Use this to describe photos, read QR codes, extract text from screenshots, or answer visual questions.',
    fileArgs: ['image_path'],
    parameters: {
      type: 'object',
      properties: {
        image_path: { type: 'string', description: 'The image: a file in your workspace or an owned artifact' },
        question: { type: 'string', description: 'What to answer or describe about the image (default: describe the image in detail)' }
      },
      required: ['image_path']
    }
  },
  {
    name: 'transcribe_audio',
    group: 'media', access: 'read', stateScope: 'workspace', latencyClass: 'slow',
    capabilities: ['audio', 'transcribe', 'speech'],
    description: 'Transcribe speech in an audio file (for example a voice note or recording the user shared) with the configured speech-to-text provider.',
    fileArgs: ['audio_path'],
    parameters: {
      type: 'object',
      properties: {
        audio_path: { type: 'string', description: 'The audio: a file in your workspace or an owned artifact' }
      },
      required: ['audio_path']
    }
  },
  {
    name: 'ocr_extract',
    group: 'media', access: 'read', stateScope: 'workspace', latencyClass: 'remote',
    capabilities: ['image', 'ocr', 'text'],
    description: 'Extract raw text from an image locally using Tesseract OCR. This is faster and completely offline compared to analyze_image.',
    fileArgs: ['image_path'],
    parameters: {
      type: 'object',
      properties: {
        image_path: { type: 'string', description: 'The image: a file in your workspace or an owned artifact' }
      },
      required: ['image_path']
    }
  },
];
