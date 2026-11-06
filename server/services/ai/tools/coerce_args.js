'use strict';

// Models send values in a near miss of the declared type: "5.0" for an integer,
// "true" for a boolean, a JSON string for an array, "Recurring" for "recurring".
// Each is fixed here, against the tool's own schema, before the call is checked
// or run; anything that is not an unambiguous near miss is left for the tool to
// reject. Strict tool schemas would stop these at the provider, but not every
// provider offers them.

function typesOf(schema) {
  if (!schema || typeof schema !== 'object') return [];
  return Array.isArray(schema.type) ? schema.type : [schema.type].filter(Boolean);
}

function coerceValue(value, schema) {
  const types = typesOf(schema);
  if (!types.length && !schema?.enum) return value;

  if (typeof value === 'string') {
    const text = value.trim();
    if ((types.includes('integer') || types.includes('number')) && !types.includes('string')
      && /^-?\d+(\.\d+)?$/.test(text)) {
      const number = Number(text);
      if (!types.includes('integer') || Number.isInteger(number)) return number;
    }
    if (types.includes('boolean') && !types.includes('string') && /^(true|false)$/i.test(text)) {
      return text.toLowerCase() === 'true';
    }
    if ((types.includes('array') || types.includes('object')) && !types.includes('string') && /^[[{]/.test(text)) {
      try {
        return coerceValue(JSON.parse(text), schema);
      } catch {
        return value;
      }
    }
    if (Array.isArray(schema.enum) && !schema.enum.includes(value)) {
      const match = schema.enum.find((option) => typeof option === 'string' && option.toLowerCase() === text.toLowerCase());
      if (match !== undefined) return match;
    }
    return value;
  }
  if ((typeof value === 'number' || typeof value === 'boolean') && types.length === 1 && types[0] === 'string') {
    return String(value);
  }
  if (Array.isArray(value) && schema.items) return value.map((item) => coerceValue(item, schema.items));
  if (value && typeof value === 'object' && !Array.isArray(value) && schema.properties) {
    return coerceToolArgs(value, schema);
  }
  return value;
}

function coerceToolArgs(args, schema) {
  if (!args || typeof args !== 'object' || Array.isArray(args) || !schema?.properties) return args;
  const coerced = { ...args };
  for (const [key, property] of Object.entries(schema.properties)) {
    if (Object.hasOwn(coerced, key)) coerced[key] = coerceValue(coerced[key], property);
  }
  return coerced;
}

module.exports = { coerceToolArgs };
