const DEFAULT_BOUNDS = Object.freeze({
  left: 0,
  top: 0,
  right: 0,
  bottom: 0,
  width: 0,
  height: 0,
  centerX: 0,
  centerY: 0,
});

function decodeXml(value) {
  return String(value || '')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#10;/g, '\n')
    .replace(/&#13;/g, '\r')
    .replace(/&#39;/g, "'");
}

function parseBounds(raw) {
  const match = String(raw || '').match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
  if (!match) return { ...DEFAULT_BOUNDS };

  const left = Number(match[1] || 0);
  const top = Number(match[2] || 0);
  const right = Number(match[3] || 0);
  const bottom = Number(match[4] || 0);

  return {
    left,
    top,
    right,
    bottom,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top),
    centerX: Math.round((left + right) / 2),
    centerY: Math.round((top + bottom) / 2),
  };
}

function parseNodeAttributes(raw) {
  const attrs = {};
  const attrRe = /([\w:-]+)="([^"]*)"/g;
  let match = attrRe.exec(raw);
  while (match) {
    attrs[match[1]] = decodeXml(match[2]);
    match = attrRe.exec(raw);
  }
  return attrs;
}

function parseUiDump(xml) {
  const nodes = [];
  const nodeRe = /<node\b([^>]*)\/>/g;
  let match = nodeRe.exec(String(xml || ''));

  while (match) {
    const attrs = parseNodeAttributes(match[1]);
    const bounds = parseBounds(attrs.bounds);
    nodes.push({
      text: attrs.text || '',
      resourceId: attrs['resource-id'] || '',
      description: attrs['content-desc'] || '',
      className: attrs.class || '',
      packageName: attrs.package || '',
      clickable: attrs.clickable === 'true',
      enabled: attrs.enabled !== 'false',
      focusable: attrs.focusable === 'true',
      longClickable: attrs['long-clickable'] === 'true',
      bounds,
      raw: attrs,
    });
    match = nodeRe.exec(String(xml || ''));
  }

  return nodes;
}

function normalizeNeedle(value) {
  return String(value || '').trim().toLowerCase();
}

function scoreNode(node, selector = {}) {
  let score = 0;

  const text = normalizeNeedle(node.text);
  const resourceId = normalizeNeedle(node.resourceId);
  const description = normalizeNeedle(node.description);
  const className = normalizeNeedle(node.className);
  const packageName = normalizeNeedle(node.packageName);

  if (selector.resourceId) {
    if (resourceId === normalizeNeedle(selector.resourceId)) score += 500;
    else if (resourceId.includes(normalizeNeedle(selector.resourceId))) score += 220;
    else return -1;
  }

  if (selector.text) {
    const needle = normalizeNeedle(selector.text);
    if (text === needle) score += 360;
    else if (text.includes(needle)) score += 180;
    else if (description.includes(needle)) score += 120;
    else return -1;
  }

  if (selector.description) {
    const needle = normalizeNeedle(selector.description);
    if (description === needle) score += 320;
    else if (description.includes(needle)) score += 160;
    else return -1;
  }

  if (selector.className) {
    if (className === normalizeNeedle(selector.className)) score += 120;
    else return -1;
  }

  if (selector.packageName) {
    if (packageName === normalizeNeedle(selector.packageName)) score += 80;
    else return -1;
  }

  if (selector.clickable === true && node.clickable) score += 40;
  if (selector.clickable === true && !node.clickable) score -= 60;
  if (node.enabled) score += 10;
  if (node.bounds.width > 0 && node.bounds.height > 0) score += 10;

  return score;
}

function findBestNode(xml, selector = {}) {
  const nodes = Array.isArray(xml) ? xml : parseUiDump(xml);
  let best = null;
  let bestScore = -1;

  for (const node of nodes) {
    const score = scoreNode(node, selector);
    if (score > bestScore) {
      best = node;
      bestScore = score;
    }
  }

  if (bestScore < 0) return null;
  return best;
}

function summarizeNode(node) {
  if (!node) return null;
  return {
    text: node.text,
    resourceId: node.resourceId,
    description: node.description,
    className: node.className,
    packageName: node.packageName,
    clickable: node.clickable,
    enabled: node.enabled,
    bounds: node.bounds,
  };
}

module.exports = {
  parseBounds,
  parseUiDump,
  findBestNode,
  summarizeNode,
};
