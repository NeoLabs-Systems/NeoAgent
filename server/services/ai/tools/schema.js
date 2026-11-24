'use strict';

function compactText(text, maxChars = 120) {
  const str = String(text || '').replace(/\s+/g, ' ').trim();
  if (str.length <= maxChars) return str;
  const trimmed = str.slice(0, maxChars);
  const sentenceBreak = Math.max(trimmed.lastIndexOf('. '), trimmed.lastIndexOf('; '), trimmed.lastIndexOf(', '));
  if (sentenceBreak > 40) return trimmed.slice(0, sentenceBreak + 1).trim();
  return `${trimmed.trim()}...`;
}

function compactProperties(properties, options) {
  const compacted = {};
  for (const [key, value] of Object.entries(properties)) {
    compacted[key] = compactSchema(value, options);
  }
  return compacted;
}

function compactSchema(schema, options) {
  if (!schema || typeof schema !== 'object') return schema;
  const compact = { ...schema };
  if (options.includeDescriptions && schema.description) {
    compact.description = compactText(schema.description, 160);
  } else {
    delete compact.description;
  }
  if (schema.properties && typeof schema.properties === 'object') {
    compact.properties = compactProperties(schema.properties, options);
  }
  if (schema.items && typeof schema.items === 'object') {
    compact.items = compactSchema(schema.items, options);
  }
  return compact;
}

// Telling two similar tools apart is the description's job, so the guidance
// joins it after the trim and always reaches the model.
function describeTool(tool) {
  const parts = [compactText(tool.description, 320)];
  if (tool.whenToUse?.length) parts.push(`Use for: ${tool.whenToUse.join('; ')}.`);
  if (tool.whenNotToUse?.length) parts.push(`Not for: ${tool.whenNotToUse.join('; ')}.`);
  return parts.join(' ');
}

// What a provider sees of a tool is its name, description, and parameters; the
// adapters serialize nothing else. `access`, `family`, and `integration` stay on
// the internal definition for the harness.
function compactToolDefinition(tool, options = {}) {
  if (!tool || typeof tool !== 'object' || !String(tool.name || '').trim()) {
    return null;
  }
  const compact = {
    name: tool.name,
    parameters: {
      ...(tool.parameters || { type: 'object', properties: {} }),
      properties: {},
    },
  };

  if (typeof tool.access === 'string' && tool.access.trim()) {
    compact.access = tool.access.trim().toLowerCase();
  }
  if (typeof tool.family === 'string' && tool.family.trim()) {
    compact.family = tool.family.trim();
  }
  if (tool.integration) compact.integration = tool.integration;

  if (options.includeDescriptions) {
    compact.description = describeTool(tool);
  }

  if (tool.parameters?.properties) {
    compact.parameters = {
      ...compact.parameters,
      properties: compactProperties(tool.parameters.properties, options),
    };
  }

  return compact;
}

module.exports = { compactToolDefinition };
