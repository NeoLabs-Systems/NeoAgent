'use strict';

function normalizeQueryWindow(window = {}) {
  const timeMin = String(
    window.timeMin || window.time_min || window.start || '',
  ).trim() || null;
  const timeMax = String(
    window.timeMax || window.time_max || window.end || '',
  ).trim() || null;
  return { timeMin, timeMax };
}

function excludeStartedTimedEvents(events, executionInstant) {
  const instantMs = Date.parse(String(executionInstant || ''));
  if (!Number.isFinite(instantMs)) return Array.isArray(events) ? events : [];
  return (Array.isArray(events) ? events : []).filter((event) => {
    if (event?.allDay) return true;
    const startMs = Date.parse(String(event?.start || ''));
    return Number.isFinite(startMs) && startMs > instantMs;
  });
}

function partitionCalendarEvents(events, window = {}) {
  const listedEvents = Array.isArray(events) ? events : [];
  const listedTimedEvents = listedEvents.filter((event) => !event.allDay);
  const allDayEvents = listedEvents.filter((event) => event.allDay);
  const queryWindow = normalizeQueryWindow(window);
  const windowStartMs = Date.parse(queryWindow.timeMin || '');
  const windowEndMs = Date.parse(queryWindow.timeMax || '');
  const hasWindowStart = Number.isFinite(windowStartMs);
  const hasWindowEnd = Number.isFinite(windowEndMs);
  const ongoingTimedEvents = hasWindowStart
    ? listedTimedEvents.filter((event) => {
      const startMs = Date.parse(event.start || '');
      const endMs = Date.parse(event.end || '');
      return Number.isFinite(startMs)
        && startMs < windowStartMs
        && (!Number.isFinite(endMs) || endMs > windowStartMs);
    })
    : [];
  const upcomingTimedEvents = listedTimedEvents.filter((event) => {
    const startMs = Date.parse(event.start || '');
    return Number.isFinite(startMs)
      && (!hasWindowStart || startMs >= windowStartMs)
      && (!hasWindowEnd || startMs < windowEndMs);
  });
  const timedEvents = [...upcomingTimedEvents, ...ongoingTimedEvents];

  return {
    count: listedEvents.length,
    timedCount: timedEvents.length,
    upcomingTimedCount: upcomingTimedEvents.length,
    ongoingTimedCount: ongoingTimedEvents.length,
    allDayCount: allDayEvents.length,
    hasTimedEvents: timedEvents.length > 0,
    hasUpcomingTimedEvents: upcomingTimedEvents.length > 0,
    hasOngoingTimedEvents: ongoingTimedEvents.length > 0,
    hasOnlyOngoingTimedEvents: upcomingTimedEvents.length === 0
      && ongoingTimedEvents.length > 0,
    hasOnlyAllDayEvents: timedEvents.length === 0 && allDayEvents.length > 0,
    nextUpcomingTimedEvent: upcomingTimedEvents[0] || null,
    nextTimedEvent: upcomingTimedEvents[0] || null,
    queryWindow,
    upcomingTimedEvents,
    ongoingTimedEvents,
    timedEvents,
    allDayEvents,
    events: [...timedEvents, ...allDayEvents],
  };
}

function applyCalendarListMode(summary, options = {}) {
  const includeOngoing = options.includeOngoing === true;
  const includeAllDay = options.includeAllDay === true;
  const upcomingTimedEvents = summary.upcomingTimedEvents || [];
  const ongoingTimedEvents = includeOngoing
    ? (summary.ongoingTimedEvents || [])
    : [];
  const allDayEvents = includeAllDay ? (summary.allDayEvents || []) : [];
  const timedEvents = [...upcomingTimedEvents, ...ongoingTimedEvents];
  const omittedOngoingTimedCount = includeOngoing
    ? 0
    : Number(summary.ongoingTimedCount || 0);
  const omittedAllDayCount = includeAllDay
    ? 0
    : Number(summary.allDayCount || 0);

  return {
    ...summary,
    count: timedEvents.length + allDayEvents.length,
    overlapCount: Number(summary.count || 0),
    timedCount: timedEvents.length,
    ongoingTimedCount: ongoingTimedEvents.length,
    allDayCount: allDayEvents.length,
    omittedOngoingTimedCount,
    omittedAllDayCount,
    hasTimedEvents: timedEvents.length > 0,
    hasOngoingTimedEvents: ongoingTimedEvents.length > 0,
    hasOnlyOngoingTimedEvents: false,
    hasOnlyAllDayEvents: timedEvents.length === 0 && allDayEvents.length > 0,
    hasOnlyOmittedOverlaps: upcomingTimedEvents.length === 0
      && omittedOngoingTimedCount + omittedAllDayCount > 0,
    windowMode: includeOngoing ? 'overlap' : 'starts_within_window',
    ongoingTimedEvents,
    timedEvents,
    allDayEvents,
    events: [...timedEvents, ...allDayEvents],
  };
}

function finalizeListedCalendarEvents(events, options = {}) {
  const args = options.args || {};
  const executionOptions = options.executionOptions || {};
  const window = {
    timeMin: options.timeMin,
    timeMax: options.timeMax,
    start: options.start,
    end: options.end,
  };
  const queryWindow = normalizeQueryWindow(window);
  const hasWindowStart = Boolean(queryWindow.timeMin);
  const automaticReminder = (
    (executionOptions.triggerSource === 'schedule' || executionOptions.triggerSource === 'tasks')
    && executionOptions.taskId
    && args.include_ongoing !== true
  );
  const listed = automaticReminder
    ? excludeStartedTimedEvents(events, executionOptions.scheduledAt)
    : (Array.isArray(events) ? events : []);
  const summary = partitionCalendarEvents(listed, window);
  return applyCalendarListMode(summary, {
    includeOngoing: !hasWindowStart || args.include_ongoing === true,
    includeAllDay: !hasWindowStart || args.include_all_day === true,
  });
}

module.exports = {
  applyCalendarListMode,
  excludeStartedTimedEvents,
  finalizeListedCalendarEvents,
  normalizeQueryWindow,
  partitionCalendarEvents,
};
