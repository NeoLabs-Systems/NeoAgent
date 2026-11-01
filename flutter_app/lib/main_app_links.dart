part of 'main.dart';

// Links the assistant sends to places in the app (settings_link and
// settings_update results). Under its message each one becomes a card that
// names the place in the reader's language and opens it in place.

final RegExp _appLinkPattern = RegExp(
  r'''(?:https?://[^\s<>()\[\]"']+)?/app/open/[^\s<>()\[\]"']+''',
);

/// The distinct app links in [text], in the order they appear.
List<AppLink> _appLinksIn(String text) {
  final seen = <String>{};
  final links = <AppLink>[];
  for (final match in _appLinkPattern.allMatches(text)) {
    final uri = Uri.tryParse(match.group(0)!);
    final link = uri == null ? null : AppLink.tryParse(uri);
    if (link == null ||
        !seen.add('${link.section}/${link.page}/${link.focus}')) {
      continue;
    }
    links.add(link);
  }
  return links;
}

/// What an app link opens, worded for the card: the place, where it lives,
/// and its icon. Null when this app has no such place.
({String title, String subtitle, IconData icon})? _describeAppLink(
  AppLink link,
  NeoAgentController controller,
) {
  if (link.section == AppSection.settings.name) {
    final page = SettingsPage.values
        .where((candidate) => candidate.name == link.page)
        .firstOrNull;
    if (page == null) {
      return (
        title: appStrings.settings,
        subtitle: AppSection.settings.group.label,
        icon: AppSection.settings.icon,
      );
    }
    final entry = _settingsEntries
        .where((item) => item.page == page && item.anchor == link.focus)
        .firstOrNull;
    return (
      title: entry?.label() ?? page.label,
      subtitle: entry == null
          ? appStrings.settings
          : appStrings.arg1Arg22(appStrings.settings, page.label),
      icon: page.icon,
    );
  }
  final section = AppSection.values
      .where((candidate) => candidate.name == link.section)
      .firstOrNull;
  if (section == null) return null;
  final integration = section == AppSection.integrations
      ? controller.officialIntegrations
            .where((item) => item.id == link.focus)
            .firstOrNull
      : null;
  return (
    title: integration?.label ?? section.label,
    subtitle: integration == null
        ? section.group.label
        : integration.isConnected
        ? integration.statusLabel
        : section.label,
    icon: section.icon,
  );
}

class _AppLinkCards extends StatelessWidget {
  const _AppLinkCards({required this.links, required this.controller});

  final List<AppLink> links;
  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    for (final link in links) {
      final place = _describeAppLink(link, controller);
      if (place == null) continue;
      cards.add(
        _AppLinkCard(
          title: place.title,
          subtitle: place.subtitle,
          icon: place.icon,
          onTap: () => controller.openAppLink(link),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: cards);
  }
}

class _AppLinkCard extends StatelessWidget {
  const _AppLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _accentMuted,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: _accent),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
