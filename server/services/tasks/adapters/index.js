'use strict';

// Every trigger the task system knows. Each adapter owns its config and either
// a poll (see trigger_polling.js) or an event source (see trigger_events.js).
module.exports = [
  require('./schedule'),
  require('./manual'),
  require('./webhook'),
  // Email and chat
  require('./gmail_message_received'),
  require('./outlook_email_received'),
  require('./slack_message_received'),
  require('./teams_message_received'),
  require('./whatsapp_personal_message_received'),
  // Messaging platforms
  require('./messaging_member_joined'),
  require('./messaging_member_left'),
  require('./messaging_reaction_added'),
  require('./messaging_platform_disconnected'),
  // Calendars
  require('./google_calendar_event_starting'),
  require('./google_calendar_event_created'),
  require('./outlook_calendar_event_starting'),
  require('./nextcloud_calendar_event_starting'),
  // Files and documents
  require('./google_drive_file_added'),
  require('./google_sheets_row_added'),
  require('./onedrive_file_added'),
  require('./nextcloud_file_added'),
  require('./nextcloud_share_received'),
  require('./notion_database_item_added'),
  require('./notion_database_item_updated'),
  require('./trello_card_entered_list'),
  require('./figma_comment_added'),
  // Developer
  require('./github_issue_opened'),
  require('./github_pr_opened'),
  require('./github_workflow_run_failed'),
  require('./github_commit_pushed'),
  require('./mcp_server_disconnected'),
  // Home, media, and memory
  require('./home_assistant_state_changed'),
  require('./spotify_track_changed'),
  require('./neorecall_memory_created'),
  require('./neorecall_daily_summary_created'),
  require('./neorecall_conversation_recorded'),
  // World
  require('./weather_event'),
  require('./world_news'),
  // Devices and tasks
  require('./android_notification_received'),
  require('./geofence_event'),
  require('./health_metric_recorded'),
  require('./wearable_connection_changed'),
  require('./task_run_finished'),
];
