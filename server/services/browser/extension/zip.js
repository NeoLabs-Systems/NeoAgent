const fs = require('fs');
const path = require('path');

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let c = i;
    for (let j = 0; j < 8; j += 1) {
      c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c >>> 0;
  }
  return table;
})();

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function dosDateTime(date = new Date()) {
  const year = Math.max(1980, date.getFullYear());
  const dosTime =
    (date.getHours() << 11) |
    (date.getMinutes() << 5) |
    Math.floor(date.getSeconds() / 2);
  const dosDate =
    ((year - 1980) << 9) |
    ((date.getMonth() + 1) << 5) |
    date.getDate();
  return { dosTime, dosDate };
}

function listFiles(rootDir, prefix = '') {
  const entries = fs.readdirSync(rootDir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    if (entry.name.startsWith('.')) continue;
    const fullPath = path.join(rootDir, entry.name);
    const archivePath = path.posix.join(prefix, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFiles(fullPath, archivePath));
    } else if (entry.isFile()) {
      files.push({ fullPath, archivePath });
    }
  }
  return files;
}

function normalizeArchivePath(value) {
  return String(value || '').replace(/\\/g, '/').replace(/^\/+/, '');
}

function u16(value) {
  const buffer = Buffer.alloc(2);
  buffer.writeUInt16LE(value);
  return buffer;
}

function u32(value) {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32LE(value >>> 0);
  return buffer;
}

function createZipFromDirectory(rootDir, options = {}) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  const overrides = new Map(
    Object.entries(options.overrides || {}).map(([archivePath, content]) => [
      normalizeArchivePath(archivePath),
      Buffer.isBuffer(content) ? content : Buffer.from(String(content), 'utf8'),
    ]),
  );
  const files = listFiles(rootDir)
    .filter((file) => !overrides.has(normalizeArchivePath(file.archivePath)))
    .map((file) => ({
      archivePath: normalizeArchivePath(file.archivePath),
      content: fs.readFileSync(file.fullPath),
      mtime: fs.statSync(file.fullPath).mtime,
    }));

  for (const [archivePath, content] of overrides.entries()) {
    files.push({ archivePath, content, mtime: new Date() });
  }

  for (const file of files) {
    const content = file.content;
    const name = Buffer.from(file.archivePath.replace(/\\/g, '/'), 'utf8');
    const { dosTime, dosDate } = dosDateTime(file.mtime);
    const crc = crc32(content);

    const localHeader = Buffer.concat([
      u32(0x04034b50),
      u16(20),
      u16(0),
      u16(0),
      u16(dosTime),
      u16(dosDate),
      u32(crc),
      u32(content.length),
      u32(content.length),
      u16(name.length),
      u16(0),
      name,
    ]);
    localParts.push(localHeader, content);

    const centralHeader = Buffer.concat([
      u32(0x02014b50),
      u16(20),
      u16(20),
      u16(0),
      u16(0),
      u16(dosTime),
      u16(dosDate),
      u32(crc),
      u32(content.length),
      u32(content.length),
      u16(name.length),
      u16(0),
      u16(0),
      u16(0),
      u16(0),
      u32(0),
      u32(offset),
      name,
    ]);
    centralParts.push(centralHeader);
    offset += localHeader.length + content.length;
  }

  const centralDirectory = Buffer.concat(centralParts);
  const end = Buffer.concat([
    u32(0x06054b50),
    u16(0),
    u16(0),
    u16(centralParts.length),
    u16(centralParts.length),
    u32(centralDirectory.length),
    u32(offset),
    u16(0),
  ]);
  return Buffer.concat([...localParts, centralDirectory, end]);
}

module.exports = {
  createZipFromDirectory,
};
