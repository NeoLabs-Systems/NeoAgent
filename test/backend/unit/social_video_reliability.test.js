'use strict';

const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const path = require('node:path');
const { test } = require('node:test');

const { SocialVideoService } = require('../../../server/services/social_video/service');

test('social video cancellation reaches dependency commands and is not shaped as success', async () => {
  const commandSignals = [];
  const service = new SocialVideoService({
    cliExecutor: {
      execute(_command, options) {
        commandSignals.push(options.signal);
        return new Promise((resolve) => {
          options.signal.addEventListener('abort', () => resolve({
            exitCode: null,
            stdout: '',
            stderr: '',
            aborted: true,
          }), { once: true });
        });
      },
    },
  });
  const controller = new AbortController();
  const reason = new Error('agent run stopped');
  const pending = service.extractFromUrl(
    1,
    'https://www.youtube.com/watch?v=abc123',
    { signal: controller.signal },
  );
  await new Promise((resolve) => setImmediate(resolve));
  controller.abort(reason);

  await assert.rejects(pending, (error) => error === reason);
  assert.equal(commandSignals.length, 2);
  assert.ok(commandSignals.every((signal) => signal === controller.signal));
});

test('social video obtains a keyless caption transcript when page metadata and ffmpeg are unavailable', async () => {
  const commands = [];
  let transcriberCalls = 0;
  const service = new SocialVideoService({
    publicResourceFetcher: async () => {
      throw new Error('public page blocked');
    },
    voiceTranscriber: async () => {
      transcriberCalls += 1;
      throw new Error('voice STT should not be called when captions are available');
    },
    cliExecutor: {
      async execute(command, options) {
        commands.push(command);
        if (command.includes(' --version')) {
          return { exitCode: 0, stdout: '2026.03.17', stderr: '' };
        }
        if (command.includes(' -version')) {
          return { exitCode: 127, stdout: '', stderr: 'ffmpeg unavailable' };
        }
        if (command.includes('--write-info-json')) {
          await fsp.writeFile(path.join(options.cwd, 'media.info.json'), JSON.stringify({
            id: 'caption-video',
            title: 'Caption video',
            description: 'Media metadata remains available.',
            duration: 42,
            webpage_url: 'https://www.youtube.com/watch?v=caption-video',
            subtitles: {},
            automatic_captions: {},
          }));
          return { exitCode: 0, stdout: '', stderr: '' };
        }
        if (command.includes('--write-auto-subs')) {
          await fsp.writeFile(
            path.join(options.cwd, 'captions.de.vtt'),
            'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nKeyless caption transcript',
          );
          return { exitCode: 0, stdout: '', stderr: '' };
        }
        throw new Error(`Unexpected command: ${command}`);
      },
    },
  });

  const health = await service.getHealthStatus();
  assert.equal(health.ready, true);
  assert.equal(health.dependencies.find((item) => item.name === 'ffmpeg').required, false);

  const result = await service.extractFromUrl(
    1,
    'https://www.youtube.com/watch?v=caption-video',
    { includeFrame: false },
  );

  assert.equal(result.platform, 'youtube');
  assert.equal(result.title, 'Caption video');
  assert.equal(result.transcript, 'Keyless caption transcript');
  assert.equal(result.transcriptSource, 'captions');
  assert.deepEqual(result.errors, []);
  assert.equal(transcriberCalls, 0);
  assert.ok(commands.some((command) => command.includes('--write-subs')));
  assert.ok(commands.some((command) => command.includes('--write-auto-subs')));
  assert.ok(commands.every((command) => !/api[-_ ]?key/i.test(command)));
  assert.ok(commands.every((command) => !command.includes('bestaudio/best')));
});

test('social video downloads audio and uses configured voice STT when keyless captions are unavailable', async () => {
  const commands = [];
  const transcriberCalls = [];
  const service = new SocialVideoService({
    publicResourceFetcher: async (url) => ({
      body: '<title>STT video</title>',
      finalUrl: url,
      headers: {},
      status: 200,
    }),
    voiceSettingsResolver: async () => ({
      provider: 'deepgram',
      model: 'nova-3',
    }),
    voiceTranscriber: async (filePath, options) => {
      transcriberCalls.push({ filePath, options });
      return 'Speech to text transcript';
    },
    cliExecutor: {
      async execute(command, options) {
        commands.push(command);
        if (command.includes(' --version') || command.includes(' -version')) {
          return { exitCode: 0, stdout: 'available', stderr: '' };
        }
        if (command.includes('--write-info-json')) {
          await fsp.writeFile(path.join(options.cwd, 'media.info.json'), JSON.stringify({
            id: 'stt-video',
            title: 'STT video',
            duration: 12,
            webpage_url: 'https://www.youtube.com/watch?v=stt-video',
            subtitles: {},
            automatic_captions: {},
          }));
          return { exitCode: 0, stdout: '', stderr: '' };
        }
        if (command.includes('--write-auto-subs')) {
          return { exitCode: 1, stdout: '', stderr: 'no subtitles available' };
        }
        if (command.includes('bestaudio/best')) {
          await fsp.writeFile(path.join(options.cwd, 'audio.mp3'), Buffer.from('audio'));
          return { exitCode: 0, stdout: '', stderr: '' };
        }
        throw new Error(`Unexpected command: ${command}`);
      },
    },
  });

  const result = await service.extractFromUrl(
    1,
    'https://www.youtube.com/watch?v=stt-video',
    { includeFrame: false },
  );

  assert.equal(result.transcript, 'Speech to text transcript');
  assert.equal(result.transcriptSource, 'stt');
  assert.equal(transcriberCalls.length, 1);
  assert.equal(transcriberCalls[0].options.provider, 'deepgram');
  assert.equal(transcriberCalls[0].options.model, 'nova-3');
  assert.equal(transcriberCalls[0].options.mimeType, 'audio/mpeg');
  assert.ok(commands.some((command) => command.includes('bestaudio/best')));
});
