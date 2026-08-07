'use strict';

// Container health probe. It uses the same unauthenticated setup handshake the
// installer waits on (lib/manager.js waitForServerReady), so a healthy
// container means a NeoAgent server that is actually serving requests.

const port = Number(process.env.PORT) || 3333;

fetch(`http://127.0.0.1:${port}/api/setup/handshake`, {
  signal: AbortSignal.timeout(4000),
})
  .then(async (response) => {
    const body = response.ok ? await response.json() : null;
    process.exit(body?.product === 'NeoAgent' ? 0 : 1);
  })
  .catch(() => process.exit(1));
