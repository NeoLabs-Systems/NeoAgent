'use strict';

const { EventEmitter } = require('node:events');
const os = require('node:os');
const { DESKTOP_COMMANDS } = require('./protocol');
const { CLIExecutor } = require('../cli/executor');
const { WorkspaceManager } = require('../workspace/manager');

const WS_OPEN = 1;
const WS_CLOSED = 3;

/**
 * A duplex the desktop registry can drive without a network socket.
 *
 * The registry talks to companions over a WebSocket: it calls send()/ping()/
 * close() and listens for 'message'. In-process we keep that same contract and
 * only swap the transport, so the registry, the provider and the command
 * protocol are shared with the desktop app rather than duplicated.
 */
class InProcessSocket extends EventEmitter {
  constructor(onCommand) {
    super();
    this.readyState = WS_OPEN;
    this._onCommand = onCommand;
  }

  send(data) {
    let message;
    try {
      message = JSON.parse(data);
    } catch {
      return;
    }
    if (message?.type !== 'command') return;
    // Detach so a handler that throws rejects that one command instead of
    // unwinding through the registry's send path.
    Promise.resolve()
      .then(() => this._onCommand(message.command, message.payload || {}))
      .then((payload) => this._reply({ type: 'result', id: message.id, ok: true, payload: payload ?? {} }))
      .catch((error) => this._reply({
        type: 'result',
        id: message.id,
        ok: false,
        error: error?.message || 'Local companion command failed.',
        code: error?.code || null,
      }));
  }

  _reply(message) {
    if (this.readyState !== WS_OPEN) return;
    this.emit('message', Buffer.from(JSON.stringify(message)));
  }

  ping() {
    if (this.readyState === WS_OPEN) this.emit('pong');
  }

  close() {
    if (this.readyState === WS_CLOSED) return;
    this.readyState = WS_CLOSED;
    this.emit('close');
  }

  terminate() {
    this.close();
  }
}

function unsupported(command) {
  const error = new Error(
    `The command-line companion cannot run "${command}" because it has no screen. `
    + 'Use the desktop app for screen control.',
  );
  error.code = 'LOCAL_COMPANION_UNSUPPORTED';
  return error;
}

/**
 * Registers this process as the user's desktop companion so agent tools run
 * here, on this machine, through the same path the desktop app uses.
 *
 * Shell work goes to CLIExecutor and file work to WorkspaceManager, so no
 * execution logic is reimplemented -- this module only maps the companion
 * protocol onto services that already exist.
 */
function startLocalCompanion({ registry, userId, workspaceRoot }) {
  const executor = new CLIExecutor();
  const workspace = new WorkspaceManager({ rootDir: workspaceRoot, pinned: true });

  const handlers = {
    [DESKTOP_COMMANDS.GET_STATUS]: () => ({ paused: false, capabilities: { files: true, shell: true } }),
    [DESKTOP_COMMANDS.PING]: () => ({}),
    [DESKTOP_COMMANDS.EXECUTE_COMMAND]: (payload) => executor.execute(payload.command, {
      cwd: payload.cwd && payload.cwd !== '__neoagent_workspace__' ? payload.cwd : workspaceRoot,
      timeout: payload.timeout,
      inputs: payload.inputs,
      pty: payload.pty,
    }),
    [DESKTOP_COMMANDS.CANCEL_COMMAND]: (payload) => executor.kill(payload.commandId),
    [DESKTOP_COMMANDS.LIST_FILES]: (payload) => workspace.listDirectory(userId, payload),
    [DESKTOP_COMMANDS.READ_FILE]: (payload) => workspace.readFile(userId, payload),
    [DESKTOP_COMMANDS.WRITE_FILE]: (payload) => workspace.writeFile(userId, payload),
    [DESKTOP_COMMANDS.SEARCH_FILES]: (payload) => workspace.searchFiles(userId, payload),
  };

  const socket = new InProcessSocket((command, payload) => {
    const handler = handlers[command];
    if (!handler) throw unsupported(command);
    return handler(payload);
  });

  const deviceId = `cli-${os.hostname()}`;
  // Read before registering: registration can itself change the selection, and
  // we want the value that was in place before this run started.
  const previousDeviceId = registry.getSelectedDeviceId(userId);
  const { connection } = registry.registerConnection({
    userId,
    sessionId: null,
    ws: socket,
    hello: {
      deviceId,
      label: 'NeoAgent CLI',
      hostname: os.hostname(),
      platform: process.platform,
      capabilities: { files: true, shell: true, screen: false },
    },
  });

  // The desktop app may be connected on this machine too. Two online
  // companions make device resolution ambiguous and the run fails, so point
  // the selection at this process while it holds the terminal, and hand it
  // back afterwards. A stale value is harmless: offline devices are skipped.
  registry.setSelectedDeviceId(userId, deviceId);

  return {
    stop() {
      registry.setSelectedDeviceId(userId, previousDeviceId || '');
      connection.close('command-line run finished');
      socket.close();
    },
  };
}

module.exports = { startLocalCompanion };
