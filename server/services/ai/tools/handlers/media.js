'use strict';

const { analyzeImageForUser } = require('../../imageAnalysis');
const { transcribeFile } = require('../../../voice/voice_note');
const { resolveUserFileReference } = require('../../../files/user_file_access');
const { AI_PROVIDER_DEFINITIONS } = require('../../provider_definitions');
const { forRole: forNeoRouterRole } = require('../../neorouter/connection');
const neorouter = require('../../neorouter/client');

const handlers = {
  async generate_image(args, ctx) {
    const { agentId, artifactStore, signal, userId } = ctx;
    try {
    if (!artifactStore) {
      return { error: 'Artifact storage is unavailable.' };
    }
    const count = Math.min(args.n || 1, 4);
    const router = forNeoRouterRole(userId, agentId, 'images');
    let images;
    if (router) {
      images = await neorouter.generateImages(router, { prompt: args.prompt, n: count, signal });
    } else {
      const OpenAI = require('openai');
      const grokDefinition = AI_PROVIDER_DEFINITIONS.grok;
      const xai = new OpenAI({
       apiKey: process.env.XAI_API_KEY,
       baseURL: process.env.XAI_BASE_URL || grokDefinition.defaultBaseUrl,
      });
      const result = await xai.images.generate({
        model: 'grok-imagine-image',
        prompt: args.prompt,
        n: count,
        response_format: 'b64_json'
      });
      images = result.data.map((img) => img.b64_json);
    }
    const artifacts = [];
    for (const b64 of images) {
      const artifact = await artifactStore.createBufferArtifact(userId, {
        kind: 'generated-image',
        filenameBase: 'generated-image',
        extension: 'png',
        contentType: 'image/png',
        content: Buffer.from(b64, 'base64'),
      });
      artifacts.push({
        artifactId: artifact.artifactId,
        path: artifact.url,
      });
    }
    return {
      success: true,
      artifacts,
      paths: artifacts.map((artifact) => artifact.path),
      count: artifacts.length,
      message: `Generated ${artifacts.length} image(s). Use send_message with media_path to share.`,
    };
    } catch (err) {
    return { error: err.message };
    }
  },

  async generate_table(args) {
    return { result: args.markdown_table, instruction: 'Table generated. Please output this table directly to the user in your next message.' };
  },

  async generate_graph(args) {
    return { result: '```mermaid\n' + args.mermaid_code + '\n```', instruction: 'Graph generated. Please output this mermaid block directly to the user in your next message.' };
  },

  async analyze_image(args, ctx) {
    const { agentId, artifactStore, userId, wc } = ctx;
    try {
    const imagePath = resolveUserFileReference({
      userId,
      reference: args.image_path,
      artifactStore,
      workspaceManager: wc(),
      label: 'Image',
    });
    const result = await analyzeImageForUser({
      userId,
      agentId,
      imagePath,
      question: args.question || 'Describe this image in detail.',
    });
    return result;
    } catch (err) {
    return { error: err.message };
    }
  },

  async transcribe_audio(args, ctx) {
    const { agentId, artifactStore, signal, userId, wc } = ctx;
    try {
    const audioPath = resolveUserFileReference({
      userId,
      reference: args.audio_path,
      artifactStore,
      workspaceManager: wc(),
      label: 'Audio',
    });
    const transcript = await transcribeFile(audioPath, { userId, agentId, signal });
    return { transcript };
    } catch (err) {
    return { error: err.message };
    }
  },

  async ocr_extract(args, ctx) {
    const { artifactStore, userId, wc } = ctx;
    try {
    const imagePath = resolveUserFileReference({
      userId,
      reference: args.image_path,
      artifactStore,
      workspaceManager: wc(),
      label: 'OCR image',
    });
    const Tesseract = require('tesseract.js');
    const result = await Tesseract.recognize(imagePath, 'eng');
    return { text: result.data.text, confidence: result.data.confidence };
    } catch (err) {
    return { error: err.message };
    }
  },
};

module.exports = { handlers };
