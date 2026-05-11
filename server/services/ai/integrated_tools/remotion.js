'use strict';

const path = require('path');
const {
  copyAssetIntoJob,
  createArtifactDescriptor,
  createJobDir,
  ensureDir,
  normalizeFilenameBase,
  promoteArtifactDescriptor,
  resolveRepoBinary,
  runCheckedCommand,
  shellEscape,
  writeJsonFile,
  writeTextFile,
} = require('./shared');

const REMOTION_BIN = resolveRepoBinary('remotion');
const ASPECT_RATIOS = {
  '16:9': { width: 1920, height: 1080 },
  '9:16': { width: 1080, height: 1920 },
  '1:1': { width: 1080, height: 1080 },
  '4:5': { width: 1080, height: 1350 },
};

function normalizeScene(scene = {}) {
  const durationSeconds = Math.max(1.5, Number(scene.duration_seconds ?? scene.durationSeconds) || 3);
  return {
    title: String(scene.title || '').trim(),
    body: String(scene.body || '').trim(),
    bullets: Array.isArray(scene.bullets)
      ? scene.bullets.map((item) => String(item || '').trim()).filter(Boolean).slice(0, 5)
      : [],
    durationSeconds,
    accentColor: String(scene.accent_color || scene.accentColor || '#7dd3fc').trim() || '#7dd3fc',
    backgroundColor: String(scene.background_color || scene.backgroundColor || '#08111f').trim() || '#08111f',
    align: ['left', 'center', 'right'].includes(String(scene.align || '').trim())
      ? String(scene.align).trim()
      : 'left',
    imagePath: String(scene.image_path || '').trim(),
    imageUrl: String(scene.image_url || '').trim(),
  };
}

function normalizeProps(args, jobDir, workspaceManager, userId) {
  const assetsDir = ensureDir(path.join(jobDir, 'public', 'assets'));
  const scenes = (Array.isArray(args.scenes) ? args.scenes : [])
    .map(normalizeScene)
    .filter((scene) => scene.title || scene.body || scene.bullets.length > 0);
  if (scenes.length === 0) {
    throw new Error('generate_video_with_remotion requires a non-empty scenes array.');
  }

  const preparedScenes = scenes.map((scene, index) => {
    let imageSrc = scene.imageUrl || '';
    if (!imageSrc && scene.imagePath) {
      const asset = copyAssetIntoJob(scene.imagePath, assetsDir, `scene-${index + 1}`, workspaceManager, userId);
      imageSrc = `/assets/${asset.relativePath}`;
    }
    return {
      ...scene,
      imageSrc,
    };
  });

  let audioSrc = '';
  if (args.audio_path) {
    const asset = copyAssetIntoJob(args.audio_path, assetsDir, 'soundtrack', workspaceManager, userId);
    audioSrc = `/assets/${asset.relativePath}`;
  }

  return {
    title: String(args.title || 'NeoAgent video').trim(),
    subtitle: String(args.subtitle || '').trim(),
    style: String(args.style || 'editorial cinematic').trim(),
    fps: Math.max(12, Math.min(60, Number(args.fps) || 30)),
    aspectRatio: ASPECT_RATIOS[String(args.aspect_ratio || '').trim()] ? String(args.aspect_ratio).trim() : '16:9',
    scenes: preparedScenes,
    audioSrc,
  };
}

function buildRootFile() {
  return `const React = require('react');
const {registerRoot, Composition} = require('remotion');
const props = require('./props.json');
const {NeoAgentVideo} = require('./VideoComposition');

const sizes = {
  '16:9': {width: 1920, height: 1080},
  '9:16': {width: 1080, height: 1920},
  '1:1': {width: 1080, height: 1080},
  '4:5': {width: 1080, height: 1350},
};

const fps = Number(props.fps) || 30;
const sceneFrames = (props.scenes || []).map((scene) => Math.max(1, Math.round((Number(scene.durationSeconds) || 3) * fps)));
const durationInFrames = sceneFrames.reduce((sum, next) => sum + next, 0);
const size = sizes[props.aspectRatio] || sizes['16:9'];

const RemotionRoot = () => (
  React.createElement(
    React.Fragment,
    null,
    React.createElement(Composition, {
      id: 'NeoAgentVideo',
      component: NeoAgentVideo,
      durationInFrames,
      fps,
      width: size.width,
      height: size.height,
      defaultProps: props,
    }),
  )
);

registerRoot(RemotionRoot);
`;
}

function buildCompositionFile() {
  return `const React = require('react');
const {AbsoluteFill, Audio, Img, Sequence, interpolate, spring, useCurrentFrame, useVideoConfig} = require('remotion');

const FONT_STACK = 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';

const shellStyle = {
  position: 'relative',
  overflow: 'hidden',
  fontFamily: FONT_STACK,
  color: '#f8fafc',
  padding: 72,
};

const backdropStyle = {
  position: 'absolute',
  inset: 0,
  background: 'radial-gradient(circle at top left, rgba(125,211,252,0.28), transparent 34%), radial-gradient(circle at bottom right, rgba(168,85,247,0.18), transparent 40%)',
};

const cardStyle = {
  position: 'relative',
  marginTop: 40,
  borderRadius: 36,
  padding: '40px 44px',
  border: '1px solid rgba(255,255,255,0.14)',
  background: 'rgba(7, 14, 25, 0.68)',
  boxShadow: '0 28px 90px rgba(0,0,0,0.28)',
  backdropFilter: 'blur(18px)',
};

const SceneView = ({scene}) => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();
  const entrance = spring({frame, fps, config: {damping: 18, mass: 0.9}});
  const exitOpacity = interpolate(frame, [Math.max(0, durationInFrames - 18), durationInFrames], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const translateY = interpolate(entrance, [0, 1], [34, 0]);
  const textAlign = scene.align || 'left';

  return (
    React.createElement(AbsoluteFill, {
      style: {
        ...shellStyle,
        justifyContent: 'center',
        background: scene.backgroundColor || '#08111f',
        opacity: exitOpacity,
      },
    },
      React.createElement('div', {style: backdropStyle}),
      scene.imageSrc
        ? React.createElement(Img, {
            src: scene.imageSrc,
            style: {
              position: 'absolute',
              inset: 0,
              width: '100%',
              height: '100%',
              objectFit: 'cover',
              opacity: 0.18,
            },
          })
        : null,
      React.createElement('div', {
        style: {
          ...cardStyle,
          transform: \`translateY(\${translateY}px)\`,
          maxWidth: scene.imageSrc ? '62%' : '100%',
        },
      },
        React.createElement('div', {
          style: {
            width: 110,
            height: 8,
            borderRadius: 999,
            background: scene.accentColor || '#7dd3fc',
            marginBottom: 24,
          },
        }),
        React.createElement('h1', {
          style: {
            margin: 0,
            fontSize: 76,
            lineHeight: 1.02,
            letterSpacing: '-0.06em',
            textAlign,
          },
        }, scene.title || 'Scene'),
        scene.body
          ? React.createElement('p', {
              style: {
                margin: '20px 0 0 0',
                maxWidth: 900,
                fontSize: 32,
                lineHeight: 1.35,
                color: 'rgba(226,232,240,0.92)',
                textAlign,
              },
            }, scene.body)
          : null,
        scene.bullets && scene.bullets.length > 0
          ? React.createElement('ul', {
              style: {
                margin: '28px 0 0 0',
                paddingLeft: textAlign === 'center' ? 24 : 34,
                fontSize: 28,
                lineHeight: 1.45,
                color: 'rgba(226,232,240,0.88)',
              },
            }, scene.bullets.map((bullet, index) => React.createElement('li', {
              key: String(index),
              style: {marginBottom: 12},
            }, bullet)))
          : null,
      ),
      scene.imageSrc
        ? React.createElement('div', {
            style: {
              position: 'absolute',
              right: 72,
              bottom: 72,
              top: 72,
              width: '30%',
              borderRadius: 32,
              overflow: 'hidden',
              border: '1px solid rgba(255,255,255,0.16)',
              boxShadow: '0 22px 70px rgba(0,0,0,0.28)',
              transform: \`translateY(\${translateY * 0.7}px)\`,
            },
          },
            React.createElement(Img, {
              src: scene.imageSrc,
              style: {
                width: '100%',
                height: '100%',
                objectFit: 'cover',
              },
            }),
          )
        : null,
    )
  );
};

const NeoAgentVideo = (props) => {
  const fps = Number(props.fps) || 30;
  const scenes = Array.isArray(props.scenes) ? props.scenes : [];
  let cursor = 0;

  return (
    React.createElement(AbsoluteFill, {style: {backgroundColor: '#020617'}},
      props.audioSrc ? React.createElement(Audio, {src: props.audioSrc}) : null,
      scenes.map((scene, index) => {
        const durationInFrames = Math.max(1, Math.round((Number(scene.durationSeconds) || 3) * fps));
        const startFrom = cursor;
        cursor += durationInFrames;
        return React.createElement(Sequence, {
          key: String(index),
          from: startFrom,
          durationInFrames,
        }, React.createElement(SceneView, {scene}));
      }),
    )
  );
};

exports.NeoAgentVideo = NeoAgentVideo;
`;
}

async function generateVideoWithRemotion(args, context = {}) {
  if (!context.cliExecutor || typeof context.cliExecutor.execute !== 'function') {
    throw new Error('CLI executor is unavailable for Remotion rendering.');
  }
  const filenameBase = normalizeFilenameBase(args.filename_base || args.title || 'video', 'video');
  const workspaceManager = context.workspaceManager;
  const userId = context.userId;
  if (!workspaceManager || typeof workspaceManager.getToolingRoot !== 'function') {
    throw new Error('Workspace manager is unavailable for Remotion rendering.');
  }
  if (!((typeof userId === 'string' && userId.trim()) || (typeof userId === 'number' && Number.isInteger(userId) && userId > 0))) {
    throw new Error('Missing or invalid userId for Remotion rendering.');
  }
  const jobDir = await createJobDir('remotion', filenameBase, workspaceManager, userId);
  const entryPath = path.join(jobDir, 'index.js');
  const compositionPath = path.join(jobDir, 'VideoComposition.js');
  const propsPath = path.join(jobDir, 'props.json');
  const outputPath = path.join(jobDir, `${filenameBase}.mp4`);
  const props = normalizeProps(args, jobDir, workspaceManager, userId);
  const size = ASPECT_RATIOS[props.aspectRatio] || ASPECT_RATIOS['16:9'];
  const durationInFrames = props.scenes.reduce((sum, scene) => (
    sum + Math.max(1, Math.round(scene.durationSeconds * props.fps))
  ), 0);

  writeTextFile(entryPath, buildRootFile());
  writeTextFile(compositionPath, buildCompositionFile());
  writeJsonFile(propsPath, props);

  const command = [
    shellEscape(REMOTION_BIN),
    'render',
    shellEscape(entryPath),
    shellEscape('NeoAgentVideo'),
    shellEscape(outputPath),
    '--props',
    shellEscape(propsPath),
    '--codec',
    shellEscape('h264'),
    '--fps',
    shellEscape(String(props.fps)),
    '--width',
    shellEscape(String(size.width)),
    '--height',
    shellEscape(String(size.height)),
    '--duration',
    shellEscape(String(durationInFrames)),
    '--overwrite',
  ].join(' ');

  const result = await runCheckedCommand(context.cliExecutor, command, {
    cwd: jobDir,
    timeout: 20 * 60 * 1000,
    errorPrefix: 'Remotion render failed.',
  });

  const videoDescriptor = createArtifactDescriptor(outputPath, {
    kind: 'video',
    label: path.basename(outputPath),
    mimeType: 'video/mp4',
  });
  const promotedVideo = promoteArtifactDescriptor(videoDescriptor, context.artifactStore, context.userId);

  return {
    success: true,
    tool: 'generate_video_with_remotion',
    title: props.title,
    artifacts: [promotedVideo],
    message: 'Generated rendered video.',
    render: {
      aspectRatio: props.aspectRatio,
      fps: props.fps,
      durationInFrames,
      sceneCount: props.scenes.length,
      durationMs: result.durationMs,
    },
  };
}

module.exports = {
  generateVideoWithRemotion,
};
