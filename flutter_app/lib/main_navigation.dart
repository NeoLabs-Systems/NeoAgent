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
  widgets,
  mcp,
  health,
  server,
  billing,
}

enum SidebarGroup { chat, timeline, automation, settings }

extension SidebarGroupX on SidebarGroup {
  String get label {
    switch (this) {
      case SidebarGroup.chat:
        return 'Chat';
      case SidebarGroup.timeline:
        return 'Timeline';
      case SidebarGroup.automation:
        return 'Automation';
      case SidebarGroup.settings:
        return 'Settings';
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
    }
  }
}

extension AppSectionX on AppSection {
  String get label {
    switch (this) {
      case AppSection.chat:
        return 'Chat';
      case AppSection.timeline:
        return 'Timeline';
      case AppSection.voiceAssistant:
        return 'Voice assistant';
      case AppSection.devices:
        return 'Devices';
      case AppSection.messaging:
        return 'Messaging';
      case AppSection.runs:
        return 'Runs';
      case AppSection.settings:
        return 'Settings';
      case AppSection.accountSettings:
        return 'Account settings';
      case AppSection.skills:
        return 'Skills';
      case AppSection.agents:
        return 'Agents';
      case AppSection.integrations:
        return 'Tools';
      case AppSection.memory:
        return 'Memory';
      case AppSection.tasks:
        return 'Tasks';
      case AppSection.widgets:
        return 'Widgets';
      case AppSection.mcp:
        return 'MCP';
      case AppSection.health:
        return 'Health';
      case AppSection.server:
        return 'Server';
      case AppSection.billing:
        return 'Billing';
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
      case AppSection.widgets:
        return Icons.dashboard_customize_outlined;
      case AppSection.mcp:
        return Icons.hub_outlined;
      case AppSection.health:
        return Icons.favorite_border;
      case AppSection.server:
        return Icons.dns_outlined;
      case AppSection.billing:
        return Icons.credit_card;
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
      case AppSection.widgets:
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
    return '$groupLabel · ${effectiveSection.label}';
  }
}
