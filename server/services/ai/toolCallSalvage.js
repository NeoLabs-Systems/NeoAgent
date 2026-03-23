const { v4: uuidv4 } = require('uuid')

const INVOKE_OPEN_RE = /(?:[A-Za-z0-9_.-]+:tool_call\s*)?<invoke\s+name="([^"]+)">/g
const PARAM_OPEN_RE = /<parameter\s+name="([^"]+)">/g
const PARAM_CLOSED_RE = /<parameter\s+name="([^"]+)">([\s\S]*?)<\/parameter>/g
const INVOKE_CLOSE = '</invoke>'

function trimLooseControlText(text) {
  return String(text || '')
    .replace(/(?:^|\s)[A-Za-z0-9_.-]+:tool_call\s*$/g, '')
    .trim()
}

function parseParameterMap(body) {
  const args = {}
  let sawClosedParam = false
  let match

  PARAM_CLOSED_RE.lastIndex = 0
  while ((match = PARAM_CLOSED_RE.exec(body)) !== null) {
    sawClosedParam = true
    args[match[1]] = match[2].trim()
  }
  if (sawClosedParam) return args

  const markers = []
  PARAM_OPEN_RE.lastIndex = 0
  while ((match = PARAM_OPEN_RE.exec(body)) !== null) {
    markers.push({
      name: match[1],
      valueStart: match.index + match[0].length,
      openIndex: match.index
    })
  }

  for (let i = 0; i < markers.length; i++) {
    const current = markers[i]
    const next = markers[i + 1]
    const rawValue = body.slice(current.valueStart, next ? next.openIndex : body.length)
    args[current.name] = rawValue.trim()
  }

  return args
}

function salvageTextToolCalls(content, tools = []) {
  const text = String(content || '')
  if (!text.includes('<invoke')) {
    return { content: text, toolCalls: [] }
  }

  const allowedToolNames = new Set(
    Array.isArray(tools) ? tools.map((tool) => tool?.name).filter(Boolean) : []
  )

  const openings = []
  let match
  INVOKE_OPEN_RE.lastIndex = 0
  while ((match = INVOKE_OPEN_RE.exec(text)) !== null) {
    openings.push({
      index: match.index,
      openText: match[0],
      name: match[1]
    })
  }

  if (openings.length === 0) {
    return { content: text, toolCalls: [] }
  }

  const cleanedParts = []
  const toolCalls = []
  let cursor = 0

  for (let i = 0; i < openings.length; i++) {
    const current = openings[i]
    const next = openings[i + 1]
    const searchEnd = next ? next.index : text.length
    const bodyStart = current.index + current.openText.length
    const closeIndex = text.indexOf(INVOKE_CLOSE, bodyStart)
    const blockEnd = closeIndex !== -1 && closeIndex < searchEnd
      ? closeIndex + INVOKE_CLOSE.length
      : searchEnd
    const bodyEnd = closeIndex !== -1 && closeIndex < searchEnd
      ? closeIndex
      : searchEnd

    cleanedParts.push(text.slice(cursor, current.index))
    cursor = blockEnd

    if (allowedToolNames.size > 0 && !allowedToolNames.has(current.name)) {
      cleanedParts.push(text.slice(current.index, blockEnd))
      continue
    }

    const args = parseParameterMap(text.slice(bodyStart, bodyEnd))
    toolCalls.push({
      id: `salvaged_${uuidv4()}`,
      type: 'function',
      function: {
        name: current.name,
        arguments: JSON.stringify(args)
      }
    })
  }

  cleanedParts.push(text.slice(cursor))

  return {
    content: trimLooseControlText(cleanedParts.join('').replace(/\n{3,}/g, '\n\n')),
    toolCalls
  }
}

module.exports = {
  salvageTextToolCalls
}
