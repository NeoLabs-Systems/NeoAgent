'use strict';

async function readChunkBody(req, options = {}) {
  const defaultMaxSize = Number(process.env.NEOAGENT_READ_CHUNK_BODY_MAX_BYTES || 10 * 1024 * 1024);
  const maxSize = Number.isFinite(Number(options.maxSize)) && Number(options.maxSize) > 0
    ? Number(options.maxSize)
    : (Number.isFinite(defaultMaxSize) && defaultMaxSize > 0 ? defaultMaxSize : null);
  const timeout = Number.isFinite(Number(options.timeout)) && Number(options.timeout) > 0
    ? Number(options.timeout)
    : null;

  if (Buffer.isBuffer(req.body) && req.body.length > 0) {
    if (maxSize != null && req.body.length > maxSize) throw new Error('Payload too large');
    return req.body;
  }
  if (req.readableEnded) {
    return Buffer.alloc(0);
  }

  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalSize = 0;

    const timer = timeout == null
      ? null
      : setTimeout(() => {
        cleanup();
        reject(new Error('Request timeout'));
        req.destroy();
      }, timeout);

    const onData = (chunk) => {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      totalSize += buffer.length;
      if (maxSize != null && totalSize > maxSize) {
        cleanup();
        reject(new Error('Payload too large'));
        req.destroy();
        return;
      }
      chunks.push(buffer);
    };

    const onEnd = () => {
      cleanup();
      resolve(Buffer.concat(chunks));
    };

    const onError = (error) => {
      cleanup();
      reject(error);
    };

    function cleanup() {
      if (timer != null) {
        clearTimeout(timer);
      }
      req.removeListener('data', onData);
      req.removeListener('end', onEnd);
      req.removeListener('error', onError);
    }

    req.on('data', onData);
    req.on('end', onEnd);
    req.on('error', onError);
  });
}

module.exports = {
  readChunkBody,
};
