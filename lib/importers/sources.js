'use strict';

// Finding OpenClaw and Hermes Agent on this computer, what each holds, and
// narrowing a bundle to the parts the user chose. Shared by `neoagent migrate`
// and the app's import screen.

const fs = require('fs');
const os = require('os');
const path = require('path');
const openclaw = require('./openclaw');
const hermes = require('./hermes');
const { PLATFORM_LABELS, isFile } = require('./common');

const READERS = {
  openclaw: { find: openclaw.findOpenClawHomes, scan: openclaw.scanOpenClaw },
  hermes: { find: hermes.findHermesHomes, scan: hermes.scanHermes },
};

const KEY_LABELS = {
  BRAVE_SEARCH_API_KEY: 'Brave Search',
  DEEPGRAM_API_KEY: 'Deepgram',
  ELEVENLABS_API_KEY: 'ElevenLabs',
  OLLAMA_URL: 'Ollama',
  OPENAI_COMPATIBLE_BASE_URL: 'Custom endpoint',
};

// What the user can leave out. Agents always come: everything else is
// attached to one.
const PARTS = ['keys', 'memories', 'skills', 'model', 'tasks', 'mcp', 'channels'];

// Left-behind notes that belong to a part, so leaving the part out also
// leaves out its notes.
const SKIPPED_KINDS = {
  keys: ['AI provider', 'Sign-in'],
  tasks: ['Automation'],
  mcp: ['MCP server'],
  channels: ['Channel'],
};

// --from <folder>: a copied or non-default installation. The folder's own
// files say which agent it belongs to.
function sourceKindOf(dir) {
  if (['openclaw.json', 'clawdbot.json', 'moltbot.json'].some((name) => isFile(path.join(dir, name)))) return 'openclaw';
  if (isFile(path.join(dir, 'config.yaml')) || fs.existsSync(path.join(dir, 'memories'))) return 'hermes';
  return null;
}

function scanSources(fromPath) {
  if (fromPath) {
    const dir = path.resolve(fromPath.replace(/^~(?=$|\/)/, os.homedir()));
    const kind = sourceKindOf(dir);
    if (!kind) throw new Error(`${dir} does not look like an OpenClaw or Hermes Agent folder.`);
    return [READERS[kind].scan(dir)];
  }
  return Object.values(READERS).flatMap((reader) => reader.find().map((home) => reader.scan(home)));
}

function keyLabel(envKey) {
  const { AI_PROVIDER_DEFINITIONS } = require('../../server/services/ai/provider_definitions');
  const definition = Object.values(AI_PROVIDER_DEFINITIONS).find((entry) => entry.envKey === envKey);
  return definition?.label || KEY_LABELS[envKey] || null;
}

// What a bundle holds, per part: [{ part, count, names, days? }]. Only parts
// with something in them; agents only when they are more than a nameless
// default.
function bundleContents(bundle) {
  const contents = [];
  const named = bundle.agents.filter((agent) => agent.instructions || !agent.isDefault);
  if (named.length) contents.push({ part: 'agents', count: bundle.agents.length, names: bundle.agents.map((agent) => agent.name) });
  const memories = bundle.agents.reduce((sum, agent) => sum + agent.memories.length + (agent.userProfile ? 1 : 0), 0);
  const days = bundle.agents.reduce((sum, agent) => sum + agent.dailyLogs.length, 0);
  if (memories || days) contents.push({ part: 'memories', count: memories, names: [], days });
  if (bundle.skills.length) contents.push({ part: 'skills', count: bundle.skills.length, names: bundle.skills.map((skill) => skill.name) });
  const keyNames = [...new Set(Object.keys(bundle.keys).map(keyLabel).filter(Boolean))];
  if (keyNames.length) contents.push({ part: 'keys', count: keyNames.length, names: keyNames });
  if (bundle.model) contents.push({ part: 'model', count: 1, names: [bundle.sourceModel] });
  if (bundle.tasks.length) contents.push({ part: 'tasks', count: bundle.tasks.length, names: bundle.tasks.map((task) => task.name) });
  if (bundle.mcp.length) contents.push({ part: 'mcp', count: bundle.mcp.length, names: bundle.mcp.map((server) => server.name) });
  if (bundle.channels.length) {
    const chats = bundle.channels.map((channel) => PLATFORM_LABELS[channel.platform]);
    contents.push({ part: 'channels', count: chats.length, names: chats });
  }
  return contents;
}

// A copy of the bundle holding only the chosen parts.
function selectParts(bundle, parts) {
  const keep = new Set(parts);
  const left = PARTS.filter((part) => !keep.has(part));
  const droppedKinds = new Set(left.flatMap((part) => SKIPPED_KINDS[part] || []));
  return {
    ...bundle,
    keys: keep.has('keys') ? bundle.keys : {},
    ignoredKeys: keep.has('keys') ? bundle.ignoredKeys : [],
    agents: bundle.agents.map((agent) => ({
      ...agent,
      ...(keep.has('memories') ? {} : { memories: [], userProfile: null, dailyLogs: [] }),
      ...(keep.has('model') ? {} : { model: null }),
    })),
    skills: keep.has('skills') ? bundle.skills : [],
    model: keep.has('model') ? bundle.model : null,
    tasks: keep.has('tasks') ? bundle.tasks : [],
    mcp: keep.has('mcp') ? bundle.mcp : [],
    channels: keep.has('channels') ? bundle.channels : [],
    skipped: bundle.skipped.filter((item) => !droppedKinds.has(item.kind)),
  };
}

module.exports = {
  PARTS,
  bundleContents,
  keyLabel,
  scanSources,
  selectParts,
};
