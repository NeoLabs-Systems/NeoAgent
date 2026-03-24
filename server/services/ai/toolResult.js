function clampText(text, maxChars) {
  const str = String(text || '');
  if (str.length <= maxChars) return str;
  return `${str.slice(0, maxChars)}\n...[truncated, ${str.length} chars total]`;
}

function lineExcerpt(text, maxLines = 12, maxChars = 700) {
  const str = String(text || '').trim();
  if (!str) return '';
  return clampText(str.split('\n').slice(0, maxLines).join('\n'), maxChars);
}

function toJsonText(value, maxChars) {
  const raw = typeof value === 'string' ? value : JSON.stringify(value, null, 2);
  return clampText(raw, maxChars);
}

function trimObject(obj) {
  return Object.fromEntries(Object.entries(obj).filter(([, value]) => value !== undefined && value !== null && value !== ''));
}

function clampEnvelope(envelope, hardLimit) {
  const raw = JSON.stringify(envelope);
  if (raw.length <= hardLimit) return raw;

  const trimmed = { ...envelope };
  if (trimmed.summary) trimmed.summary = clampText(trimmed.summary, Math.max(200, hardLimit - 300));
  if (trimmed.stdout) trimmed.stdout = clampText(trimmed.stdout, Math.max(160, hardLimit - 400));
  if (trimmed.stderr) trimmed.stderr = clampText(trimmed.stderr, Math.max(120, hardLimit - 400));
  if (trimmed.content) trimmed.content = clampText(trimmed.content, Math.max(160, hardLimit - 400));
  if (trimmed.excerpt) trimmed.excerpt = clampText(trimmed.excerpt, Math.max(160, hardLimit - 400));
  if (trimmed.result) trimmed.result = clampText(trimmed.result, Math.max(160, hardLimit - 400));

  const fallback = JSON.stringify(trimmed);
  if (fallback.length <= hardLimit) return fallback;
  return clampText(fallback, hardLimit);
}

function compactToolResult(toolName, toolArgs = {}, toolResult, options = {}) {
  const softLimit = Math.max(400, Math.min(Number(options.softLimit) || 1200, 2000));
  const hardLimit = Math.max(softLimit, Math.min(Number(options.hardLimit) || 2000, 3000));

  let envelope;

  switch (toolName) {
    case 'execute_command':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.timedOut ? 'timed_out' : (toolResult?.exitCode === 0 ? 'ok' : 'error'),
        exitCode: toolResult?.exitCode,
        cwd: toolResult?.cwd || toolArgs.cwd,
        killed: toolResult?.killed || false,
        timedOut: toolResult?.timedOut || false,
        signal: toolResult?.signal,
        durationMs: toolResult?.durationMs,
        stdout: lineExcerpt(toolResult?.stdout, 12, Math.floor(softLimit * 0.45)),
        stderr: lineExcerpt(toolResult?.stderr, 8, Math.floor(softLimit * 0.25))
      });
      break;

    case 'read_file':
      envelope = trimObject({
        tool: toolName,
        path: toolArgs.path,
        startLine: toolArgs.start_line,
        endLine: toolArgs.end_line,
        content: lineExcerpt(toolResult?.content || toolResult, 20, Math.floor(softLimit * 0.7))
      });
      break;

    case 'search_files':
      envelope = trimObject({
        tool: toolName,
        count: toolResult?.count || toolResult?.matches?.length || 0,
        matches: (toolResult?.matches || []).slice(0, 6).map((match) => trimObject({
          file: match.file,
          line: match.line,
          content: clampText(match.content, 160)
        }))
      });
      break;

    case 'browser_extract':
      envelope = trimObject({
        tool: toolName,
        selector: toolArgs.selector || 'body',
        attribute: toolArgs.attribute || 'innerText',
        excerpt: lineExcerpt(toolResult?.result || toolResult?.content || toolResult, 18, Math.floor(softLimit * 0.7))
      });
      break;

    case 'android_dump_ui':
    case 'android_observe':
      envelope = trimObject({
        tool: toolName,
        serial: toolResult?.serial,
        nodeCount: toolResult?.nodeCount,
        screenshotPath: toolResult?.screenshotPath,
        uiDumpPath: toolResult?.uiDumpPath,
        preview: clampText(JSON.stringify(toolResult?.preview || []).slice(0, Math.floor(softLimit * 0.55)), Math.floor(softLimit * 0.55))
      });
      break;

    case 'android_list_apps':
      envelope = trimObject({
        tool: toolName,
        serial: toolResult?.serial,
        count: toolResult?.count,
        preview: lineExcerpt((toolResult?.packages || []).slice(0, 20).join('\n'), 20, Math.floor(softLimit * 0.6))
      });
      break;

    case 'android_shell':
      envelope = trimObject({
        tool: toolName,
        serial: toolResult?.serial,
        command: toolArgs.command,
        screenshotPath: toolResult?.screenshotPath,
        excerpt: lineExcerpt(toolResult?.stdout || toolResult?.result || toolResult, 18, Math.floor(softLimit * 0.65))
      });
      break;

    case 'http_request':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.status,
        headers: trimObject({
          contentType: toolResult?.headers?.['content-type'] || toolResult?.headers?.['Content-Type'],
          contentLength: toolResult?.headers?.['content-length'] || toolResult?.headers?.['Content-Length']
        }),
        excerpt: lineExcerpt(toolResult?.body || toolResult, 18, Math.floor(softLimit * 0.65))
      });
      break;

    case 'send_message':
    case 'make_call':
    case 'memory_save':
    case 'memory_recall':
    case 'memory_update_core':
    case 'memory_read':
    case 'memory_write':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.success === false || toolResult?.error ? 'error' : 'ok',
        message: clampText(toolResult?.message || toolResult?.error || '', Math.floor(softLimit * 0.45)),
        result: clampText(JSON.stringify(trimObject({
          id: toolResult?.id,
          key: toolResult?.key,
          deleted: toolResult?.deleted,
          sent: toolResult?.sent,
          count: Array.isArray(toolResult?.results) ? toolResult.results.length : undefined
        })), Math.floor(softLimit * 0.35))
      });
      break;

    case 'spawn_subagent':
      envelope = trimObject({
        tool: toolName,
        iterations: toolResult?.iterations,
        tokens: toolResult?.tokens,
        runId: toolResult?.runId,
        summary: clampText(toolResult?.subagent_result || toolResult?.error || '', Math.floor(softLimit * 0.55))
      });
      break;

    default:
      envelope = trimObject({
        tool: toolName,
        summary: toJsonText(toolResult, Math.floor(softLimit * 0.75))
      });
      break;
  }

  return clampEnvelope(envelope, hardLimit);
}

module.exports = {
  compactToolResult,
  clampText,
  lineExcerpt
};
