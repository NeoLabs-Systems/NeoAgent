part of 'main.dart';

enum NeoAgentAppMode { standard, launcher }

NeoAgentAppMode _appModeFromEnvironment() {
  const rawMode = String.fromEnvironment(
    'NEOAGENT_APP_MODE',
    defaultValue: 'standard',
  );
  return rawMode.toLowerCase() == 'launcher'
      ? NeoAgentAppMode.launcher
      : NeoAgentAppMode.standard;
}

enum AppSection {
  chat,
  timeline,
  voiceAssistant,
  devices,
  messaging,
  runs,
  settings,
  accountSettings,
  skills,
  agents,
  integrations,
  memory,
  tasks,
  mcp,
  health,
  server,
  billing,
  team,
  admin,
}

enum SidebarGroup { chat, timeline, automation, team, settings, admin }

extension SidebarGroupX on SidebarGroup {
  String get label {
    switch (this) {
      case SidebarGroup.chat:
        return appStrings.chat;
      case SidebarGroup.timeline:
        return appStrings.timeline;
      case SidebarGroup.automation:
        return appStrings.automation;
      case SidebarGroup.settings:
        return appStrings.settings;
      case SidebarGroup.team:
        return appStrings.team;
      case SidebarGroup.admin:
        return appStrings.admin;
    }
  }

  IconData get icon {
    switch (this) {
      case SidebarGroup.chat:
        return Icons.chat_bubble_outline;
      case SidebarGroup.timeline:
        return Icons.timeline_rounded;
      case SidebarGroup.automation:
        return Icons.auto_awesome_outlined;
      case SidebarGroup.settings:
        return Icons.tune;
      case SidebarGroup.team:
        return Icons.groups_2_outlined;
      case SidebarGroup.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }
}

extension AppSectionX on AppSection {
  String get label {
    switch (this) {
      case AppSection.chat:
        return appStrings.chat;
      case AppSection.timeline:
        return appStrings.timeline;
      case AppSection.voiceAssistant:
        return appStrings.voiceAssistant;
      case AppSection.devices:
        return appStrings.devices;
      case AppSection.messaging:
        return appStrings.messaging;
      case AppSection.runs:
        return appStrings.runs;
      case AppSection.settings:
        return appStrings.settings;
      case AppSection.accountSettings:
        return appStrings.accountSettings;
      case AppSection.skills:
        return appStrings.skills;
      case AppSection.agents:
        return appStrings.agents;
      case AppSection.integrations:
        return appStrings.tools;
      case AppSection.memory:
        return appStrings.memory;
      case AppSection.tasks:
        return appStrings.tasks;
      case AppSection.mcp:
        return appStrings.mcp;
      case AppSection.health:
        return appStrings.health;
      case AppSection.server:
        return appStrings.server;
      case AppSection.billing:
        return appStrings.billing;
      case AppSection.team:
        return appStrings.team;
      case AppSection.admin:
        return appStrings.admin;
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.chat:
        return Icons.chat_bubble_outline;
      case AppSection.timeline:
        return Icons.timeline_rounded;
      case AppSection.voiceAssistant:
        return Icons.keyboard_voice_outlined;
      case AppSection.devices:
        return Icons.devices_other_outlined;
      case AppSection.messaging:
        return Icons.forum_outlined;
      case AppSection.runs:
        return Icons.monitor_heart_outlined;
      case AppSection.settings:
        return Icons.tune;
      case AppSection.accountSettings:
        return Icons.manage_accounts_outlined;
      case AppSection.skills:
        return Icons.extension_outlined;
      case AppSection.agents:
        return Icons.smart_toy_outlined;
      case AppSection.integrations:
        return Icons.handyman_outlined;
      case AppSection.memory:
        return Icons.psychology_outlined;
      case AppSection.tasks:
        return Icons.schedule_outlined;
      case AppSection.mcp:
        return Icons.hub_outlined;
      case AppSection.health:
        return Icons.favorite_border;
      case AppSection.server:
        return Icons.dns_outlined;
      case AppSection.billing:
        return Icons.credit_card;
      case AppSection.team:
        return Icons.groups_2_outlined;
      case AppSection.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  SidebarGroup get group {
    switch (this) {
      case AppSection.chat:
      case AppSection.voiceAssistant:
        return SidebarGroup.chat;
      case AppSection.timeline:
        return SidebarGroup.timeline;
      case AppSection.devices:
      case AppSection.skills:
      case AppSection.integrations:
      case AppSection.memory:
      case AppSection.tasks:
      case AppSection.mcp:
      case AppSection.health:
        return SidebarGroup.automation;
      case AppSection.runs:
      case AppSection.settings:
      case AppSection.accountSettings:
      case AppSection.messaging:
      case AppSection.agents:
      case AppSection.server:
      case AppSection.billing:
        return SidebarGroup.settings;
      case AppSection.team:
        return SidebarGroup.team;
      case AppSection.admin:
        return SidebarGroup.admin;
    }
  }

  /// Whether the section shows data that belongs to the selected bot, so it
  /// has nothing meaningful to show while a bot switch is loading.
  bool get isAgentScoped {
    switch (this) {
      case AppSection.chat:
      case AppSection.messaging:
      case AppSection.runs:
      case AppSection.settings:
      case AppSection.skills:
      case AppSection.integrations:
      case AppSection.memory:
      case AppSection.tasks:
      case AppSection.mcp:
        return true;
      default:
        return false;
    }
  }

  AppSection get canonicalSection {
    switch (this) {
      case AppSection.skills:
      case AppSection.mcp:
        return AppSection.integrations;
      default:
        return this;
    }
  }

  AppSection get sidebarSection {
    switch (this) {
      case AppSection.accountSettings:
        return AppSection.settings;
      default:
        return canonicalSection;
    }
  }

  String get navigationTitle {
    final effectiveSection = canonicalSection;
    final groupLabel = effectiveSection.group.label;
    if (effectiveSection == AppSection.voiceAssistant) {
      return effectiveSection.label;
    }
    if (effectiveSection.group == SidebarGroup.chat ||
        effectiveSection.group == SidebarGroup.timeline) {
      return groupLabel;
    }
    if (groupLabel == effectiveSection.label) {
      return groupLabel;
    }
    return appStrings.arg1Arg22(groupLabel, effectiveSection.label);
  }
}
