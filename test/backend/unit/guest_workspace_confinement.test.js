'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const { once } = require('node:events');

test('real guest HTTP file routes refuse outside symlinks and preserve contained links', { timeout: 15000 }, async (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neo-guest-http-'));
  const workspace = path.join(root, 'workspace'); fs.mkdirSync(workspace);
  fs.writeFileSync(path.join(root, 'outside.txt'), 'dummy private fixture');
  fs.writeFileSync(path.join(workspace, 'inside.txt'), 'inside');
  fs.symlinkSync(path.join(root, 'outside.txt'), path.join(workspace, 'outside-link'));
  fs.symlinkSync(path.join(workspace, 'inside.txt'), path.join(workspace, 'inside-link'));
  const listener = net.createServer(); listener.listen(0, '127.0.0.1'); await once(listener, 'listening');
  const port = listener.address().port; await new Promise((resolve) => listener.close(resolve));
  const child = spawn(process.execPath, [path.resolve(__dirname, '../../../server/guest_agent.js')], {
    env: { PATH: process.env.PATH, HOME: path.join(root, 'home'), TMPDIR: root,
      NEOAGENT_HOME: root, NEOAGENT_DATA_DIR: path.join(root, 'data'), NEOAGENT_ENV_FILE: path.join(root, 'empty.env'),
      NEOAGENT_GUEST_AGENT_PORT: String(port), NEOAGENT_VM_GUEST_TOKEN: 'dummy-guest-token',
      NEOAGENT_GUEST_PROFILE: 'cli', NEOAGENT_WORKSPACE_DIR: workspace }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  t.after(async () => { child.kill('SIGTERM'); if (child.exitCode === null) await once(child, 'close'); fs.rmSync(root, { recursive: true, force: true }); });
  await new Promise((resolve, reject) => { child.stdout.on('data', (data) => { if (String(data).includes('listening')) resolve(); }); child.once('exit', () => reject(new Error('guest fixture exited before readiness'))); });
  const request = (route, method = 'GET', body) => fetch(`http://127.0.0.1:${port}${route}`, { method, headers: { authorization: 'Bearer dummy-guest-token', 'content-type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
  for (const route of ['/workspace/files/content?path=outside-link', '/workspace/files/download?path=outside-link']) {
    const response = await request(route); const body = await response.json();
    assert.ok(response.status >= 400); assert.match(body.error, /outside/); assert.ok(!JSON.stringify(body).includes('dummy private fixture'));
  }
  const denied = await request('/workspace/files/content', 'PUT', { path: 'outside-link', content: 'overwrite' });
  assert.ok(denied.status >= 400); assert.equal(fs.readFileSync(path.join(root, 'outside.txt'), 'utf8'), 'dummy private fixture');
  const read = await (await request('/workspace/files/content?path=inside-link')).json(); assert.equal(read.content, 'inside');
  const written = await (await request('/workspace/files/content', 'PUT', { path: 'inside-link', content: 'updated' })).json();
  assert.equal(written.success, true); assert.equal(fs.lstatSync(path.join(workspace, 'inside-link')).isSymbolicLink(), true);
  assert.equal(fs.readFileSync(path.join(workspace, 'inside.txt'), 'utf8'), 'updated');
});
