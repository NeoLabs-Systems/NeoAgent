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

function lineExcerptWasTruncated(text, maxLines, maxChars) {
  const str = String(text || '').trim();
  if (!str) return false;
  const lines = str.split('\n');
  if (lines.length > maxLines) return true;
  return lines.join('\n').length > maxChars;
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
        stdoutBytes: toolResult?.stdoutBytes,
        stderrBytes: toolResult?.stderrBytes,
        truncated: toolResult?.truncated === true,
        outputArtifact: toolResult?.outputArtifact,
        artifactError: toolResult?.artifactError,
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

    case 'read_artifact':
      envelope = trimObject({
        tool: toolName,
        artifactId: toolResult?.artifactId || toolArgs.artifact_id,
        contentType: toolResult?.contentType,
        byteSize: toolResult?.byteSize,
        binary: toolResult?.binary === true,
        rangeShown: toolResult?.rangeShown,
        totalLines: toolResult?.totalLines,
        truncated: toolResult?.truncated === true,
        content: lineExcerpt(toolResult?.content || '', 30, Math.floor(softLimit * 0.72)),
        error: toolResult?.error,
      });
      break;

    case 'read_file':
      {
        const content = String(toolResult?.content || toolResult || '');
        const contentLimit = Math.floor(softLimit * 0.7);
        const truncated = toolResult?.truncated === true
          || content.includes('...[truncated')
          || lineExcerptWasTruncated(content, 20, contentLimit);
        envelope = trimObject({
          tool: toolName,
          path: toolArgs.path,
          startLine: toolArgs.start_line,
          endLine: toolArgs.end_line,
          rangeShown: toolResult?.rangeShown,
          totalLines: toolResult?.totalLines,
          truncated,
          note: truncated
            ? 'Only part of the file was returned. Read a narrower line range to recover the omitted content.'
            : undefined,
          content: lineExcerpt(content, 20, contentLimit)
        });
        break;
      }

    case 'read_files':
      {
        const sourceResults = toolResult?.results || [];
        const contentLimit = Math.floor(softLimit * 0.22);
        const itemWasTruncated = (item) => item?.truncated === true
          || lineExcerptWasTruncated(item?.content || '', 10, contentLimit);
        const truncated = toolResult?.truncated === true
          || sourceResults.length > 6
          || sourceResults.some(itemWasTruncated);
        envelope = trimObject({
          tool: toolName,
          count: toolResult?.count || 0,
          truncated,
          note: truncated
            ? 'Only part of the requested file set was returned. Split the request or read individual files and narrower line ranges.'
            : undefined,
          results: sourceResults.slice(0, 6).map((item) => trimObject({
            path: item.path || item.requestedPath,
            requestedPath: item.requestedPath,
            rangeShown: item.rangeShown,
            truncated: itemWasTruncated(item),
            error: item.error,
            content: lineExcerpt(item.content || '', 10, contentLimit)
          }))
        });
        break;
      }

    case 'replace_file_range':
      envelope = trimObject({
        tool: toolName,
        status: toolResult?.success === false || toolResult?.error ? 'error' : 'ok',
        path: toolResult?.path || toolArgs.path,
        startLine: toolResult?.startLine || toolArgs.start_line,
        endLine: toolResult?.endLine || toolArgs.end_line,
        replacedLines: toolResult?.replacedLines,
        insertedLines: toolResult?.insertedLines,
        totalLines: toolResult?.totalLines,
        error: toolResult?.error
      });
      break;

    case 'search_files':
      {
        const matches = toolResult?.matches || [];
        const count = toolResult?.count || matches.length;
        const truncated = toolResult?.truncated === true || count > 6 || matches.length > 6;
        envelope = trimObject({
          tool: toolName,
          count,
          truncated,
          note: truncated
            ? 'Only the first matches are shown. Narrow the path or search pattern, or read the matched files around the relevant lines.'
            : undefined,
          matches: matches.slice(0, 6).map((match) => trimObject({
            file: match.file,
            line: match.line,
            content: clampText(match.content, 160)
          }))
        });
        break;
      }

    case 'browser_extract':
      envelope = trimObject({
        tool: toolName,
        selector: toolArgs.selector || 'body',
        attribute: toolArgs.attribute || 'innerText',
        excerpt: lineExcerpt(toolResult?.result || toolResult?.content || toolResult, 18, Math.floor(softLimit * 0.7))
      });
      break;

    case 'social_video_extract':
      envelope = trimObject({
        tool: toolName,
        platform: toolResult?.platform,
        sourceUrl: toolResult?.sourceUrl,
        resolvedUrl: toolResult?.resolvedUrl,
        title: clampText(toolResult?.title || '', Math.floor(softLimit * 0.25)),
        description: clampText(toolResult?.description || '', Math.floor(softLimit * 0.25)),
        transcriptSource: toolResult?.transcriptSource,
        transcriptPreview: lineExcerpt(toolResult?.transcript || '', 6, Math.floor(softLimit * 0.35)),
        frameImage: trimObject({
          url: toolResult?.frameImage?.url,
          source: toolResult?.frameImage?.source,
        }),
        setupReady: toolResult?.setup?.ready,
        warningCount: Array.isArray(toolResult?.warnings) ? toolResult.warnings.length : 0,
        errorCount: Array.isArray(toolResult?.errors) ? toolResult.errors.length : 0,
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

    case 'list_tasks':
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
            triggerType: task?.triggerType,
            triggerSummary: task?.triggerSummary,
            enabled: task?.enabled,
            ...(task?.model ? { model: task.model } : {})
          }))
          : undefined
      });
      break;

    case 'send_message':
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
    case 'create_task':
    case 'delete_task':
    case 'update_task':
      envelope = buildSimpleStatusEnvelope(toolName, toolResult, softLimit);
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

    case 'google_workspace_calendar_list_events': {
      // Emit a compact, complete digest and preserve the provider's window-aware
      // distinction: an event can be timed yet already running when the queried
      // window begins. Reminder logic must only treat upcomingTimed as a new start.
      const events = Array.isArray(toolResult?.events)
        ? toolResult.events
        : [
          ...(Array.isArray(toolResult?.timedEvents) ? toolResult.timedEvents : []),
          ...(Array.isArray(toolResult?.allDayEvents) ? toolResult.allDayEvents : []),
        ];
      const timed = events.filter((event) => !event?.allDay);
      const hasTimedPartitions = Array.isArray(toolResult?.upcomingTimedEvents)
        || Array.isArray(toolResult?.ongoingTimedEvents);
      const upcomingTimed = hasTimedPartitions
        ? (Array.isArray(toolResult?.upcomingTimedEvents) ? toolResult.upcomingTimedEvents : [])
        : timed;
      const ongoingTimed = hasTimedPartitions
        ? (Array.isArray(toolResult?.ongoingTimedEvents) ? toolResult.ongoingTimedEvents : [])
        : [];
      const allDay = Array.isArray(toolResult?.allDayEvents)
        ? toolResult.allDayEvents
        : events.filter((event) => event?.allDay);
      const queryWindow = trimObject({
        timeMin: toolResult?.queryWindow?.timeMin || toolArgs.time_min || toolArgs.timeMin,
        timeMax: toolResult?.queryWindow?.timeMax || toolArgs.time_max || toolArgs.timeMax,
      });
      envelope = trimObject({
        tool: toolName,
        queryWindow: Object.keys(queryWindow).length > 0 ? queryWindow : undefined,
        count: typeof toolResult?.count === 'number' ? toolResult.count : events.length,
        timedCount: typeof toolResult?.timedCount === 'number' ? toolResult.timedCount : timed.length,
        upcomingTimedCount: typeof toolResult?.upcomingTimedCount === 'number'
          ? toolResult.upcomingTimedCount
          : upcomingTimed.length,
        ongoingTimedCount: typeof toolResult?.ongoingTimedCount === 'number'
          ? toolResult.ongoingTimedCount
          : ongoingTimed.length,
        allDayCount: typeof toolResult?.allDayCount === 'number' ? toolResult.allDayCount : allDay.length,
        hasUpcomingTimedEvents: toolResult?.hasUpcomingTimedEvents === true || upcomingTimed.length > 0,
        hasOngoingTimedEvents: toolResult?.hasOngoingTimedEvents === true || ongoingTimed.length > 0,
        hasOnlyOngoingTimedEvents: toolResult?.hasOnlyOngoingTimedEvents === true
          || (upcomingTimed.length === 0 && ongoingTimed.length > 0),
        hasOnlyAllDayEvents: toolResult?.hasOnlyAllDayEvents === true
          || (timed.length === 0 && allDay.length > 0),
        upcomingTimed: upcomingTimed.map((event) => trimObject({
          summary: clampText(event?.summary || '(no title)', 140),
          start: event?.start || null,
          end: event?.end || null,
          location: event?.location ? clampText(event.location, 80) : undefined,
          status: event?.status && event.status !== 'confirmed' ? event.status : undefined,
        })),
        ongoingTimed: ongoingTimed.map((event) => trimObject({
          summary: clampText(event?.summary || '(no title)', 140),
          start: event?.start || null,
          end: event?.end || null,
          location: event?.location ? clampText(event.location, 80) : undefined,
          status: event?.status && event.status !== 'confirmed' ? event.status : undefined,
        })),
        // All-day entries are usually birthdays / markers — names + dates suffice.
        allDay: allDay.map((event) => trimObject({
          summary: clampText(event?.summary || '(no title)', 140),
          start: event?.start || null,
          end: event?.end || null,
        })),
      });
      break;
    }

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
