'use strict';

const { resolveAgentId } = require('../agents/manager');
const { normalizeJsonObject } = require('./utils');

const POLLED_TRIGGER_TYPES = Object.freeze([
  'gmail_message_received',
  'outlook_email_received',
  'slack_message_received',
  'teams_message_received',
  'weather_event',
  'whatsapp_personal_message_received',
]);

function sortByTimestamp(left, right) {
  return String(left.timestamp).localeCompare(String(right.timestamp));
}

async function fetchTriggerRows({ integrationManager, userId, agentId, triggerType, config }) {
  if (!integrationManager) return [];
  const scopedAgentId = resolveAgentId(userId, agentId);
  const connectionArg = {
    connection_id: config.connectionId,
    account_email: config.accountEmail || undefined,
  };

  if (triggerType === 'gmail_message_received') {
    const queryParts = [];
    if (config.query) queryParts.push(config.query);
    if (config.unreadOnly) queryParts.push('is:unread');
    const result = await integrationManager.executeTool(userId, 'google_workspace_gmail_api_request', {
      ...connectionArg,
      method: 'GET',
      path: '/gmail/v1/users/me/messages',
      query: {
        maxResults: 20,
        q: queryParts.join(' ').trim() || undefined,
      },
    }, scopedAgentId);
    const messages = Array.isArray(result?.messages) ? result.messages : [];
    return messages
      .map((item) => ({
        fingerprint: `gmail:${config.connectionId}:${item.id}`,
        timestamp: new Date().toISOString(),
        context: { triggerEvent: { provider: 'gmail', messageId: item.id, threadId: item.threadId || null } },
      }))
      .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
  }

  if (triggerType === 'outlook_email_received') {
    const filters = [];
    const escapedQuery = String(config.query || '').replace(/"/g, '\\"');
    if (config.unreadOnly) filters.push('isRead eq false');
    const result = await integrationManager.executeTool(userId, 'microsoft_365_outlook_graph_request', {
      ...connectionArg,
      method: 'GET',
      path: config.folderId
        ? `/v1.0/me/mailFolders/${encodeURIComponent(config.folderId)}/messages`
        : '/v1.0/me/messages',
      query: {
        '$top': 20,
        ...(filters.length ? { '$filter': filters.join(' and ') } : {}),
        ...(escapedQuery ? { '$search': `"${escapedQuery}"` } : {}),
      },
    }, scopedAgentId);
    const messages = Array.isArray(result?.value) ? result.value : [];
    return messages
      .map((item) => ({
        fingerprint: `outlook:${config.connectionId}:${item.id}`,
        timestamp: item.receivedDateTime || new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'outlook',
            messageId: item.id,
            subject: item.subject || '',
            from: item.from?.emailAddress?.address || null,
          },
        },
      }))
      .sort(sortByTimestamp);
  }

  if (triggerType === 'slack_message_received') {
    const result = await integrationManager.executeTool(userId, 'slack_get_conversation_history', {
      ...connectionArg,
      channel: config.channel,
      limit: 20,
    }, scopedAgentId);
    const messages = Array.isArray(result?.result?.messages)
      ? result.result.messages
      : Array.isArray(result?.messages)
      ? result.messages
      : [];
    return messages
      .filter((item) => !config.sender || String(item.user || '') === String(config.sender))
      .map((item) => ({
        fingerprint: `slack:${config.connectionId}:${config.channel}:${item.ts}`,
        timestamp: item.ts || new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'slack',
            channel: config.channel,
            sender: item.user || null,
            messageId: item.client_msg_id || item.ts,
            content: item.text || '',
          },
        },
      }))
      .sort(sortByTimestamp);
  }

  if (triggerType === 'teams_message_received') {
    const result = await integrationManager.executeTool(userId, 'microsoft_365_teams_graph_request', {
      ...connectionArg,
      method: 'GET',
      path: `/v1.0/me/chats/${encodeURIComponent(config.chatId)}/messages`,
      query: { '$top': 20 },
    }, scopedAgentId);
    const messages = Array.isArray(result?.value) ? result.value : [];
    return messages
      .filter((item) => {
        const sender = item.from?.user?.id || item.from?.application?.id || '';
        return !config.sender || String(sender) === String(config.sender);
      })
      .map((item) => ({
        fingerprint: `teams:${config.connectionId}:${config.chatId}:${item.id}`,
        timestamp: item.createdDateTime || new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'teams',
            chatId: config.chatId,
            messageId: item.id,
            sender: item.from?.user?.id || null,
            content: item.body?.content || '',
          },
        },
      }))
      .sort(sortByTimestamp);
  }

  if (triggerType === 'whatsapp_personal_message_received') {
    const result = await integrationManager.executeTool(userId, 'whatsapp_personal_get_messages', {
      ...connectionArg,
      chat_id: config.chatId,
      limit: 25,
    }, scopedAgentId);
    const messages = Array.isArray(result?.messages) ? result.messages : [];
    return messages
      .filter((item) => item && item.fromMe !== true)
      .filter((item) => !config.sender || String(item.senderTag || item.sender || '') === String(config.sender))
      .filter((item) => !(config.ignoreGroups && String(item.chatId || '').endsWith('@g.us')))
      .map((item) => ({
        fingerprint: `whatsapp:${config.connectionId}:${item.id}`,
        timestamp: item.timestamp || new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'whatsapp_personal',
            chatId: item.chatId,
            messageId: item.id,
            sender: item.sender || null,
            senderTag: item.senderTag || null,
            content: item.text || '',
            isGroup: String(item.chatId || '').endsWith('@g.us'),
          },
        },
      }))
      .sort(sortByTimestamp);
  }

  if (triggerType === 'weather_event') {
    const forecast = await integrationManager.executeTool(userId, 'weather_get_forecast', {
      ...connectionArg,
      ...(config.location ? { location: config.location } : {}),
      forecast_hours: Math.max(1, Math.min(Number(config.horizonHours) || 12, 48)),
    }, scopedAgentId);
    const hourly = Array.isArray(forecast?.hourly) ? forecast.hourly : [];
    const eventTypes = Array.isArray(config.eventTypes) ? config.eventTypes : [];
    const rows = [];

    for (let index = 0; index < hourly.length; index += 1) {
      const row = hourly[index] || {};
      const previous = index > 0 ? (hourly[index - 1] || {}) : null;
      const time = String(row.time || '').trim();
      if (!time) continue;

      const rain = Number(row.rain || row.precipitation || 0);
      const prevRain = Number(previous?.rain || previous?.precipitation || 0);
      const snowfall = Number(row.snowfall || 0);
      const prevSnow = Number(previous?.snowfall || 0);
      const windSpeed = Number(row.windSpeed || 0);
      const temperature = Number(row.temperature);

      const candidates = [
        {
          type: 'rain_start',
          active:
            eventTypes.includes('rain_start')
            && rain >= Number(config.minPrecipitationMm || 0.4)
            && prevRain < Number(config.minPrecipitationMm || 0.4),
        },
        {
          type: 'snow_start',
          active:
            eventTypes.includes('snow_start')
            && snowfall >= Number(config.minSnowfallCm || 0.2)
            && prevSnow < Number(config.minSnowfallCm || 0.2),
        },
        {
          type: 'wind_alert',
          active:
            eventTypes.includes('wind_alert')
            && windSpeed >= Number(config.windAlertKph || 40),
        },
        {
          type: 'temperature_above',
          active:
            eventTypes.includes('temperature_above')
            && Number.isFinite(temperature)
            && temperature >= Number(config.temperatureAboveC || 32),
        },
        {
          type: 'temperature_below',
          active:
            eventTypes.includes('temperature_below')
            && Number.isFinite(temperature)
            && temperature <= Number(config.temperatureBelowC || 0),
        },
      ];

      for (const candidate of candidates) {
        if (!candidate.active) continue;
        rows.push({
          fingerprint: `weather:${config.connectionId}:${candidate.type}:${time}`,
          timestamp: time,
          context: {
            triggerEvent: {
              provider: 'weather',
              eventType: candidate.type,
              location: forecast?.location?.label || config.location || null,
              time,
              rain,
              snowfall,
              windSpeed,
              temperature,
            },
          },
        });
      }
    }

    return rows.sort(sortByTimestamp);
  }

  return [];
}

async function pollIntegrationTask(runtime, task) {
  const config = normalizeJsonObject(task.trigger_config);
  const rows = await fetchTriggerRows({
    integrationManager: runtime.integrationManager,
    userId: task.user_id,
    agentId: task.agent_id,
    triggerType: task.trigger_type,
    config,
  });
  if (!rows.length) return;

  const existingFingerprint = String(task.last_trigger_fingerprint || '');
  const latestFingerprint = rows[rows.length - 1].fingerprint;
  if (!existingFingerprint) {
    runtime.taskRepository.markTaskTriggerCheckpoint(task.id, latestFingerprint);
    return;
  }

  const startIndex = rows.findIndex((row) => row.fingerprint === existingFingerprint);
  const pending = startIndex >= 0 ? rows.slice(startIndex + 1) : rows.slice(-1);
  for (const row of pending) {
    await runtime.fireTaskFromTrigger(task.id, task.user_id, row);
  }
}

function createWhatsappTriggerPayload(event) {
  return {
    fingerprint: `whatsapp:${event.connectionId}:${event.messageId}`,
    timestamp: event.timestamp,
    context: {
      triggerEvent: {
        provider: 'whatsapp_personal',
        chatId: event.chatId,
        sender: event.sender,
        senderTag: event.senderTag || null,
        messageId: event.messageId,
        content: event.text || '',
        isGroup: event.isGroup === true,
      },
    },
  };
}

function matchesWhatsappTaskEvent(task, event) {
  const config = normalizeJsonObject(task.trigger_config);
  if (String(config.connectionId || '') !== String(event.connectionId || '')) return false;
  if (config.chatId && String(config.chatId) !== String(event.chatId)) return false;
  if (config.sender && String(config.sender) !== String(event.senderTag || event.sender || '')) return false;
  if (config.ignoreGroups && event.isGroup) return false;
  return true;
}

function attachIntegrationEventSources(runtime) {
  const cleanups = [];
  const provider = runtime.integrationManager?.getProvider?.('whatsapp_personal');
  if (provider && typeof provider.on === 'function') {
    const listener = async (event) => {
      const tasks = runtime.taskRepository.listEnabledWhatsappEventTasks(event.userId, event.agentId);
      for (const task of tasks) {
        if (!matchesWhatsappTaskEvent(task, event)) continue;
        await runtime.fireTaskFromTrigger(task.id, task.user_id, createWhatsappTriggerPayload(event)).catch((error) => {
          const logger = runtime.logger?.error || console.error;
          logger('[Tasks] Failed to fire WhatsApp task trigger', {
            taskId: task.id,
            userId: task.user_id,
            agentId: event.agentId,
            error: error?.message || String(error),
          });
        });
      }
    };
    provider.on('message', listener);
    cleanups.push(() => {
      if (typeof provider.off === 'function') {
        provider.off('message', listener);
      } else if (typeof provider.removeListener === 'function') {
        provider.removeListener('message', listener);
      }
    });
  }
  return cleanups;
}

module.exports = {
  POLLED_TRIGGER_TYPES,
  attachIntegrationEventSources,
  fetchTriggerRows,
  pollIntegrationTask,
};
