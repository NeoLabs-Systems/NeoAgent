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
    section: appStrings.triggerSectionMessaging,
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
    section: appStrings.triggerSectionMessaging,
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
    section: appStrings.triggerSectionMessaging,
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
    section: appStrings.triggerSectionMessaging,
    label: appStrings.messagingMemberJoined,
    description: appStrings.runWhenSomeoneJoinsAServerOrGroup,
    icon: Icons.person_add_alt_1_rounded,
    fields: _membershipFields(),
  ),
  _TaskTriggerOption(
    type: 'messaging_member_left',
    section: appStrings.triggerSectionMessaging,
    label: appStrings.messagingMemberLeft,
    description: appStrings.runWhenSomeoneLeavesAServerOrGroup,
    icon: Icons.person_remove_alt_1_rounded,
    fields: _membershipFields(),
  ),
  _TaskTriggerOption(
    type: 'messaging_reaction_added',
    section: appStrings.triggerSectionMessaging,
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
    section: appStrings.triggerSectionMessaging,
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
    section: appStrings.triggerSectionDeveloper,
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
    section: appStrings.triggerSectionDeveloper,
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
    section: appStrings.triggerSectionDeveloper,
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
    section: appStrings.triggerSectionDeveloper,
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
    section: appStrings.triggerSectionDeveloper,
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
    section: appStrings.triggerSectionMemory,
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
    section: appStrings.triggerSectionMemory,
    label: appStrings.neorecallDailySummaryReady,
    description: appStrings.runWhenADaysSummaryIsFinal,
    icon: Icons.summarize_rounded,
    providerKey: 'neorecall',
    appKey: 'recall',
    requiresConnection: true,
  ),
  _TaskTriggerOption(
    type: 'neorecall_conversation_recorded',
    section: appStrings.triggerSectionMemory,
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
    section: appStrings.triggerSectionNews,
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
    section: appStrings.triggerSectionSystem,
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

Future<String?> _pickTaskTriggerType(
  BuildContext context,
  String selectedType, {
  required bool Function(_TaskTriggerOption option) isConnected,
}) {
  final compact = MediaQuery.sizeOf(context).width < 640;
  final picker = _TaskTriggerPicker(
    selectedType: selectedType,
    isConnected: isConnected,
    compact: compact,
  );
  return showDialog<String>(
    context: context,
    builder: (context) => compact
        ? Dialog.fullscreen(backgroundColor: _bgCard, child: picker)
        : Dialog(
            backgroundColor: _bgCard,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
              child: picker,
            ),
          ),
  );
}

enum _TriggerAvailability { ready, connected, accountMissing, needsAccount }

class _TaskTriggerPicker extends StatefulWidget {
  const _TaskTriggerPicker({
    required this.selectedType,
    required this.isConnected,
    required this.compact,
  });

  final String selectedType;
  final bool Function(_TaskTriggerOption option) isConnected;
  final bool compact;

  @override
  State<_TaskTriggerPicker> createState() => _TaskTriggerPickerState();
}

class _TaskTriggerPickerState extends State<_TaskTriggerPicker> {
  final TextEditingController _search = TextEditingController();
  late final List<_TaskTriggerOption> _options = _taskTriggerOptions;
  late final List<String> _sections = _options
      .map((option) => option.section)
      .toSet()
      .toList();
  String? _section;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  _TriggerAvailability _availability(_TaskTriggerOption option) {
    if (option.providerKey == null) return _TriggerAvailability.ready;
    if (widget.isConnected(option)) return _TriggerAvailability.connected;
    if (option.requiresConnection && option.type != widget.selectedType) {
      return _TriggerAvailability.needsAccount;
    }
    return _TriggerAvailability.accountMissing;
  }

  // Every word must appear in the name, description, category, or app.
  bool _matches(_TaskTriggerOption option, List<String> words) {
    if (words.isEmpty) return true;
    final haystack = <String?>[
      option.label,
      option.description,
      option.section,
      option.type.replaceAll('_', ' '),
      option.providerKey?.replaceAll('_', ' '),
    ].whereType<String>().join(' ').toLowerCase();
    return words.every(haystack.contains);
  }

  List<String> get _words => _search.text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  List<_TaskTriggerOption> _searchResults() {
    final words = _words;
    return _options.where((option) => _matches(option, words)).toList();
  }

  void _pick(_TaskTriggerOption option) {
    if (_availability(option) == _TriggerAvailability.needsAccount) return;
    Navigator.of(context).pop(option.type);
  }

  void _pickFirst(List<_TaskTriggerOption> visible) {
    for (final option in visible) {
      if (_availability(option) != _TriggerAvailability.needsAccount) {
        _pick(option);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _searchResults();
    final visible = _section == null
        ? results
        : results.where((option) => option.section == _section).toList();
    final padding = widget.compact ? 16.0 : 24.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, padding, padding, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              autofocus: !widget.compact,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _pickFirst(visible),
              decoration: InputDecoration(
                hintText: appStrings.searchTriggersHint,
                prefixIcon: Icon(Icons.search_rounded, color: _textMuted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: appStrings.clear,
                        icon: Icon(Icons.close_rounded, color: _textMuted),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSectionChips(results),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? _buildEmptyState()
                  : _buildResults(visible),
            ),
            _buildFooter(visible.length),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                appStrings.selectTrigger,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                appStrings.chooseHowThisTaskShouldStart,
                style: TextStyle(color: _textSecondary, height: 1.45),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: appStrings.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSectionChips(List<_TaskTriggerOption> results) {
    final counts = <String, int>{};
    for (final option in results) {
      counts[option.section] = (counts[option.section] ?? 0) + 1;
    }
    Widget chip(String? section, String label, int count) {
      final selected = _section == section;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          showCheckmark: false,
          label: Text('$label  $count'),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: count == 0 && !selected ? _textMuted : null,
          ),
          onSelected: count == 0 && !selected
              ? null
              : (_) => setState(() => _section = selected ? null : section),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          chip(null, appStrings.all, results.length),
          for (final section in _sections)
            chip(section, section, counts[section] ?? 0),
        ],
      ),
    );
  }

  Widget _buildResults(List<_TaskTriggerOption> visible) {
    final grouped = _section == null && _words.isEmpty;
    final items = <Widget>[];
    String? currentSection;
    for (final option in visible) {
      if (grouped && option.section != currentSection) {
        currentSection = option.section;
        items.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, items.isEmpty ? 4 : 18, 4, 8),
            child: Text(
              option.section.toUpperCase(),
              style: TextStyle(
                color: _textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        );
      }
      items.add(
        _TaskTriggerTile(
          option: option,
          selected: option.type == widget.selectedType,
          availability: _availability(option),
          showSection: !grouped,
          onTap: () => _pick(option),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      children: items,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off_rounded, size: 40, color: _textMuted),
          const SizedBox(height: 12),
          Text(
            appStrings.noTriggersMatch,
            style: TextStyle(color: _textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _search.clear();
              _section = null;
            }),
            child: Text(appStrings.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Text(
            appStrings.triggerResultCountArg1(count),
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
          if (!widget.compact && _search.text.isNotEmpty && count > 0) ...[
            const SizedBox(width: 12),
            Icon(Icons.keyboard_return_rounded, size: 14, color: _textMuted),
            const SizedBox(width: 4),
            Text(
              appStrings.pickTriggerKeyboardHint,
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appStrings.cancel),
          ),
        ],
      ),
    );
  }
}

class _TaskTriggerTile extends StatelessWidget {
  const _TaskTriggerTile({
    required this.option,
    required this.selected,
    required this.availability,
    required this.showSection,
    required this.onTap,
  });

  final _TaskTriggerOption option;
  final bool selected;
  final _TriggerAvailability availability;
  final bool showSection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = availability == _TriggerAvailability.needsAccount;
    final badge = switch (availability) {
      _TriggerAvailability.connected => (appStrings.connected, _success),
      _TriggerAvailability.accountMissing => (
        appStrings.triggerAccountMissing,
        _warning,
      ),
      _TriggerAvailability.needsAccount => (
        appStrings.triggerNeedsAccount,
        _textMuted,
      ),
      _TriggerAvailability.ready => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Material(
          color: selected
              ? _accent.withValues(alpha: 0.10)
              : _bgCard.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? _accent : _border,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? _accent.withValues(alpha: 0.16)
                          : _bgTertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      option.icon,
                      size: 21,
                      color: selected ? _accent : _textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              option.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            if (showSection)
                              Text(
                                option.section,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          option.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: badge.$2,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                badge.$1,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: selected ? _accent : _textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
