'use strict';

const { githubApiRequest } = require('./common');

// Push rules for agent git traffic. The proxy reads the ref-update commands at
// the head of a receive-pack request (pkt-line framed, terminated by a flush),
// decides before any pack data reaches GitHub, and on refusal answers with a
// normal report-status so git prints "! [remote rejected] <ref> (<reason>)".

const MAX_COMMAND_SECTION_BYTES = 1024 * 1024;
const SIDEBAND_CHUNK_BYTES = 995;
const NULL_OBJECT_ID = /^0+$/;

function parsePushCommands(buffer) {
  const commands = [];
  let clientCapabilities = [];
  let offset = 0;
  while (offset + 4 <= buffer.length) {
    const length = Number.parseInt(buffer.toString('ascii', offset, offset + 4), 16);
    if (!Number.isInteger(length) || (length > 0 && length < 4)) {
      throw new Error('Malformed receive-pack request.');
    }
    if (length === 0) {
      return { complete: true, bytes: offset + 4, commands, clientCapabilities };
    }
    if (offset + length > buffer.length) break;
    let line = buffer.toString('utf8', offset + 4, offset + length).replace(/\n$/, '');
    offset += length;
    const nul = line.indexOf('\0');
    if (nul !== -1) {
      clientCapabilities = line.slice(nul + 1).split(' ');
      line = line.slice(0, nul);
    }
    if (line.startsWith('shallow ')) continue;
    const [oldId, newId, ref] = line.split(' ');
    if (!oldId || !newId || !ref) throw new Error('Malformed receive-pack command.');
    commands.push({ oldId, newId, ref });
  }
  return { complete: false };
}

// Reads just the command section and pauses the request, so the caller can
// replay those bytes upstream and pipe the pack that follows.
function readPushCommands(req) {
  return new Promise((resolve, reject) => {
    let buffered = Buffer.alloc(0);
    const cleanup = () => {
      req.off('data', onData);
      req.off('end', onEnd);
      req.off('error', onError);
    };
    const fail = (error) => {
      cleanup();
      reject(error);
    };
    function onData(chunk) {
      buffered = Buffer.concat([buffered, chunk]);
      let parsed;
      try {
        parsed = parsePushCommands(buffered);
      } catch (error) {
        fail(error);
        return;
      }
      if (parsed.complete) {
        cleanup();
        req.pause();
        resolve({ head: buffered, commands: parsed.commands, clientCapabilities: parsed.clientCapabilities });
        return;
      }
      if (buffered.length > MAX_COMMAND_SECTION_BYTES) {
        fail(new Error('Push command list is too large.'));
      }
    }
    function onEnd() {
      fail(new Error('Push request ended before its command list.'));
    }
    function onError(error) {
      fail(error);
    }
    req.on('data', onData);
    req.on('end', onEnd);
    req.on('error', onError);
  });
}

async function findPushRefusal({ commands, owner, repo, token, signal }) {
  const deletion = commands.find((command) => NULL_OBJECT_ID.test(command.newId));
  if (deletion) {
    return { ref: deletion.ref, reason: 'agents may not delete remote branches or tags' };
  }

  // Creating the default branch (first push to an empty repo) cannot overwrite
  // anything; only updates to an existing default branch are refused.
  const updates = commands.filter((command) => !NULL_OBJECT_ID.test(command.oldId));
  if (updates.length === 0) return null;
  const repository = await githubApiRequest({ token, signal }, { path: `/repos/${owner}/${repo}` });
  const defaultRef = `refs/heads/${repository?.default_branch}`;
  const protectedUpdate = updates.find((command) => command.ref === defaultRef);
  if (!protectedUpdate) return null;
  return {
    ref: protectedUpdate.ref,
    reason: `pushes to the default branch ${repository.default_branch} are blocked; push a feature branch and open a pull request`,
  };
}

function pktLine(payload) {
  const body = Buffer.isBuffer(payload) ? payload : Buffer.from(payload);
  return Buffer.concat([Buffer.from((body.length + 4).toString(16).padStart(4, '0')), body]);
}

function buildPushRefusalReport({ commands, clientCapabilities, refusal }) {
  const report = Buffer.concat([
    pktLine('unpack ok\n'),
    ...commands.map((command) => pktLine(
      command.ref === refusal.ref
        ? `ng ${command.ref} ${refusal.reason}\n`
        : `ng ${command.ref} not pushed because ${refusal.ref} was refused\n`,
    )),
    Buffer.from('0000'),
  ]);
  const sideband = clientCapabilities.includes('side-band-64k') || clientCapabilities.includes('side-band');
  if (!sideband) return report;

  const packets = [];
  for (let offset = 0; offset < report.length; offset += SIDEBAND_CHUNK_BYTES) {
    packets.push(pktLine(Buffer.concat([
      Buffer.from([1]),
      report.subarray(offset, offset + SIDEBAND_CHUNK_BYTES),
    ])));
  }
  packets.push(Buffer.from('0000'));
  return Buffer.concat(packets);
}

module.exports = {
  buildPushRefusalReport,
  findPushRefusal,
  parsePushCommands,
  readPushCommands,
};
