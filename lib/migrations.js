const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { parseEnv } = require('../runtime/env');
const { ENV_FILE, AGENT_DATA_DIR, DATA_DIR } = require('../runtime/paths');

const HOME_DIR = os.homedir();

const OPENCLAW_PATHS = {
  config: path.join(HOME_DIR, '.openclaw', 'openclaw.json'),
  workspace: path.join(HOME_DIR, '.openclaw', 'workspace'),
  skills: path.join(HOME_DIR, '.openclaw', 'skills'),
  soul: path.join(HOME_DIR, '.openclaw', 'workspace', 'SOUL.md'),
  memory: path.join(HOME_DIR, '.openclaw', 'workspace', 'MEMORY.md'),
  user: path.join(HOME_DIR, '.openclaw', 'workspace', 'USER.md'),
  agents: path.join(HOME_DIR, '.openclaw', 'agents'),
  env: path.join(HOME_DIR, '.openclaw', '.env'),
  legacyConfig: path.join(HOME_DIR, '.clawdbot', 'config.json')
};

const HERMES_PATHS = {
  config: path.join(HOME_DIR, '.hermes', 'config.yaml'),
  env: path.join(HOME_DIR, '.hermes', '.env'),
  skills: path.join(HOME_DIR, '.hermes', 'skills'),
  memories: path.join(HOME_DIR, '.hermes', 'memories'),
  memory: path.join(HOME_DIR, '.hermes', 'memories', 'MEMORY.md'),
  user: path.join(HOME_DIR, '.hermes', 'memories', 'USER.md'),
  logs: path.join(HOME_DIR, '.hermes', 'logs')
};

const NEOAGENT_SKILLS_DIR = path.join(AGENT_DATA_DIR, 'skills');
const NEOAGENT_MEMORY_DIR = path.join(AGENT_DATA_DIR, 'memory');

const API_KEY_NAMES = [
  'ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'XAI_API_KEY', 'GOOGLE_AI_KEY',
  'MINIMAX_API_KEY', 'BRAVE_SEARCH_API_KEY', 'DEEPGRAM_API_KEY',
  'TELEGRAM_BOT_TOKEN', 'OPENROUTER_API_KEY', 'ELEVENLABS_API_KEY',
  'VOICE_TOOLS_OPENAI_KEY', 'SLACK_BOT_TOKEN', 'DISCORD_BOT_TOKEN'
];

function detectSourceAgents() {
  const detected = { openclaw: false, hermes: false };

  if (fs.existsSync(OPENCLAW_PATHS.config) || fs.existsSync(OPENCLAW_PATHS.legacyConfig)) {
    detected.openclaw = true;
  }
  if (fs.existsSync(HERMES_PATHS.config) || fs.existsSync(HERMES_PATHS.env)) {
    detected.hermes = true;
  }

  return detected;
}

function scanOpenClaw() {
  const scan = { skills: [], memories: [], apiKeys: {}, connections: [] };

  if (fs.existsSync(OPENCLAW_PATHS.skills)) {
    const files = fs.readdirSync(OPENCLAW_PATHS.skills).filter(f => f.endsWith('.md'));
    scan.skills = files.map(f => ({ name: f.replace('.md', ''), path: path.join(OPENCLAW_PATHS.skills, f) }));
  }

  for (const [key, filePath] of Object.entries({
    soul: OPENCLAW_PATHS.soul,
    memory: OPENCLAW_PATHS.memory,
    user: OPENCLAW_PATHS.user
  })) {
    if (fs.existsSync(filePath)) {
      scan.memories.push({ type: key, path: filePath });
    }
  }

  if (fs.existsSync(OPENCLAW_PATHS.env)) {
    const envMap = parseEnv(fs.readFileSync(OPENCLAW_PATHS.env, 'utf8'));
    for (const [key, value] of envMap.entries()) {
      if (API_KEY_NAMES.includes(key) && value) {
        scan.apiKeys[key] = value;
      }
    }
  }

  return scan;
}

function scanHermes() {
  const scan = { skills: [], memories: [], apiKeys: {}, connections: [] };

  if (fs.existsSync(HERMES_PATHS.skills)) {
    const files = fs.readdirSync(HERMES_PATHS.skills).filter(f => f.endsWith('.md'));
    scan.skills = files.map(f => ({ name: f.replace('.md', ''), path: path.join(HERMES_PATHS.skills, f) }));
  }

  for (const [key, filePath] of Object.entries({
    memory: HERMES_PATHS.memory,
    user: HERMES_PATHS.user
  })) {
    if (fs.existsSync(filePath)) {
      scan.memories.push({ type: key, path: filePath });
    }
  }

  if (fs.existsSync(HERMES_PATHS.env)) {
    const envMap = parseEnv(fs.readFileSync(HERMES_PATHS.env, 'utf8'));
    for (const [key, value] of envMap.entries()) {
      if (API_KEY_NAMES.includes(key) && value) {
        scan.apiKeys[key] = value;
      }
    }
  }

  return scan;
}

function copyFileIfExists(src, dest) {
  if (!fs.existsSync(src)) return false;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
  return true;
}

function copyDirContents(src, dest, extensions = ['.md']) {
  if (!fs.existsSync(src)) return [];
  const copied = [];
  const files = fs.readdirSync(src);
  for (const file of files) {
    if (extensions && !extensions.some(ext => file.endsWith(ext))) continue;
    const srcPath = path.join(src, file);
    const destPath = path.join(dest, file);
    fs.mkdirSync(dest, { recursive: true });
    fs.copyFileSync(srcPath, destPath);
    copied.push(file);
  }
  return copied;
}

async function ask(question, defaultValue = '') {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    const suffix = defaultValue ? ` [${defaultValue}]` : '';
    rl.question(`  ? ${question}${suffix}: `, (answer) => {
      rl.close();
      resolve(answer.trim() || defaultValue);
    });
  });
}

async function askChoice(question, options) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    console.log(`  ? ${question}`);
    options.forEach((opt, i) => console.log(`    [${i + 1}] ${opt}`));
    rl.question('  Choice: ', (answer) => {
      rl.close();
      const idx = parseInt(answer, 10) - 1;
      if (idx >= 0 && idx < options.length) {
        resolve(options[idx]);
      } else {
        resolve(options[0]);
      }
    });
  });
}

async function askOverwriteKey(key, existingSource, newSource) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    console.log(`  ⚠️  Conflict: ${key}`);
    console.log(`      Existing in: ${existingSource}`);
    console.log(`      Incoming from: ${newSource}`);
    console.log('    [1] Keep existing');
    console.log('    [2] Overwrite with new');
    console.log('    [3] Skip this key');
    rl.question('  Choice [1]: ', (answer) => {
      rl.close();
      const choice = answer.trim() || '1';
      if (choice === '2') resolve('overwrite');
      else if (choice === '3') resolve('skip');
      else resolve('keep');
    });
  });
}

async function migrateOpenClaw(scan, options = {}) {
  const { dryRun = false, conflictStrategy = 'ask' } = options;
  const results = { skills: [], memories: [], apiKeys: {}, connections: [], errors: [] };

  const skillsDest = path.join(NEOAGENT_SKILLS_DIR, 'openclaw-imports');
  if (!dryRun) fs.mkdirSync(skillsDest, { recursive: true });
  results.skills = copyDirContents(OPENCLAW_PATHS.skills, skillsDest, ['.md']);
  if (results.skills.length > 0) {
    console.log(`  → Copied ${results.skills.length} skills to openclaw-imports/`);
  }

  const memoryDest = path.join(NEOAGENT_MEMORY_DIR, 'openclaw');
  if (!dryRun) fs.mkdirSync(memoryDest, { recursive: true });
  for (const mem of scan.memories) {
    const destPath = path.join(memoryDest, path.basename(mem.path));
    if (!dryRun) {
      copyFileIfExists(mem.path, destPath);
    }
    results.memories.push(mem.type);
  }
  if (results.memories.length > 0) {
    console.log(`  → Copied ${results.memories.length} memory files`);
  }

  return results;
}

async function migrateHermes(scan, options = {}) {
  const { dryRun = false } = options;
  const results = { skills: [], memories: [], apiKeys: {}, connections: [], errors: [] };

  const skillsDest = path.join(NEOAGENT_SKILLS_DIR, 'hermes-imports');
  if (!dryRun) fs.mkdirSync(skillsDest, { recursive: true });
  results.skills = copyDirContents(HERMES_PATHS.skills, skillsDest, ['.md']);
  if (results.skills.length > 0) {
    console.log(`  → Copied ${results.skills.length} skills to hermes-imports/`);
  }

  const memoryDest = path.join(NEOAGENT_MEMORY_DIR, 'hermes');
  if (!dryRun) fs.mkdirSync(memoryDest, { recursive: true });
  for (const mem of scan.memories) {
    const destPath = path.join(memoryDest, path.basename(mem.path));
    if (!dryRun) {
      copyFileIfExists(mem.path, destPath);
    }
    results.memories.push(mem.type);
  }
  if (results.memories.length > 0) {
    console.log(`  → Copied ${results.memories.length} memory files`);
  }

  return results;
}

async function mergeApiKeys(sources, options = {}) {
  const { conflictStrategy = 'ask' } = options;
  const results = {};
  const conflicts = [];
  const currentEnv = fs.existsSync(ENV_FILE)
    ? parseEnv(fs.readFileSync(ENV_FILE, 'utf8'))
    : new Map();

  for (const [source, apiKeys] of Object.entries(sources)) {
    for (const [key, value] of Object.entries(apiKeys)) {
      if (!value) continue;
      const existingValue = currentEnv.get ? currentEnv.get(key) : currentEnv[key];
      if (existingValue && existingValue !== value) {
        conflicts.push({ key, existingValue, newValue: value, source });
      } else {
        results[key] = value;
      }
    }
  }

  for (const conflict of conflicts) {
    let resolution;
    if (conflictStrategy === 'overwrite') {
      resolution = 'overwrite';
    } else if (conflictStrategy === 'skip') {
      resolution = 'skip';
    } else {
      resolution = await askOverwriteKey(conflict.key, 'neoagent', conflict.source);
    }

    if (resolution === 'overwrite') {
      results[conflict.key] = conflict.newValue;
    } else if (resolution === 'skip') {
      // keep existing, do nothing
    } else {
      results[conflict.key] = conflict.existingValue;
    }
  }

  return results;
}

function writeMergedApiKeys(apiKeysToWrite) {
  if (Object.keys(apiKeysToWrite).length === 0) return;

  const currentLines = fs.existsSync(ENV_FILE)
    ? fs.readFileSync(ENV_FILE, 'utf8').split('\n')
    : [];

  const existingKeys = new Set();
  const newLines = [];

  for (const line of currentLines) {
    const match = line.match(/^([A-Z_]+)=/);
    if (match && API_KEY_NAMES.includes(match[1])) {
      if (apiKeysToWrite[match[1]] !== undefined) {
        newLines.push(`${match[1]}=${apiKeysToWrite[match[1]]}`);
        existingKeys.add(match[1]);
        delete apiKeysToWrite[match[1]];
      } else {
        newLines.push(line);
      }
    } else {
      newLines.push(line);
    }
  }

  for (const [key, value] of Object.entries(apiKeysToWrite)) {
    if (value) {
      newLines.push(`${key}=${value}`);
    }
  }

  fs.writeFileSync(ENV_FILE, newLines.join('\n') + '\n', { mode: 0o600 });
}

async function cmdMigrateDryRun(sources) {
  console.log('\n=== Migration Dry Run ===\n');

  if (sources.openclaw) {
    console.log('OpenClaw detection: FOUND');
    const scan = scanOpenClaw();
    console.log(`  Skills: ${scan.skills.length}`);
    console.log(`  Memories: ${scan.memories.length}`);
    console.log(`  API keys: ${Object.keys(scan.apiKeys).join(', ') || 'none'}`);
    console.log(`  Config: ${OPENCLAW_PATHS.config}`);
  } else {
    console.log('OpenClaw detection: NOT FOUND');
  }

  console.log();

  if (sources.hermes) {
    console.log('Hermes detection: FOUND');
    const scan = scanHermes();
    console.log(`  Skills: ${scan.skills.length}`);
    console.log(`  Memories: ${scan.memories.length}`);
    console.log(`  API keys: ${Object.keys(scan.apiKeys).join(', ') || 'none'}`);
    console.log(`  Config: ${HERMES_PATHS.config}`);
  } else {
    console.log('Hermes detection: NOT FOUND');
  }

  console.log('\nWould migrate to:');
  console.log(`  Skills → ${NEOAGENT_SKILLS_DIR}`);
  console.log(`  Memories → ${NEOAGENT_MEMORY_DIR}`);
  console.log(`  API keys → ${ENV_FILE}`);
}

async function cmdMigrateRun(sources, options = {}) {
  const { apiKeyStrategy = 'ask' } = options;

  console.log('\n=== NeoAgent Migration ===\n');

  const openclawScan = sources.openclaw ? scanOpenClaw() : null;
  const hermesScan = sources.hermes ? scanHermes() : null;

  console.log('Scanning sources...');
  if (openclawScan) console.log(`  OpenClaw: ${openclawScan.skills.length} skills, ${openclawScan.memories.length} memories, ${Object.keys(openclawScan.apiKeys).length} API keys`);
  if (hermesScan) console.log(`  Hermes: ${hermesScan.skills.length} skills, ${hermesScan.memories.length} memories, ${Object.keys(hermesScan.apiKeys).length} API keys`);

  const allApiKeys = {};
  if (openclawScan) Object.assign(allApiKeys, openclawScan.apiKeys);
  if (hermesScan) Object.assign(allApiKeys, hermesScan.apiKeys);

  console.log('\nMigrating skills and memories...');
  const migratePromises = [];
  if (sources.openclaw && openclawScan) {
    migratePromises.push(migrateOpenClaw(openclawScan, options));
  }
  if (sources.hermes && hermesScan) {
    migratePromises.push(migrateHermes(hermesScan, options));
  }

  const results = await Promise.all(migratePromises);

  if (Object.keys(allApiKeys).length > 0) {
    console.log('\nMerging API keys...');
    const merged = await mergeApiKeys(
      { openclaw: openclawScan?.apiKeys || {}, hermes: hermesScan?.apiKeys || {} },
      { conflictStrategy: apiKeyStrategy }
    );
    writeMergedApiKeys(merged);
    const addedCount = Object.keys(merged).filter(k => allApiKeys[k]).length;
    console.log(`  → Merged ${addedCount} API keys`);
  }

  console.log('\n=== Migration Complete ===\n');
  console.log('Skills migrated to:');
  if (sources.openclaw) console.log(`  openclaw-imports/`);
  if (sources.hermes) console.log(`  hermes-imports/`);
  console.log('\nMemories migrated to:');
  if (sources.openclaw) console.log(`  memory/openclaw/`);
  if (sources.hermes) console.log(`  memory/hermes/`);
  console.log('\nRun `neoagent status` to verify the installation.');
  console.log('Run `neoagent start` to start the server.\n');
}

module.exports = {
  detectSourceAgents,
  scanOpenClaw,
  scanHermes,
  migrateOpenClaw,
  migrateHermes,
  mergeApiKeys,
  writeMergedApiKeys,
  cmdMigrateDryRun,
  cmdMigrateRun,
  NEOAGENT_SKILLS_DIR,
  NEOAGENT_MEMORY_DIR,
  OPENCLAW_PATHS,
  HERMES_PATHS
};