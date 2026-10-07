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
  voiceAssistant,
  devices,
  runs,
  settings,
  skills,
  integrations,
  memory,
  tasks,
  mcp,
  health,
  team,
  admin,
}

enum SidebarGroup { chat, automation, team, settings, admin }

extension SidebarGroupX on SidebarGroup {
  String get label {
    switch (this) {
      case SidebarGroup.chat:
        return appStrings.chat;
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
      case AppSection.voiceAssistant:
        return appStrings.voiceAssistant;
      case AppSection.devices:
        return appStrings.devices;
      case AppSection.runs:
        return appStrings.runs;
      case AppSection.settings:
        return appStrings.settings;
      case AppSection.skills:
        return appStrings.skills;
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
      case AppSection.voiceAssistant:
        return Icons.keyboard_voice_outlined;
      case AppSection.devices:
        return Icons.devices_other_outlined;
      case AppSection.runs:
        return Icons.monitor_heart_outlined;
      case AppSection.settings:
        return Icons.tune;
      case AppSection.skills:
        return Icons.extension_outlined;
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
      case AppSection.devices:
      case AppSection.skills:
      case AppSection.integrations:
      case AppSection.memory:
      case AppSection.tasks:
      case AppSection.mcp:
      case AppSection.health:
      case AppSection.runs:
        return SidebarGroup.automation;
      case AppSection.settings:
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

  String get navigationTitle {
    final effectiveSection = canonicalSection;
    final groupLabel = effectiveSection.group.label;
    if (effectiveSection == AppSection.voiceAssistant) {
      return effectiveSection.label;
    }
    if (effectiveSection.group == SidebarGroup.chat) {
      return groupLabel;
    }
    if (groupLabel == effectiveSection.label) {
      return groupLabel;
    }
    return appStrings.arg1Arg22(groupLabel, effectiveSection.label);
  }
}

/// Who a settings page applies to. Every page names its scope above the title,
/// so a change is never ambiguous about following the account, every agent,
/// only the selected agent, or this app.
enum SettingsScope { account, allAgents, agent, app }

extension SettingsScopeX on SettingsScope {
  String get label {
    switch (this) {
      case SettingsScope.account:
        return appStrings.account;
      case SettingsScope.allAgents:
        return appStrings.settingsScopeAllAgents;
      case SettingsScope.agent:
        return appStrings.settingsScopeAgent;
      case SettingsScope.app:
        return appStrings.settingsScopeApp;
    }
  }
}

/// The pages of the single Settings screen, in the order the list shows them.
enum SettingsPage {
  profile,
  security,
  usage,
  agents,
  permissions,
  computer,
  models,
  behavior,
  voice,
  messaging,
  general,
  system,
}

extension SettingsPageX on SettingsPage {
  SettingsScope get scope {
    switch (this) {
      case SettingsPage.profile:
      case SettingsPage.security:
      case SettingsPage.usage:
        return SettingsScope.account;
      case SettingsPage.agents:
      case SettingsPage.permissions:
      case SettingsPage.computer:
        return SettingsScope.allAgents;
      case SettingsPage.models:
      case SettingsPage.behavior:
      case SettingsPage.voice:
      case SettingsPage.messaging:
        return SettingsScope.agent;
      case SettingsPage.general:
      case SettingsPage.system:
        return SettingsScope.app;
    }
  }

  String get label {
    switch (this) {
      case SettingsPage.profile:
        return appStrings.settingsPageProfile;
      case SettingsPage.security:
        return appStrings.settingsPageSecurity;
      case SettingsPage.usage:
        return appStrings.settingsPageUsage;
      case SettingsPage.agents:
        return appStrings.agents;
      case SettingsPage.permissions:
        return appStrings.settingsPagePermissions;
      case SettingsPage.computer:
        return appStrings.settingsPageComputer;
      case SettingsPage.models:
        return appStrings.models;
      case SettingsPage.behavior:
        return appStrings.settingsPageBehavior;
      case SettingsPage.voice:
        return appStrings.voice;
      case SettingsPage.messaging:
        return appStrings.messaging;
      case SettingsPage.general:
        return appStrings.general;
      case SettingsPage.system:
        return appStrings.settingsPageSystem;
    }
  }

  String get description {
    switch (this) {
      case SettingsPage.profile:
        return appStrings.settingsPageProfileDescription;
      case SettingsPage.security:
        return appStrings.settingsPageSecurityDescription;
      case SettingsPage.usage:
        return appStrings.settingsPageUsageDescription;
      case SettingsPage.agents:
        return appStrings.settingsPageAgentsDescription;
      case SettingsPage.permissions:
        return appStrings.settingsPagePermissionsDescription;
      case SettingsPage.computer:
        return appStrings.settingsPageComputerDescription;
      case SettingsPage.models:
        return appStrings.settingsPageModelsDescription;
      case SettingsPage.behavior:
        return appStrings.settingsPageBehaviorDescription;
      case SettingsPage.voice:
        return appStrings.settingsPageVoiceDescription;
      case SettingsPage.messaging:
        return appStrings.settingsPageMessagingDescription;
      case SettingsPage.general:
        return appStrings.settingsPageGeneralDescription;
      case SettingsPage.system:
        return appStrings.settingsPageSystemDescription;
    }
  }

  IconData get icon {
    switch (this) {
      case SettingsPage.profile:
        return Icons.person_outline;
      case SettingsPage.security:
        return Icons.shield_outlined;
      case SettingsPage.usage:
        return Icons.data_usage_outlined;
      case SettingsPage.agents:
        return Icons.smart_toy_outlined;
      case SettingsPage.permissions:
        return Icons.lock_outline;
      case SettingsPage.computer:
        return Icons.computer_outlined;
      case SettingsPage.models:
        return Icons.hub_outlined;
      case SettingsPage.behavior:
        return Icons.psychology_outlined;
      case SettingsPage.voice:
        return Icons.mic_none_outlined;
      case SettingsPage.messaging:
        return Icons.forum_outlined;
      case SettingsPage.general:
        return Icons.tune;
      case SettingsPage.system:
        return Icons.dns_outlined;
    }
  }
}
