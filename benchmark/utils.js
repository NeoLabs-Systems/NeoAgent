'use strict';

const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');

async function ensureDir(dirPath) {
  await fsp.mkdir(dirPath, { recursive: true });
}

async function writeJson(filePath, value) {
  await ensureDir(path.dirname(filePath));
  await fsp.writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

async function writeText(filePath, value) {
  await ensureDir(path.dirname(filePath));
  await fsp.writeFile(filePath, value, 'utf8');
}

async function readJson(filePath) {
  return JSON.parse(await fsp.readFile(filePath, 'utf8'));
}

async function readJsonLines(filePath) {
  const text = await fsp.readFile(filePath, 'utf8');
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

async function exists(targetPath) {
  try {
    await fsp.access(targetPath, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

function executeCommand(command, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, {
      shell: true,
      cwd: options.cwd || process.cwd(),
      env: { ...process.env, ...(options.env || {}) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('error', reject);
    child.on('close', (code) => {
      resolve({
        code: Number(code || 0),
        stdout,
        stderr,
        ok: Number(code || 0) === 0,
      });
    });
  });
}

async function commandExists(command) {
  const result = await executeCommand(`command -v ${command}`);
  return result.ok && String(result.stdout || '').trim().length > 0;
}

function limitCases(items, maxItems) {
  if (!Number.isInteger(maxItems) || maxItems <= 0) return [...items];
  return items.slice(0, maxItems);
}

module.exports = {
  commandExists,
  ensureDir,
  executeCommand,
  exists,
  limitCases,
  readJson,
  readJsonLines,
  writeJson,
  writeText,
};
