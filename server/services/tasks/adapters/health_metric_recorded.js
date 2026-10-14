'use strict';

const { normalizeMetricType } = require('../../health/ingestion');
const { optionalNumber, requiredText, summaryParts } = require('./shared');

function matchingRecords(config, records) {
  return (records || []).filter((record) => {
    if (normalizeMetricType(record.metricType) !== config.metricType) return false;
    if (config.above === null && config.below === null) return true;
    const value = record.numericValue;
    if (!Number.isFinite(value)) return false;
    return (config.above === null || value > config.above) && (config.below === null || value < config.below);
  });
}

function recordTime(record) {
  return record.recordedAt || record.endTime || record.startTime || '';
}

// A phone sync carries many samples; a task runs once per sync, on the newest
// sample that matches.
module.exports = {
  type: 'health_metric_recorded',
  label: 'Health Metric Recorded',
  configHint: '{ metricType: e.g. heart_rate|steps|weight|sleep_session, above?: number, below?: number }; arrives with each phone health sync',
  async validateConfig(config = {}) {
    return {
      metricType: normalizeMetricType(requiredText(config.metricType || config.metric_type, 80, 'Health metric type is required.')),
      above: optionalNumber(config.above),
      below: optionalNumber(config.below),
    };
  },
  summarize(config = {}) {
    return summaryParts('Health', [
      config.metricType,
      config.above !== null && config.above !== undefined && `above ${config.above}`,
      config.below !== null && config.below !== undefined && `below ${config.below}`,
    ]);
  },
  event: {
    source: 'runtime',
    name: 'health_sync',
    matches(config, event) {
      return matchingRecords(config, event.records).length > 0;
    },
    toPayload(event, config) {
      const matches = matchingRecords(config, event.records)
        .sort((left, right) => recordTime(left).localeCompare(recordTime(right)));
      const latest = matches[matches.length - 1];
      return {
        fingerprint: `health:${config.metricType}:${latest.recordId}`,
        timestamp: recordTime(latest) || event.syncedAt,
        context: {
          triggerEvent: {
            provider: 'health',
            event: 'metric_recorded',
            metricType: config.metricType,
            value: latest.numericValue,
            text: latest.textValue,
            unit: latest.unit,
            recordedAt: recordTime(latest) || null,
            matchingSamples: matches.length,
          },
        },
      };
    },
  },
};
