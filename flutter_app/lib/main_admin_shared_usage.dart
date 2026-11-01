part of 'main.dart';

// The "Shared usage" part of the admin Analytics tab: totals from accounts
// that opted in to usage data sharing (`sharedUsage` in /api/admin/analytics).

typedef _AdminCount = ({String label, int count});

List<_AdminCount> _adminCounts(Object? raw) => <_AdminCount>[
  for (final row in _jsonMapList(raw))
    (label: _asText(row['label'], fallback: ''), count: _asInt(row['count'])),
];

class _AdminSharedUsage {
  const _AdminSharedUsage({
    required this.sharing,
    required this.total,
    required this.platforms,
    required this.appVersions,
    required this.languages,
    required this.regions,
    required this.features,
    required this.integrations,
    required this.messaging,
    required this.triggers,
    required this.tools,
    required this.activity,
    required this.outcomes,
    required this.models,
  });

  factory _AdminSharedUsage.fromJson(Map<String, dynamic> json) {
    final participants = _jsonMap(json['participants']);
    final audience = _jsonMap(json['audience']);
    // Seven rows, Monday first, of 24 hourly run counts.
    final activity = List<List<int>>.generate(
      7,
      (_) => List<int>.filled(24, 0),
    );
    for (final cell in _jsonMapList(json['activity'])) {
      final weekday = _asInt(cell['weekday']);
      final hour = _asInt(cell['hour']);
      if (weekday < 0 || weekday > 6 || hour < 0 || hour > 23) continue;
      activity[(weekday + 6) % 7][hour] = _asInt(cell['runs']);
    }
    final outcomes = _jsonMap(json['outcomes']);
    return _AdminSharedUsage(
      sharing: _asInt(participants['sharing']),
      total: _asInt(participants['total']),
      platforms: _adminCounts(audience['platforms']),
      appVersions: _adminCounts(audience['appVersions']),
      languages: _adminCounts(audience['languages']),
      regions: _adminCounts(audience['regions']),
      features: <({String key, int users})>[
        for (final row in _jsonMapList(json['features']))
          (key: _asText(row['key']), users: _asInt(row['users'])),
      ],
      integrations: _adminCounts(json['integrations']),
      messaging: _adminCounts(json['messaging']),
      triggers: _adminCounts(json['triggers']),
      tools: <({String tool, int calls, int failures})>[
        for (final row in _jsonMapList(json['tools']))
          (
            tool: _asText(row['tool']),
            calls: _asInt(row['calls']),
            failures: _asInt(row['failures']),
          ),
      ],
      activity: activity,
      outcomes: (
        runs: _asInt(outcomes['runs']),
        successRate: _asInt(outcomes['successRate']),
        avgDurationSeconds: _asInt(outcomes['avgDurationSeconds']),
        avgTokens: _asInt(outcomes['avgTokens']),
        avgSteps: (outcomes['avgSteps'] as num?)?.toDouble() ?? 0,
      ),
      models:
          <
            ({
              String model,
              int calls,
              int avgLatencyMs,
              int inputTokens,
              int cachedTokens,
              double? costUsd,
            })
          >[
            for (final row in _jsonMapList(json['models']))
              (
                model: '${_asText(row['provider'])} / ${_asText(row['model'])}',
                calls: _asInt(row['calls']),
                avgLatencyMs: _asInt(row['avgLatencyMs']),
                inputTokens: _asInt(row['inputTokens']),
                cachedTokens: _asInt(row['cachedTokens']),
                costUsd: (row['costUsd'] as num?)?.toDouble(),
              ),
          ],
    );
  }

  final int sharing;
  final int total;
  final List<_AdminCount> platforms;
  final List<_AdminCount> appVersions;
  final List<_AdminCount> languages;
  final List<_AdminCount> regions;
  final List<({String key, int users})> features;
  final List<_AdminCount> integrations;
  final List<_AdminCount> messaging;
  final List<_AdminCount> triggers;
  final List<({String tool, int calls, int failures})> tools;
  final List<List<int>> activity;
  final ({
    int runs,
    int successRate,
    int avgDurationSeconds,
    int avgTokens,
    double avgSteps,
  })
  outcomes;
  final List<
    ({
      String model,
      int calls,
      int avgLatencyMs,
      int inputTokens,
      int cachedTokens,
      double? costUsd,
    })
  >
  models;
}

const Map<String, String> _adminPlatformLabels = <String, String>{
  'android': 'Android',
  'ios': 'iOS',
  'web': 'Web',
  'macos': 'macOS',
  'windows': 'Windows',
  'linux': 'Linux',
};

String _adminFeatureLabel(String key) {
  switch (key) {
    case 'agents':
      return appStrings.sharedUsageFeatureAgents;
    case 'scheduledTasks':
      return appStrings.sharedUsageFeatureTasks;
    case 'skills':
      return appStrings.sharedUsageFeatureSkills;
    case 'mcpServers':
      return appStrings.sharedUsageFeatureMcp;
    case 'integrations':
      return appStrings.sharedUsageFeatureIntegrations;
    case 'messaging':
      return appStrings.sharedUsageFeatureMessaging;
    case 'memory':
      return appStrings.sharedUsageFeatureMemory;
  }
  return key;
}

/// "agent_delegation" reads as "Agent delegation".
String _adminHumanize(String value) {
  final words = value.replaceAll('_', ' ').trim();
  if (words.isEmpty) return value;
  return words[0].toUpperCase() + words.substring(1);
}

String _adminLatency(int milliseconds) => milliseconds >= 1000
    ? '${(milliseconds / 1000).toStringAsFixed(1)}s'
    : '${milliseconds}ms';

int _adminPercent(int part, int whole) =>
    whole == 0 ? 0 : (part * 100 / whole).round();

/// The cards for the shared-usage part of the report, in order.
List<Widget> _adminSharedUsageCards(_AdminSharedUsage data, String rangeLabel) {
  final header = _SectionCard(
    title: appStrings.sharedUsageTitle,
    description: appStrings.sharedUsageParticipants(data.sharing, data.total),
    trailing: _AdminSharedUsageShare(sharing: data.sharing, total: data.total),
    child: data.sharing == 0
        ? _EmptyText(appStrings.sharedUsageEmpty)
        : _AdminOpsStatGrid(
            stats: <({String title, String value, String helper})>[
              (
                title: appStrings.sharedUsageRuns,
                value: _formatNumber(data.outcomes.runs),
                helper: appStrings.lastArg1(rangeLabel),
              ),
              (
                title: appStrings.successRate,
                value: '${data.outcomes.successRate}%',
                helper: appStrings.sharedUsageCompletedRuns,
              ),
              (
                title: appStrings.sharedUsageAvgDuration,
                value: _formatElapsed(
                  Duration(seconds: data.outcomes.avgDurationSeconds),
                ),
                helper: appStrings.sharedUsageCompletedRuns,
              ),
              (
                title: appStrings.sharedUsageStepsPerRun,
                value: data.outcomes.avgSteps.toStringAsFixed(1),
                helper: appStrings.lastArg1(rangeLabel),
              ),
              (
                title: appStrings.tokensPerRun,
                value: _formatTokenCount(data.outcomes.avgTokens),
                helper: appStrings.lastArg1(rangeLabel),
              ),
            ],
          ),
  );
  if (data.sharing == 0) return <Widget>[header];

  _AdminOpsRankedItem shareOfSharers(String label, int count, {Color? color}) {
    return _AdminOpsRankedItem(
      label: label,
      value: count,
      valueLabel: '${_adminPercent(count, data.sharing)}%',
      detail: appStrings.sharedUsageAccounts(count),
      color: color,
    );
  }

  Widget accountsCard(
    String title,
    List<_AdminCount> counts, {
    String Function(String label)? labelOf,
    Color? color,
  }) {
    return _SectionCard(
      title: title,
      child: _AdminOpsRankedList(
        emptyText: appStrings.sharedUsageNotReported,
        items: <_AdminOpsRankedItem>[
          for (final entry in counts)
            shareOfSharers(
              labelOf?.call(entry.label) ?? entry.label,
              entry.count,
              color: color,
            ),
        ],
      ),
    );
  }

  final runsInRange = data.triggers.fold<int>(0, (sum, e) => sum + e.count);
  return <Widget>[
    header,
    _AdminOpsPair(
      first: accountsCard(
        appStrings.sharedUsageDevices,
        data.platforms,
        labelOf: (key) => _adminPlatformLabels[key] ?? key,
      ),
      second: accountsCard(
        appStrings.sharedUsageAppVersions,
        data.appVersions,
        color: _info,
      ),
    ),
    _AdminOpsPair(
      first: accountsCard(
        appStrings.sharedUsageLanguages,
        data.languages,
        labelOf: (code) => AppLanguage.fromCode(code)?.label ?? code,
        color: _accentAlt,
      ),
      second: accountsCard(
        appStrings.sharedUsageRegions,
        data.regions,
        color: _accentAlt,
      ),
    ),
    _SectionCard(
      title: appStrings.sharedUsageFeatures,
      description: appStrings.sharedUsageFeaturesDescription,
      child: _AdminOpsRankedList(
        emptyText: appStrings.sharedUsageNoData,
        items: <_AdminOpsRankedItem>[
          for (final entry in [
            ...data.features,
          ]..sort((a, b) => b.users.compareTo(a.users)))
            shareOfSharers(_adminFeatureLabel(entry.key), entry.users),
        ],
      ),
    ),
    _AdminOpsPair(
      first: _SectionCard(
        title: appStrings.sharedUsageTools,
        description: appStrings.sharedUsageToolsDescription(rangeLabel),
        child: _AdminOpsRankedList(
          emptyText: appStrings.sharedUsageNoData,
          items: <_AdminOpsRankedItem>[
            for (final entry in data.tools)
              _AdminOpsRankedItem(
                label: entry.tool,
                value: entry.calls,
                valueLabel: appStrings.sharedUsageToolCalls(
                  _formatNumber(entry.calls),
                ),
                detail: appStrings.sharedUsageToolFailures(
                  _adminPercent(entry.failures, entry.calls),
                ),
                color: _adminPercent(entry.failures, entry.calls) >= 20
                    ? _warning
                    : null,
                mono: true,
              ),
          ],
        ),
      ),
      second: _SectionCard(
        title: appStrings.sharedUsageTriggers,
        description: appStrings.arg1RunsInTheLastArg2(
          _formatNumber(runsInRange),
          rangeLabel,
        ),
        child: _AdminOpsRankedList(
          emptyText: appStrings.sharedUsageNoData,
          items: <_AdminOpsRankedItem>[
            for (final entry in data.triggers)
              _AdminOpsRankedItem(
                label: _adminHumanize(entry.label),
                value: entry.count,
                valueLabel: _formatNumber(entry.count),
                detail: '${_adminPercent(entry.count, runsInRange)}%',
                color: _info,
              ),
          ],
        ),
      ),
    ),
    _SectionCard(
      title: appStrings.sharedUsageActivity,
      description: appStrings.sharedUsageActivityDescription,
      child: _AdminActivityHeatmap(activity: data.activity),
    ),
    _AdminOpsPair(
      first: accountsCard(
        appStrings.sharedUsageIntegrations,
        data.integrations,
        labelOf: _adminHumanize,
      ),
      second: _SectionCard(
        title: appStrings.sharedUsageMessaging,
        child: _AdminOpsRankedList(
          emptyText: appStrings.sharedUsageNoData,
          items: <_AdminOpsRankedItem>[
            for (final entry in data.messaging)
              shareOfSharers(
                _taskDeliveryPlatformLabel(entry.label),
                entry.count,
                color: _taskDeliveryPlatformColor(entry.label),
              ),
          ],
        ),
      ),
    ),
    _SectionCard(
      title: appStrings.sharedUsageModels,
      description: appStrings.mostUsedModelsInTheLast(rangeLabel),
      child: _AdminOpsRankedList(
        emptyText: appStrings.sharedUsageNoData,
        items: <_AdminOpsRankedItem>[
          for (final entry in data.models)
            _AdminOpsRankedItem(
              label: entry.model,
              value: entry.calls,
              valueLabel: appStrings.sharedUsageToolCalls(
                _formatNumber(entry.calls),
              ),
              detail: appStrings.sharedUsageModelDetail(
                _adminLatency(entry.avgLatencyMs),
                _adminPercent(entry.cachedTokens, entry.inputTokens),
                entry.costUsd == null
                    ? '—'
                    : '\$${entry.costUsd!.toStringAsFixed(2)}',
              ),
              mono: true,
            ),
        ],
      ),
    ),
  ];
}

/// A small ring with the share of accounts that opted in.
class _AdminSharedUsageShare extends StatelessWidget {
  const _AdminSharedUsageShare({required this.sharing, required this.total});

  final int sharing;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : sharing / total;
    return SizedBox.square(
      dimension: 44,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 4,
              backgroundColor: _bgSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(_success),
            ),
          ),
          Text(
            '${(fraction * 100).round()}%',
            style: _monoStyle(size: 10.5, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Runs per weekday and hour; darker cells had more runs.
class _AdminActivityHeatmap extends StatelessWidget {
  const _AdminActivityHeatmap({required this.activity});

  final List<List<int>> activity;

  @override
  Widget build(BuildContext context) {
    final peak = activity.fold<int>(
      0,
      (max, row) => row.fold<int>(max, math.max),
    );
    if (peak == 0) return _EmptyText(appStrings.sharedUsageNoData);
    final axisStyle = _monoStyle(size: 10.5, color: _textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var day = 0; day < 7; day++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 36,
                  child: Text(_taskWeekdayLabels[day], style: axisStyle),
                ),
                for (var hour = 0; hour < 24; hour++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${_taskWeekdayLabels[day]} '
                          '${hour.toString().padLeft(2, '0')}:00 · '
                          '${appStrings.arg1Runs(_formatNumber(activity[day][hour]))}',
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: activity[day][hour] == 0
                                  ? _bgSecondary
                                  : _accent.withValues(
                                      alpha:
                                          0.18 +
                                          0.82 * activity[day][hour] / peak,
                                    ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            const SizedBox(width: 36),
            for (final hour in const <int>[0, 6, 12, 18])
              Expanded(
                flex: 6,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: axisStyle,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
