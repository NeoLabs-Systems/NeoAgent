part of 'main.dart';

// The task triggers the editor offers. Each option lists its own config
// fields, and the editor builds the form and the saved config from them, so a
// new trigger is one entry here and one adapter on the server.

enum _TaskTriggerFieldKind { text, number, toggle, list, choice, task }

class _TaskTriggerChoice {
  const _TaskTriggerChoice(this.value, this.label);

  final String value;
  final String label;
}

class _TaskTriggerField {
  const _TaskTriggerField(
    this.key,
    this.label, {
    this.kind = _TaskTriggerFieldKind.text,
    this.helper,
    this.required = false,
    this.choices = const <_TaskTriggerChoice>[],
    this.defaultValue,
  });

  final String key;
  final String label;
  final _TaskTriggerFieldKind kind;
  final String? helper;
  final bool required;
  final List<_TaskTriggerChoice> choices;
  final Object? defaultValue;
}

class _TaskTriggerOption {
  const _TaskTriggerOption({
    required this.type,
    required this.section,
    required this.label,
    required this.description,
    required this.icon,
    this.providerKey,
    this.appKey,
    this.requiresConnection = false,
    this.fields = const <_TaskTriggerField>[],
  });

  final String type;
  final String section;
  final String label;
  final String description;
  final IconData icon;

  /// The official integration provider key this trigger binds to, if any.
  /// When set, the task editor shows a connected-account dropdown instead of
  /// a raw connection ID text field.
  final String? providerKey;

  /// The app within the provider (matches [OfficialIntegrationAppItem.id]).
  /// Narrows account lookup to just the relevant app so multi-app providers
  /// (e.g. Google Workspace with Gmail + Drive + Calendar) don't show
  /// duplicate accounts.
  final String? appKey;

  /// Hides the trigger from the picker until the integration has a connected
  /// account.
  final bool requiresConnection;

  final List<_TaskTriggerField> fields;
}

_TaskTriggerField _repoField() => _TaskTriggerField(
  'repo',
  appStrings.githubRepository,
  helper: appStrings.requiredFormatOwnerRepo,
  required: true,
);

_TaskTriggerField _minutesBeforeField() => _TaskTriggerField(
  'minutesBefore',
  appStrings.minutesBefore,
  kind: _TaskTriggerFieldKind.number,
  defaultValue: 10,
);

_TaskTriggerField _aboveField() => _TaskTriggerField(
  'above',
  appStrings.aboveOptional,
  kind: _TaskTriggerFieldKind.number,
);

_TaskTriggerField _belowField() => _TaskTriggerField(
  'below',
  appStrings.belowOptional,
  kind: _TaskTriggerFieldKind.number,
);

List<_TaskTriggerField> _membershipFields() => <_TaskTriggerField>[
  _TaskTriggerField(
    'platform',
    appStrings.platform,
    kind: _TaskTriggerFieldKind.choice,
    required: true,
    choices: const <_TaskTriggerChoice>[
      _TaskTriggerChoice('discord', 'Discord'),
      _TaskTriggerChoice('telegram', 'Telegram'),
      _TaskTriggerChoice('whatsapp', 'WhatsApp'),
      _TaskTriggerChoice('slack', 'Slack'),
      _TaskTriggerChoice('matrix', 'Matrix'),
    ],
  ),
  _TaskTriggerField(
    'spaceId',
    appStrings.spaceIdOptional,
    helper: appStrings.spaceIdHelper,
  ),
];

// A getter, so labels follow the app language when it changes.
List<_TaskTriggerOption> get _taskTriggerOptions => <_TaskTriggerOption>[
  _TaskTriggerOption(
    type: 'manual',
    section: appStrings.onDemand,
    label: appStrings.manualTrigger,
    description: appStrings.runsOnlyWhenYouPressRun,
    icon: Icons.play_circle_outline_rounded,
  ),
  _TaskTriggerOption(
    type: 'schedule',
    section: appStrings.time,
    label: appStrings.schedule,
    description: appStrings.cronBasedRecurringRunsAndOne,
    icon: Icons.schedule_rounded,
  ),
  _TaskTriggerOption(
    type: 'gmail_message_received',
    section: appStrings.email,
    label: appStrings.gmailMessageReceived,
    description: appStrings.runWhenAMatchingGmailMessage,
    icon: Icons.mail_rounded,
    providerKey: 'google_workspace',
    appKey: 'gmail',
    fields: <_TaskTriggerField>[
      _TaskTriggerField('query', appStrings.queryFilter),
      _TaskTriggerField(
        'unreadOnly',
        appStrings.unreadOnly,
        kind: _TaskTriggerFieldKind.toggle,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'outlook_email_received',
    section: appStrings.email,
    label: appStrings.outlookEmailReceived,
    description: appStrings.runWhenAMatchingOutlookEmail,
    icon: Icons.markunread_rounded,
    providerKey: 'microsoft_365',
    appKey: 'outlook',
    fields: <_TaskTriggerField>[
      _TaskTriggerField('query', appStrings.queryFilter),
      _TaskTriggerField(
        'unreadOnly',
        appStrings.unreadOnly,
        kind: _TaskTriggerFieldKind.toggle,
      ),
      _TaskTriggerField('folderId', appStrings.folderIdOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'slack_message_received',
    section: 'Messaging',
    label: appStrings.slackMessageReceived,
    description: appStrings.runWhenASlackMessageMatches,
    icon: Icons.forum_rounded,
    providerKey: 'slack',
    appKey: 'slack',
    fields: <_TaskTriggerField>[
      _TaskTriggerField('channel', appStrings.channelId, required: true),
      _TaskTriggerField('sender', appStrings.senderFilterOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'teams_message_received',
    section: 'Messaging',
    label: appStrings.teamsMessageReceived,
    description: appStrings.runWhenATeamsChatMessage,
    icon: Icons.groups_rounded,
    providerKey: 'microsoft_365',
    appKey: 'teams',
    fields: <_TaskTriggerField>[
      _TaskTriggerField('chatId', appStrings.chatId, required: true),
      _TaskTriggerField('sender', appStrings.senderFilterOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'whatsapp_personal_message_received',
    section: 'Messaging',
    label: appStrings.whatsappPersonalMessageReceived,
    description: appStrings.runOnInboundPersonalWhatsappMessages,
    icon: Icons.chat_bubble_rounded,
    providerKey: 'whatsapp_personal',
    appKey: 'personal',
    fields: <_TaskTriggerField>[
      _TaskTriggerField('chatId', appStrings.chatId, required: true),
      _TaskTriggerField('sender', appStrings.senderFilterOptional),
      _TaskTriggerField(
        'ignoreGroups',
        appStrings.ignoreGroups,
        kind: _TaskTriggerFieldKind.toggle,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'messaging_member_joined',
    section: 'Messaging',
    label: appStrings.messagingMemberJoined,
    description: appStrings.runWhenSomeoneJoinsAServerOrGroup,
    icon: Icons.person_add_alt_1_rounded,
    fields: _membershipFields(),
  ),
  _TaskTriggerOption(
    type: 'messaging_member_left',
    section: 'Messaging',
    label: appStrings.messagingMemberLeft,
    description: appStrings.runWhenSomeoneLeavesAServerOrGroup,
    icon: Icons.person_remove_alt_1_rounded,
    fields: _membershipFields(),
  ),
  _TaskTriggerOption(
    type: 'messaging_reaction_added',
    section: 'Messaging',
    label: appStrings.messagingReactionAdded,
    description: appStrings.runWhenSomeoneReactsInAPrivateChat,
    icon: Icons.add_reaction_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'platform',
        appStrings.platform,
        kind: _TaskTriggerFieldKind.choice,
        choices: <_TaskTriggerChoice>[
          _TaskTriggerChoice('', appStrings.anyPlatform),
          const _TaskTriggerChoice('discord', 'Discord'),
          const _TaskTriggerChoice('telegram', 'Telegram'),
          const _TaskTriggerChoice('whatsapp', 'WhatsApp'),
        ],
      ),
      _TaskTriggerField('emoji', appStrings.emojiOptional),
      _TaskTriggerField('chatId', appStrings.chatIdOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'messaging_platform_disconnected',
    section: 'Messaging',
    label: appStrings.messagingPlatformDisconnected,
    description: appStrings.runWhenAMessagingConnectionNeedsYou,
    icon: Icons.link_off_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'platform',
        appStrings.platformOptional,
        helper: appStrings.platformOptionalHelper,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'google_calendar_event_starting',
    section: appStrings.triggerSectionCalendar,
    label: appStrings.googleCalendarEventStarting,
    description: appStrings.runMinutesBeforeEachEvent,
    icon: Icons.event_rounded,
    providerKey: 'google_workspace',
    appKey: 'calendar',
    fields: <_TaskTriggerField>[
      _minutesBeforeField(),
      _TaskTriggerField(
        'calendarId',
        appStrings.calendarIdOptional,
        helper: appStrings.calendarIdHelper,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'google_calendar_event_created',
    section: appStrings.triggerSectionCalendar,
    label: appStrings.googleCalendarEventCreated,
    description: appStrings.runWhenANewGoogleCalendarEventAppears,
    icon: Icons.event_available_rounded,
    providerKey: 'google_workspace',
    appKey: 'calendar',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'calendarId',
        appStrings.calendarIdOptional,
        helper: appStrings.calendarIdHelper,
      ),
      _TaskTriggerField(
        'invitesOnly',
        appStrings.invitesOnly,
        kind: _TaskTriggerFieldKind.toggle,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'outlook_calendar_event_starting',
    section: appStrings.triggerSectionCalendar,
    label: appStrings.outlookCalendarEventStarting,
    description: appStrings.runMinutesBeforeEachEvent,
    icon: Icons.event_note_rounded,
    providerKey: 'microsoft_365',
    appKey: 'calendar',
    fields: <_TaskTriggerField>[_minutesBeforeField()],
  ),
  _TaskTriggerOption(
    type: 'nextcloud_calendar_event_starting',
    section: appStrings.triggerSectionCalendar,
    label: appStrings.nextcloudCalendarEventStarting,
    description: appStrings.runMinutesBeforeEachEvent,
    icon: Icons.calendar_month_rounded,
    providerKey: 'nextcloud',
    appKey: 'calendar',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'calendar',
        appStrings.nextcloudCalendarPath,
        helper: appStrings.nextcloudCalendarPathHelper,
        required: true,
      ),
      _minutesBeforeField(),
    ],
  ),
  _TaskTriggerOption(
    type: 'google_drive_file_added',
    section: appStrings.triggerSectionFiles,
    label: appStrings.googleDriveFileAdded,
    description: appStrings.runWhenAFileIsAddedToDrive,
    icon: Icons.upload_file_rounded,
    providerKey: 'google_workspace',
    appKey: 'drive',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'folderId',
        appStrings.driveFolderIdOptional,
        helper: appStrings.folderIdOptionalHelperDrive,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'google_sheets_row_added',
    section: appStrings.triggerSectionFiles,
    label: appStrings.googleSheetsRowAdded,
    description: appStrings.runWhenRowsAreAddedToASheet,
    icon: Icons.table_rows_rounded,
    providerKey: 'google_workspace',
    appKey: 'sheets',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'spreadsheetId',
        appStrings.spreadsheetId,
        required: true,
      ),
      _TaskTriggerField(
        'range',
        appStrings.sheetRange,
        helper: appStrings.sheetRangeHelper,
        required: true,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'onedrive_file_added',
    section: appStrings.triggerSectionFiles,
    label: appStrings.onedriveFileAdded,
    description: appStrings.runWhenAFileIsAddedToOnedrive,
    icon: Icons.cloud_upload_rounded,
    providerKey: 'microsoft_365',
    appKey: 'onedrive',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'folderId',
        appStrings.driveFolderIdOptional,
        helper: appStrings.folderIdOptionalHelperOnedrive,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'nextcloud_file_added',
    section: appStrings.triggerSectionFiles,
    label: appStrings.nextcloudFileAdded,
    description: appStrings.runWhenAFileIsAddedToNextcloud,
    icon: Icons.note_add_rounded,
    providerKey: 'nextcloud',
    appKey: 'files',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'path',
        appStrings.folderPathOptional,
        helper: appStrings.folderPathHelper,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'nextcloud_share_received',
    section: appStrings.triggerSectionFiles,
    label: appStrings.nextcloudShareReceived,
    description: appStrings.runWhenSomeoneSharesWithYouOnNextcloud,
    icon: Icons.folder_shared_rounded,
    providerKey: 'nextcloud',
    appKey: 'files',
  ),
  _TaskTriggerOption(
    type: 'notion_database_item_added',
    section: appStrings.triggerSectionFiles,
    label: appStrings.notionItemAdded,
    description: appStrings.runWhenAnItemIsAddedToANotionDatabase,
    icon: Icons.post_add_rounded,
    providerKey: 'notion',
    appKey: 'notion',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'databaseId',
        appStrings.notionDatabaseId,
        required: true,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'notion_database_item_updated',
    section: appStrings.triggerSectionFiles,
    label: appStrings.notionItemUpdated,
    description: appStrings.runWhenANotionDatabaseItemChanges,
    icon: Icons.edit_note_rounded,
    providerKey: 'notion',
    appKey: 'notion',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'databaseId',
        appStrings.notionDatabaseId,
        required: true,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'trello_card_entered_list',
    section: appStrings.triggerSectionFiles,
    label: appStrings.trelloCardEnteredList,
    description: appStrings.runWhenACardIsCreatedInOrMovedIntoAList,
    icon: Icons.view_kanban_rounded,
    providerKey: 'trello',
    appKey: 'trello',
    fields: <_TaskTriggerField>[
      _TaskTriggerField('listId', appStrings.trelloListId, required: true),
    ],
  ),
  _TaskTriggerOption(
    type: 'figma_comment_added',
    section: appStrings.triggerSectionFiles,
    label: appStrings.figmaCommentAdded,
    description: appStrings.runWhenSomeoneCommentsOnAFigmaFile,
    icon: Icons.mode_comment_rounded,
    providerKey: 'figma',
    appKey: 'figma',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'fileKey',
        appStrings.figmaFileKey,
        helper: appStrings.figmaFileKeyHelper,
        required: true,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'github_issue_opened',
    section: 'Developer',
    label: appStrings.githubIssueOpened,
    description: appStrings.runWhenANewIssueMatching,
    icon: Icons.bug_report_rounded,
    providerKey: 'github',
    appKey: 'repos',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _repoField(),
      _TaskTriggerField(
        'author',
        appStrings.authorOptional,
        helper: appStrings.githubUsernameThatOpenedTheIssue,
      ),
      _TaskTriggerField('assignee', appStrings.assigneeOptional),
      _TaskTriggerField(
        'labels',
        appStrings.labelsOptional,
        helper: appStrings.commaSeparatedTheIssueMustHave,
      ),
      _TaskTriggerField(
        'query',
        appStrings.containsTextOptional,
        helper: appStrings.matchedAgainstTitleAndBody,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'github_pr_opened',
    section: 'Developer',
    label: appStrings.githubPrOpened,
    description: appStrings.runWhenANewPullRequestIsOpened,
    icon: Icons.merge_type_rounded,
    providerKey: 'github',
    appKey: 'repos',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _repoField(),
      _TaskTriggerField('author', appStrings.authorOptional),
      _TaskTriggerField(
        'query',
        appStrings.containsTextOptional,
        helper: appStrings.matchedAgainstTitleAndBody,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'github_workflow_run_failed',
    section: 'Developer',
    label: appStrings.githubWorkflowRunFailed,
    description: appStrings.runWhenAGithubActionsRunFails,
    icon: Icons.error_outline_rounded,
    providerKey: 'github',
    appKey: 'repos',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _repoField(),
      _TaskTriggerField(
        'workflow',
        appStrings.workflowOptional,
        helper: appStrings.workflowHelper,
      ),
      _TaskTriggerField('branch', appStrings.branchOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'github_commit_pushed',
    section: 'Developer',
    label: appStrings.githubCommitPushed,
    description: appStrings.runWhenNewCommitsReachABranch,
    icon: Icons.commit_rounded,
    providerKey: 'github',
    appKey: 'repos',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _repoField(),
      _TaskTriggerField(
        'branch',
        appStrings.branchOptional,
        helper: appStrings.branchHelper,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'mcp_server_disconnected',
    section: 'Developer',
    label: appStrings.mcpServerFailed,
    description: appStrings.runWhenAWorkingMcpServerFails,
    icon: Icons.power_off_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField('serverId', appStrings.mcpServerIdOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'home_assistant_state_changed',
    section: appStrings.triggerSectionHome,
    label: appStrings.homeAssistantStateChanged,
    description: appStrings.runWhenAHomeAssistantEntityChanges,
    icon: Icons.sensors_rounded,
    providerKey: 'home_assistant',
    appKey: 'home_assistant',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'entityId',
        appStrings.entityId,
        helper: appStrings.entityIdHelper,
        required: true,
      ),
      _TaskTriggerField(
        'toState',
        appStrings.targetStateOptional,
        helper: appStrings.targetStateHelper,
      ),
      _aboveField(),
      _belowField(),
    ],
  ),
  _TaskTriggerOption(
    type: 'spotify_track_changed',
    section: appStrings.triggerSectionHome,
    label: appStrings.spotifyTrackChanged,
    description: appStrings.runWhenADifferentTrackStartsPlaying,
    icon: Icons.music_note_rounded,
    providerKey: 'spotify',
    appKey: 'spotify',
    requiresConnection: true,
  ),
  _TaskTriggerOption(
    type: 'neorecall_memory_created',
    section: 'Memory',
    label: appStrings.neorecallMemoryCreated,
    description: appStrings.runWhenANewNeorecallMemoryMatches,
    icon: Icons.psychology_alt_rounded,
    providerKey: 'neorecall',
    appKey: 'recall',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _TaskTriggerField('query', appStrings.containsTextOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'neorecall_daily_summary_created',
    section: 'Memory',
    label: appStrings.neorecallDailySummaryReady,
    description: appStrings.runWhenADaysSummaryIsFinal,
    icon: Icons.summarize_rounded,
    providerKey: 'neorecall',
    appKey: 'recall',
    requiresConnection: true,
  ),
  _TaskTriggerOption(
    type: 'neorecall_conversation_recorded',
    section: 'Memory',
    label: appStrings.neorecallConversationRecorded,
    description: appStrings.runWhenARecordedConversationEnds,
    icon: Icons.record_voice_over_rounded,
    providerKey: 'neorecall',
    appKey: 'recall',
    requiresConnection: true,
  ),
  _TaskTriggerOption(
    type: 'weather_event',
    section: appStrings.environment,
    label: appStrings.weatherEvent,
    description: appStrings.runWhenConfiguredWeatherEventsAre,
    icon: Icons.cloudy_snowing,
    providerKey: 'weather',
    appKey: 'forecast',
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'location',
        appStrings.locationCityOrPlace,
        helper: appStrings.requiredExampleBerlinDe,
        required: true,
      ),
      _TaskTriggerField(
        'eventTypes',
        appStrings.eventTypesCommaSeparated,
        kind: _TaskTriggerFieldKind.list,
        helper: appStrings.supportedRainStartSnowStartWind,
        required: true,
        defaultValue: appStrings.rainStartWindAlert,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'world_news',
    section: 'News',
    label: appStrings.worldNews,
    description: appStrings.runWhenNewWorldHeadlinesAppear,
    icon: Icons.public_rounded,
    providerKey: 'news',
    appKey: 'headlines',
    requiresConnection: true,
    fields: <_TaskTriggerField>[
      _TaskTriggerField('query', appStrings.newsKeywordsOptional),
    ],
  ),
  _TaskTriggerOption(
    type: 'android_notification_received',
    section: 'System',
    label: appStrings.androidNotificationReceived,
    description: appStrings.runWhenANotificationArrivesOn,
    icon: Icons.notifications_active_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'appPackage',
        appStrings.appPackageOptional,
        helper: appStrings.appPackageHelper,
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'geofence_event',
    section: appStrings.triggerSectionDevices,
    label: appStrings.geofenceTrigger,
    description: appStrings.runWhenYourPhoneArrivesOrLeaves,
    icon: Icons.place_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField('label', appStrings.placeName),
      _TaskTriggerField(
        'latitude',
        appStrings.latitude,
        kind: _TaskTriggerFieldKind.number,
        required: true,
      ),
      _TaskTriggerField(
        'longitude',
        appStrings.longitude,
        kind: _TaskTriggerFieldKind.number,
        required: true,
      ),
      _TaskTriggerField(
        'radiusMeters',
        appStrings.radiusMeters,
        kind: _TaskTriggerFieldKind.number,
        defaultValue: 200,
      ),
      _TaskTriggerField(
        'transition',
        appStrings.geofenceTransition,
        kind: _TaskTriggerFieldKind.choice,
        required: true,
        defaultValue: 'enter',
        choices: <_TaskTriggerChoice>[
          _TaskTriggerChoice('enter', appStrings.arriving),
          _TaskTriggerChoice('exit', appStrings.leaving),
        ],
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'health_metric_recorded',
    section: appStrings.triggerSectionDevices,
    label: appStrings.healthMetricRecorded,
    description: appStrings.runWhenAHealthReadingArrives,
    icon: Icons.monitor_heart_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'metricType',
        appStrings.healthMetric,
        helper: appStrings.healthMetricHelper,
        required: true,
      ),
      _aboveField(),
      _belowField(),
    ],
  ),
  _TaskTriggerOption(
    type: 'wearable_connection_changed',
    section: appStrings.triggerSectionDevices,
    label: appStrings.wearableConnectionChanged,
    description: appStrings.runWhenYourWearableConnectsOrDisconnects,
    icon: Icons.watch_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'transition',
        appStrings.wearableTransition,
        kind: _TaskTriggerFieldKind.choice,
        required: true,
        defaultValue: 'disconnected',
        choices: <_TaskTriggerChoice>[
          _TaskTriggerChoice('connected', appStrings.wearableConnects),
          _TaskTriggerChoice('disconnected', appStrings.wearableDisconnects),
        ],
      ),
    ],
  ),
  _TaskTriggerOption(
    type: 'task_run_finished',
    section: appStrings.triggerSectionTasks,
    label: appStrings.taskRunFinished,
    description: appStrings.runWhenAnotherTaskFinishes,
    icon: Icons.account_tree_rounded,
    fields: <_TaskTriggerField>[
      _TaskTriggerField(
        'sourceTaskId',
        appStrings.sourceTask,
        kind: _TaskTriggerFieldKind.task,
        required: true,
      ),
      _TaskTriggerField(
        'outcome',
        appStrings.taskOutcome,
        kind: _TaskTriggerFieldKind.choice,
        defaultValue: 'any',
        choices: <_TaskTriggerChoice>[
          _TaskTriggerChoice('any', appStrings.anyOutcome),
          _TaskTriggerChoice('succeeded', appStrings.succeeded),
          _TaskTriggerChoice('failed', appStrings.failed),
        ],
      ),
    ],
  ),
];

_TaskTriggerOption _taskTriggerOptionForType(String type) {
  final options = _taskTriggerOptions;
  return options.firstWhere(
    (option) => option.type == type,
    orElse: () => options.first,
  );
}

/// The values typed into a task's trigger fields, kept per field key so
/// switching between triggers that share a field keeps what was entered.
class _TaskTriggerDraft {
  _TaskTriggerDraft(Map<String, dynamic> savedConfig)
    : _saved = Map<String, dynamic>.from(savedConfig);

  final Map<String, dynamic> _saved;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, Object?> _picked = <String, Object?>{};

  TextEditingController textFor(_TaskTriggerField field) {
    return _controllers.putIfAbsent(field.key, () {
      final saved = _saved[field.key] ?? field.defaultValue;
      final text = saved is List ? saved.join(', ') : (saved?.toString() ?? '');
      return TextEditingController(text: text);
    });
  }

  Object? valueFor(_TaskTriggerField field) {
    if (_picked.containsKey(field.key)) return _picked[field.key];
    return _saved[field.key] ?? field.defaultValue;
  }

  void pick(_TaskTriggerField field, Object? value) {
    _picked[field.key] = value;
  }

  /// Writes the fields into [config] and returns the label of the first
  /// field that is missing or not valid, or null when all are fine.
  String? writeTo(List<_TaskTriggerField> fields, Map<String, dynamic> config) {
    for (final field in fields) {
      switch (field.kind) {
        case _TaskTriggerFieldKind.toggle:
          config[field.key] = valueFor(field) == true;
        case _TaskTriggerFieldKind.choice:
          final value = valueFor(field)?.toString() ?? '';
          if (value.isEmpty && field.required) return field.label;
          config[field.key] = value;
        case _TaskTriggerFieldKind.task:
          final value = valueFor(field);
          final taskId = value is int ? value : int.tryParse('$value');
          if (taskId == null) {
            if (field.required) return field.label;
            continue;
          }
          config[field.key] = taskId;
        case _TaskTriggerFieldKind.list:
          final items = textFor(field).text
              .split(',')
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList();
          if (items.isEmpty && field.required) return field.label;
          config[field.key] = items;
        case _TaskTriggerFieldKind.number:
          final text = textFor(field).text.trim();
          if (text.isEmpty) {
            if (field.required) return field.label;
            continue;
          }
          final number = num.tryParse(text.replaceAll(',', '.'));
          if (number == null) return field.label;
          config[field.key] = number;
        case _TaskTriggerFieldKind.text:
          final text = textFor(field).text.trim();
          if (text.isEmpty) {
            if (field.required) return field.label;
            continue;
          }
          config[field.key] = text;
      }
    }
    return null;
  }
}

Widget _buildTaskTriggerFields({
  required _TaskTriggerOption option,
  required _TaskTriggerDraft draft,
  required List<TaskItem> otherTasks,
  required StateSetter setLocalState,
}) {
  return Column(
    children: <Widget>[
      for (final field in option.fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTaskTriggerField(
            field: field,
            draft: draft,
            otherTasks: otherTasks,
            setLocalState: setLocalState,
          ),
        ),
    ],
  );
}

Widget _buildTaskTriggerField({
  required _TaskTriggerField field,
  required _TaskTriggerDraft draft,
  required List<TaskItem> otherTasks,
  required StateSetter setLocalState,
}) {
  final decoration = InputDecoration(
    labelText: field.label,
    helperText: field.helper,
    helperMaxLines: 2,
  );
  switch (field.kind) {
    case _TaskTriggerFieldKind.toggle:
      return SwitchListTile(
        value: draft.valueFor(field) == true,
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: field.helper == null ? null : Text(field.helper!),
        onChanged: (value) => setLocalState(() => draft.pick(field, value)),
      );
    case _TaskTriggerFieldKind.choice:
      final current = draft.valueFor(field)?.toString() ?? '';
      return DropdownButtonFormField<String>(
        initialValue: field.choices.any((choice) => choice.value == current)
            ? current
            : null,
        isExpanded: true,
        decoration: decoration,
        items: field.choices
            .map(
              (choice) => DropdownMenuItem<String>(
                value: choice.value,
                child: Text(choice.label),
              ),
            )
            .toList(),
        onChanged: (value) => setLocalState(() => draft.pick(field, value)),
      );
    case _TaskTriggerFieldKind.task:
      final current = draft.valueFor(field);
      final currentId = current is int ? current : int.tryParse('$current');
      return DropdownButtonFormField<int>(
        initialValue: otherTasks.any((task) => task.id == currentId)
            ? currentId
            : null,
        isExpanded: true,
        decoration: decoration,
        items: otherTasks
            .map(
              (task) => DropdownMenuItem<int>(
                value: task.id,
                child: Text(task.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) => setLocalState(() => draft.pick(field, value)),
      );
    case _TaskTriggerFieldKind.number:
      return TextField(
        controller: draft.textFor(field),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: decoration,
      );
    case _TaskTriggerFieldKind.list:
    case _TaskTriggerFieldKind.text:
      return TextField(controller: draft.textFor(field), decoration: decoration);
  }
}
