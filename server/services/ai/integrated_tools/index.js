'use strict';

const { generateSlideDeck } = require('./slidev');
const { generateVideoWithRemotion } = require('./remotion');

function getIntegratedToolDefinitions() {
  return [
    {
      name: 'generate_slide_deck',
      description: 'Generate a polished presentation using Slidev and export finished artifacts. Prefer this for decks instead of raw file-writing. Best practice: pass a clear title and a complete slides array, and request export_formats ["pdf"] or ["pdf","pptx"] for a shareable final result.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Deck title.' },
          subtitle: { type: 'string', description: 'Optional deck subtitle or framing line.' },
          theme: { type: 'string', description: 'Slidev theme name. Defaults to "default".' },
          deck_markdown: { type: 'string', description: 'Optional full Slidev markdown deck. Use this when you want exact Slidev syntax control.' },
          slides: {
            type: 'array',
            description: 'Structured slide definitions. Use this for most decks if you do not need custom Slidev markdown.',
            items: {
              type: 'object',
              properties: {
                title: { type: 'string', description: 'Slide title.' },
                body: { type: 'string', description: 'Short narrative paragraph or statement.' },
                bullets: { type: 'array', items: { type: 'string' }, description: 'Bullet list for the slide.' },
                notes: { type: 'string', description: 'Presenter notes.' },
                image_url: { type: 'string', description: 'Optional remote image URL to embed.' },
                image_path: { type: 'string', description: 'Optional absolute local image path to embed.' },
                layout: { type: 'string', description: 'Optional Slidev layout, for example cover, section, statement, quote, or two-cols.' },
                className: { type: 'string', description: 'Optional Slidev class value.' },
              },
            },
          },
          export_formats: {
            type: 'array',
            items: { type: 'string', enum: ['pdf', 'pptx', 'png'] },
            description: 'Finished output formats. Defaults to ["pdf"].',
          },
          filename_base: { type: 'string', description: 'Optional output filename base.' },
        },
        required: ['title'],
      },
    },
    {
      name: 'generate_video_with_remotion',
      description: 'Generate a finished MP4 video using Remotion. Prefer this for explainers, launch videos, reels, and narrated visual summaries. Best practice: pass 3-10 scenes with explicit duration_seconds, concise on-screen text, and optional image_path or image_url assets.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Video title or opening headline.' },
          subtitle: { type: 'string', description: 'Optional supporting line.' },
          style: { type: 'string', description: 'High-level visual style direction.' },
          aspect_ratio: { type: 'string', enum: ['16:9', '9:16', '1:1', '4:5'], description: 'Video canvas aspect ratio. Defaults to 16:9.' },
          fps: { type: 'number', description: 'Frames per second. Defaults to 30.' },
          audio_path: { type: 'string', description: 'Optional absolute local path to a soundtrack or voiceover file.' },
          scenes: {
            type: 'array',
            description: 'Scene list in playback order.',
            items: {
              type: 'object',
              properties: {
                title: { type: 'string', description: 'Scene headline.' },
                body: { type: 'string', description: 'Supporting sentence or paragraph.' },
                bullets: { type: 'array', items: { type: 'string' }, description: 'Optional bullets to show in the scene.' },
                duration_seconds: { type: 'number', description: 'Scene duration in seconds.' },
                image_url: { type: 'string', description: 'Optional remote image URL.' },
                image_path: { type: 'string', description: 'Optional absolute local image path.' },
                accent_color: { type: 'string', description: 'Optional accent color, for example #7dd3fc.' },
                background_color: { type: 'string', description: 'Optional scene background color.' },
                align: { type: 'string', enum: ['left', 'center', 'right'], description: 'Text alignment.' },
              },
              required: ['title'],
            },
          },
          filename_base: { type: 'string', description: 'Optional output filename base.' },
        },
        required: ['title', 'scenes'],
      },
    },
  ];
}

async function executeIntegratedTool(toolName, args, context = {}) {
  switch (String(toolName || '').trim()) {
    case 'generate_slide_deck':
      return generateSlideDeck(args, context);
    case 'generate_video_with_remotion':
      return generateVideoWithRemotion(args, context);
    default:
      return null;
  }
}

module.exports = {
  executeIntegratedTool,
  getIntegratedToolDefinitions,
};
