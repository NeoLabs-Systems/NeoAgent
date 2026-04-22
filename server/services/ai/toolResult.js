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

function buildSimpleStatusEnvelope(toolName, toolResult, softLimit) {
  return trimObject({
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
}

function compactToolResult(toolName, toolArgs = {}, toolResult, options = {}) {
  const softLimit = Math.max(500, Math.min(Number(options.softLimit) || 1800, 3000));
  const hardLimit = Math.max(softLimit, Math.min(Number(options.hardLimit) || 3200, 4500));

  let envelope;

  switch (toolName) {
    case 'execute_command':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.timedOut ? 'timed_out' : (toolResult?.exitCode === 0 ? 'ok' : 'error'),
        command: clampText(toolArgs.command || '', Math.floor(softLimit * 0.28)),
        exitCode: toolResult?.exitCode,
        cwd: toolResult?.cwd || toolArgs.cwd,
        killed: toolResult?.killed || false,
        timedOut: toolResult?.timedOut || false,
        signal: toolResult?.signal,
        durationMs: toolResult?.durationMs,
        note: toolResult?.timedOut
          ? 'Command timed out. Treat the output as partial.'
          : toolResult?.killed
            ? 'Command was killed. Treat the output as partial.'
            : (toolResult?.exitCode !== undefined && toolResult?.exitCode !== 0)
              ? 'Command exited non-zero. Output may be partial; later segments of a chained shell command may not have run.'
              : '',
        stdout: lineExcerpt(toolResult?.stdout, 12, Math.floor(softLimit * 0.45)),
        stderr: lineExcerpt(toolResult?.stderr, 10, Math.floor(softLimit * 0.35))
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

    case 'list_scheduled_tasks':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.success === false || toolResult?.error ? 'error' : 'ok',
        message: clampText(toolResult?.message || toolResult?.error || '', Math.floor(softLimit * 0.3)),
        count: typeof toolResult?.count === 'number'
          ? toolResult.count
          : (Array.isArray(toolResult?.tasks) ? toolResult.tasks.length : undefined),
        tasks: Array.isArray(toolResult?.tasks)
          ? toolResult.tasks.slice(0, 8).map((task) => trimObject({
            id: task?.id,
            name: task?.name,
            cronExpression: task?.cronExpression,
            ...(task?.oneTime ? { runAt: task?.runAt } : {}),
            oneTime: task?.oneTime,
            enabled: task?.enabled,
            ...(task?.model ? { model: task.model } : {})
          }))
          : undefined
      });
      break;

    case 'send_message':
    case 'make_call':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.skipped
          ? 'skipped'
          : (toolResult?.success === false || toolResult?.error ? 'error' : 'ok'),
        platform: toolArgs.platform,
        to: toolArgs.to,
        success: typeof toolResult?.success === 'boolean' ? toolResult.success : undefined,
        skipped: toolResult?.skipped === true ? true : undefined,
        sent: typeof toolResult?.sent === 'boolean' ? toolResult.sent : undefined,
        suppressed: toolResult?.suppressed === true ? true : undefined,
        message: clampText(toolResult?.message || toolResult?.reason || toolResult?.error || '', Math.floor(softLimit * 0.45)),
        result: clampText(JSON.stringify(trimObject({
          id: toolResult?.id,
          key: toolResult?.key,
          deleted: toolResult?.deleted,
          count: Array.isArray(toolResult?.results) ? toolResult.results.length : undefined
        })), Math.floor(softLimit * 0.3))
      });
      break;

    case 'send_interim_update':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.skipped
          ? 'skipped'
          : (toolResult?.sent === true ? 'ok' : 'error'),
        kind: toolResult?.kind || toolArgs.kind,
        expectsReply: toolResult?.expectsReply === true || toolResult?.waitingForUser === true,
        message: clampText(toolResult?.content || toolArgs.content || toolResult?.reason || '', Math.floor(softLimit * 0.55))
      });
      break;

    case 'memory_save':
    case 'memory_recall':
    case 'memory_update_core':
    case 'memory_read':
    case 'memory_write':
    case 'create_scheduled_task':
    case 'schedule_run':
    case 'delete_scheduled_task':
    case 'update_scheduled_task':
    case 'create_ai_widget':
    case 'update_ai_widget':
    case 'delete_ai_widget':
    case 'save_widget_snapshot':
      envelope = buildSimpleStatusEnvelope(toolName, toolResult, softLimit);
      break;

    case 'list_ai_widgets':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.success === false || toolResult?.error ? 'error' : 'ok',
        message: clampText(toolResult?.message || toolResult?.error || '', Math.floor(softLimit * 0.3)),
        count: typeof toolResult?.count === 'number'
          ? toolResult.count
          : (Array.isArray(toolResult?.widgets) ? toolResult.widgets.length : undefined),
        widgets: Array.isArray(toolResult?.widgets)
          ? toolResult.widgets.slice(0, 6).map((widget) => trimObject({
            id: widget?.id,
            name: widget?.name,
            template: widget?.template,
            layoutVariant: widget?.layoutVariant,
            refreshCron: widget?.refreshCron,
            enabled: widget?.enabled,
          }))
          : undefined,
      });
      break;

    case 'spawn_subagent':
      envelope = trimObject({
        tool: toolName,
        handle: toolResult?.handle,
        childRunId: toolResult?.childRunId,
        status: toolResult?.status,
        summary: clampText(toolResult?.task || toolResult?.error || '', Math.floor(softLimit * 0.55))
      });
      break;

    case 'list_subagents':
    case 'wait_subagent':
    case 'cancel_subagent':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.status || (Array.isArray(toolResult?.subagents) ? 'ok' : ''),
        summary: clampText(JSON.stringify(trimObject({
          handle: toolResult?.handle,
          childRunId: toolResult?.childRunId,
          timedOut: toolResult?.timedOut,
          count: Array.isArray(toolResult?.subagents) ? toolResult.subagents.length : undefined,
          error: toolResult?.error,
          result: toolResult?.result,
        })), Math.floor(softLimit * 0.6))
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
