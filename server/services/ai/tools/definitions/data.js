'use strict';

// Personal and social data tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'read_health_data',
    group: 'data', access: 'read', latencyClass: 'local', repeatable: true,
    capabilities: ['health', 'fitness', 'steps', 'sleep'],
    description: 'Read the user\'s synced mobile health data. Omit metric_type for a summary of all available metrics. With metric_type, returns an aggregate summary (total, avg, min, max over all stored data) plus the most recent individual records. Always report the summary figures — avoid listing every raw record.',
    parameters: {
      type: 'object',
      properties: {
        metric_type: { type: 'string', description: 'Metric to query. Canonical values: "steps" (also accepts: "step", "step_count"), "heart_rate" (also accepts: "heartbeat", "heartrate", "pulse", "bpm"), "sleep_session" (also accepts: "sleep"), "exercise_session" (also accepts: "exercise", "workout", "activity"), "weight" (also accepts: "body_weight"). Omit to see what is available.' },
        limit: { type: 'number', description: 'Max recent records to return (default 10, max 200). Use a small number unless the user explicitly asks for a full history.' }
      }
    }
  },
  {
    name: 'social_reach_status',
    group: 'data', access: 'read', latencyClass: 'remote', repeatable: true,
    capabilities: ['social', 'status'],
    policy: { external: true },
    description: 'List available Social Reach platforms, setup state, and active backend for social content access.',
    parameters: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'social_reach_read',
    group: 'data', access: 'read', latencyClass: 'remote', repeatable: true,
    capabilities: ['social', 'read', 'post'],
    policy: { external: true },
    description: 'Read a supported public social URL using NeoAgent Social Reach. Supports RSS/Atom, V2EX, Reddit, X posts, GitHub repositories, configured Xueqiu data, and social video links from YouTube, TikTok, Instagram/Reels, or X.',
    parameters: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'HTTP or HTTPS URL to read.' },
        platform: { type: 'string', description: 'Optional platform override such as rss, v2ex, reddit, x, github, social_video, youtube, tiktok, instagram, reels, or xueqiu.' },
        symbol: { type: 'string', description: 'Optional Xueqiu stock symbol when platform is xueqiu.' },
        limit: { type: 'number', description: 'Maximum number of feed/results/replies to return.' }
      }
    }
  },
  {
    name: 'social_reach_search',
    group: 'data', access: 'read', latencyClass: 'remote', repeatable: true,
    capabilities: ['social', 'search'],
    policy: { external: true },
    description: 'Search a supported Social Reach platform. Supports GitHub repositories, V2EX hot/node topics, Reddit posts, and configured Xueqiu stock search.',
    parameters: {
      type: 'object',
      properties: {
        platform: { type: 'string', description: 'Platform to search: github, v2ex, reddit, or xueqiu.' },
        query: { type: 'string', description: 'Search query. For V2EX, use "hot" or a node name.' },
        limit: { type: 'number', description: 'Maximum result count.' }
      },
      required: ['platform', 'query']
    }
  },
  {
    name: 'social_video_extract',
    egress: true,
    resultShape: 'video_extract',
    group: 'data', access: 'read', latencyClass: 'slow', exclusive: true,
    capabilities: ['social', 'video', 'extract'],
    description: 'Extract title, description, transcript, and one representative frame image from a public social video URL (YouTube, TikTok, Instagram, or X) without social API keys.',
    parameters: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'Public social video URL.' },
        include_frame: { type: 'boolean', description: 'Whether to return one representative frame image artifact (default true).' },
        force_stt: { type: 'boolean', description: 'Force speech-to-text fallback even if captions are present.' }
      },
      required: ['url']
    }
  },
];
