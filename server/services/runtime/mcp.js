function validateRemoteMcpEndpoint(value) {
  let url;
  try {
    url = new URL(String(value || '').trim());
  } catch {
    throw new Error('MCP server must be a valid remote http(s) URL.');
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    throw new Error('MCP server must use http or https. Local stdio/process MCP is disabled.');
  }

  return url.toString();
}

module.exports = {
  validateRemoteMcpEndpoint,
};
