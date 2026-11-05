part of 'main.dart';

/// What the Discover section shows when nothing is typed: a skills.sh
/// leaderboard, or a topic that runs a skills.sh search.
class _SkillsShShelf {
  const _SkillsShShelf(this.id, {this.list, this.query});

  final String id;
  final String? list;

  /// The skills.sh search a topic runs. Searches stay in English: that is the
  /// language of the skills.sh catalogue.
  final String? query;

  String get key => list ?? 'q:$query';

  String get label => switch (id) {
    'popular' => appStrings.skillsShelfPopular,
    'trending' => appStrings.skillsShelfTrending,
    'documents' => appStrings.skillsTopicDocuments,
    'browser' => appStrings.skillsTopicBrowser,
    'research' => appStrings.skillsTopicResearch,
    'writing' => appStrings.skillsTopicWriting,
    'design' => appStrings.skillsTopicDesign,
    'coding' => appStrings.skillsTopicCoding,
    'data' => appStrings.skillsTopicData,
    _ => appStrings.skillsTopicMarketing,
  };
}

const List<_SkillsShShelf> _skillsShShelves = <_SkillsShShelf>[
  _SkillsShShelf('popular', list: 'popular'),
  _SkillsShShelf('trending', list: 'trending'),
  _SkillsShShelf('documents', query: 'documents'),
  _SkillsShShelf('browser', query: 'browser'),
  _SkillsShShelf('research', query: 'research'),
  _SkillsShShelf('writing', query: 'writing'),
  _SkillsShShelf('design', query: 'design'),
  _SkillsShShelf('coding', query: 'code review'),
  _SkillsShShelf('data', query: 'data analysis'),
  _SkillsShShelf('marketing', query: 'marketing'),
];

/// The Skills tab: installed skills as a card grid, then skills.sh. With an
/// empty search, skills.sh shows leaderboards and topics; a search covers both
/// the installed skills and skills.sh.
class _SkillsTab extends StatefulWidget {
  const _SkillsTab({required this.controller, required this.query});

  final NeoAgentController controller;

  /// The Tools page search, trimmed. Matched case-insensitively.
  final String query;

  @override
  State<_SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends State<_SkillsTab> {
  // Shelves already fetched this session, so switching tabs doesn't refetch.
  static final Map<String, List<SkillsShItem>> _shelfCache =
      <String, List<SkillsShItem>>{};

  String _status = 'all';
  String _source = 'all';
  _SkillsShShelf _shelf = _skillsShShelves.first;
  Timer? _debounce;
  int _request = 0;
  List<SkillsShItem> _results = const <SkillsShItem>[];
  bool _loading = false;
  String? _error;

  bool get _searching => widget.query.length >= 2;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _SkillsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _reload() {
    _debounce?.cancel();
    if (_searching) {
      final query = widget.query;
      setState(() {
        _loading = true;
        _error = null;
      });
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _fetch(() => widget.controller.searchSkillsSh(query)),
      );
      return;
    }
    final shelf = _shelf;
    final cached = _shelfCache[shelf.key];
    if (cached != null) {
      setState(() {
        _request++;
        _results = cached;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _results = const <SkillsShItem>[];
      _loading = true;
      _error = null;
    });
    _fetch(() async {
      final items = shelf.list != null
          ? await widget.controller.featuredSkillsSh(shelf.list!)
          : await widget.controller.searchSkillsSh(shelf.query!);
      _shelfCache[shelf.key] = items;
      return items;
    });
  }

  Future<void> _fetch(Future<List<SkillsShItem>> Function() load) async {
    final request = ++_request;
    try {
      final items = await load();
      if (!mounted || request != _request) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _results = const <SkillsShItem>[];
        _error = formatCaughtError(error);
        _loading = false;
      });
    }
  }

  void _selectShelf(_SkillsShShelf shelf) {
    if (shelf.key == _shelf.key) return;
    _shelf = shelf;
    _reload();
  }

  List<SkillItem> _visibleSkills() {
    final query = widget.query.toLowerCase();
    return widget.controller.skills.where((skill) {
      if (query.isNotEmpty &&
          !<String>[
            skill.name,
            skill.description,
            skill.category,
            skill.source,
          ].any((field) => field.toLowerCase().contains(query))) {
        return false;
      }
      switch (_status) {
        case 'active':
          if (!skill.enabled || skill.draft) return false;
        case 'draft':
          if (!skill.draft) return false;
        case 'disabled':
          if (skill.enabled) return false;
      }
      return _source == 'all' || skill.source == _source;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final skills = _visibleSkills();
    final filtered = _status != 'all' || _source != 'all';
    final installedBySkillsShId = <String, String>{
      for (final skill in controller.skills)
        if (skill.skillsShId.isNotEmpty) skill.skillsShId: skill.name,
    };

    // Skills from one uploaded library fold into a single card.
    final libraries = <String, List<SkillItem>>{};
    final loose = <SkillItem>[];
    for (final skill in skills) {
      if (skill.library.isEmpty) {
        loose.add(skill);
      } else {
        libraries.putIfAbsent(skill.library, () => <SkillItem>[]).add(skill);
      }
    }
    final narrowed = widget.query.isNotEmpty || filtered;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        _SkillsSectionBar(
          title: appStrings.skillsInstalled,
          count: skills.length,
          trailing: <Widget>[
            IconButton(
              tooltip: appStrings.skillLibraryUpload,
              visualDensity: VisualDensity.compact,
              onPressed: () => _openSkillLibraryUpload(context, controller),
              icon: Icon(Icons.drive_folder_upload_outlined, size: 20),
            ),
            _ToolsFilterMenu(
              icon: Icons.tune_rounded,
              label: appStrings.status,
              value: _status,
              options: const <String>['all', 'active', 'draft', 'disabled'],
              onSelected: (value) => setState(() => _status = value),
            ),
            _ToolsFilterMenu(
              icon: Icons.source_outlined,
              label: appStrings.source,
              value: _source,
              options: const <String>[
                'all',
                'built-in',
                'learned',
                'user',
                'skills.sh',
                'library',
              ],
              onSelected: (value) => setState(() => _source = value),
            ),
          ],
        ),
        if (skills.isEmpty)
          _SkillsQuietNote(
            icon: Icons.auto_awesome_outlined,
            text: narrowed
                ? appStrings.noSkillsMatchTheseFilters
                : appStrings.skillsNoneInstalled,
          ),
        for (final entry in libraries.entries) ...<Widget>[
          _SkillLibraryCard(
            key: ValueKey<String>('library:${entry.key}'),
            controller: controller,
            library: entry.key,
            skills: entry.value,
            expandedByDefault: narrowed,
          ),
          const SizedBox(height: 10),
        ],
        if (loose.isNotEmpty)
          _ToolCardGrid(
            children: <Widget>[
              for (final skill in loose)
                _SkillCard(
                  key: ValueKey<String>('skill:${skill.name}'),
                  controller: controller,
                  skill: skill,
                ),
            ],
          ),
        const SizedBox(height: 32),
        _SkillsSectionBar(
          title: _searching
              ? appStrings.skillsOnSkillsSh
              : appStrings.skillsDiscover,
          count: _loading ? null : _results.length,
          subtitle: 'skills.sh',
        ),
        if (!_searching) ...<Widget>[
          _SkillsShShelfBar(selected: _shelf, onSelected: _selectShelf),
          const SizedBox(height: 14),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_results.isEmpty)
          _SkillsQuietNote(
            icon: _error == null
                ? Icons.travel_explore_rounded
                : Icons.cloud_off_rounded,
            text: _error ??
                (_searching
                    ? appStrings.noSkillsShMatches
                    : appStrings.skillsShHint),
          )
        else
          _ToolCardGrid(
            children: <Widget>[
              for (final item in _results)
                _SkillsShCard(
                  key: ValueKey<String>('sh:${item.id}'),
                  controller: controller,
                  item: item,
                  installedName:
                      installedBySkillsShId[item.id] ??
                      (controller.skills.any(
                            (skill) => skill.name == item.installedName,
                          )
                          ? item.installedName
                          : ''),
                ),
            ],
          ),
      ],
    );
  }
}

/// Section title with a count on the left and small controls on the right.
class _SkillsSectionBar extends StatelessWidget {
  const _SkillsSectionBar({
    required this.title,
    this.count,
    this.subtitle,
    this.trailing = const <Widget>[],
  });

  final String title;
  final int? count;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: _textPrimary,
            ),
          ),
          if (count != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                color: _textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          if (subtitle != null) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              subtitle!,
              style: _monoStyle(size: 11.5, color: _textMuted),
            ),
          ],
          const SizedBox(width: 12),
          // Filters scroll sideways on phones instead of overflowing.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (index, control) in trailing.indexed) ...<Widget>[
                      if (index > 0) const SizedBox(width: 6),
                      control,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsQuietNote extends StatelessWidget {
  const _SkillsQuietNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: _textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsShShelfBar extends StatelessWidget {
  const _SkillsShShelfBar({required this.selected, required this.onSelected});

  final _SkillsShShelf selected;
  final ValueChanged<_SkillsShShelf> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final (index, shelf) in _skillsShShelves.indexed) ...<Widget>[
            // Leaderboards first, then a hairline, then topics.
            if (index == 2)
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: _border,
              )
            else if (index > 0)
              const SizedBox(width: 6),
            _SkillsShShelfChip(
              shelf: shelf,
              selected: shelf.key == selected.key,
              onTap: () => onSelected(shelf),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillsShShelfChip extends StatelessWidget {
  const _SkillsShShelfChip({
    required this.shelf,
    required this.selected,
    required this.onTap,
  });

  final _SkillsShShelf shelf;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (shelf.list) {
      'popular' => Icons.star_rounded,
      'trending' => Icons.trending_up_rounded,
      _ => null,
    };
    final foreground = selected ? _accent : _textSecondary;
    return Material(
      color: selected ? _accentMuted : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? _accent.withValues(alpha: 0.45) : _border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                shelf.label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Even grid of fixed-height cards: up to three across, one on phones.
class _ToolCardGrid extends StatelessWidget {
  const _ToolCardGrid({required this.children});

  final List<Widget> children;

  static const double _gap = 10;
  static const double _minCardWidth = 260;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) / (_minCardWidth + _gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Card frame shared by installed and skills.sh skills.
class _SkillCardFrame extends StatelessWidget {
  const _SkillCardFrame({
    required this.name,
    required this.meta,
    required this.body,
    required this.trailing,
    required this.onTap,
    this.dimmed = false,
  });

  final String name;
  final Widget meta;
  final Widget body;
  final Widget trailing;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          height: 112,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: dimmed ? 0.55 : 1,
                      child: Row(
                        children: <Widget>[
                          _SkillLetterBadge(name: name, size: 34),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                meta,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  trailing,
                ],
              ),
              const Spacer(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: dimmed ? 0.55 : 1,
                child: body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillLetterBadge extends StatelessWidget {
  const _SkillLetterBadge({required this.name, this.size = 34});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _toolAccentFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Where a skill came from, in the words the card shows.
String _skillOriginLabel(SkillItem skill) {
  if (skill.library.isNotEmpty) return skill.library;
  if (skill.skillsShId.isNotEmpty) return 'skills.sh';
  if (skill.builtIn) return appStrings.skillOriginBuiltIn;
  return switch (skill.source) {
    'learned' => appStrings.skillOriginLearned,
    'user' || 'local' => appStrings.skillOriginYours,
    _ => skill.source,
  };
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({super.key, required this.controller, required this.skill});

  final NeoAgentController controller;
  final SkillItem skill;

  @override
  Widget build(BuildContext context) {
    return _SkillCardFrame(
      name: skill.name,
      dimmed: !skill.enabled,
      onTap: () => _openSkillDialog(context, controller, skill.name),
      meta: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              '${_skillOriginLabel(skill)} · ${skill.category}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
          ),
          if (skill.draft) ...<Widget>[
            const SizedBox(width: 6),
            _SkillTag(label: appStrings.draft, color: _warning),
          ],
        ],
      ),
      trailing: Transform.scale(
        scale: 0.78,
        child: Switch(
          value: skill.enabled,
          onChanged: (value) => _setSkillEnabled(context, controller, skill, value),
        ),
      ),
      body: Text(
        skill.description.ifEmpty(appStrings.noDescription),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _textSecondary, fontSize: 12.5, height: 1.35),
      ),
    );
  }
}

Future<void> _setSkillEnabled(
  BuildContext context,
  NeoAgentController controller,
  SkillItem skill,
  bool enabled,
) async {
  try {
    await controller.setSkillEnabled(skill.name, enabled);
  } catch (error) {
    if (context.mounted) {
      _showFormError(context, controller.friendlyErrorMessage(error));
    }
  }
}

class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A skills.sh skill. Installing makes it a regular user skill, so an
/// installed one opens the same popup as any other.
class _SkillsShCard extends StatefulWidget {
  const _SkillsShCard({
    super.key,
    required this.controller,
    required this.item,
    required this.installedName,
  });

  final NeoAgentController controller;
  final SkillsShItem item;

  /// The local skill this one was installed as, or empty.
  final String installedName;

  @override
  State<_SkillsShCard> createState() => _SkillsShCardState();
}

class _SkillsShCardState extends State<_SkillsShCard> {
  bool _installing = false;

  Future<void> _install() async {
    setState(() => _installing = true);
    try {
      final name = await widget.controller.installSkillsShSkill(widget.item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appStrings.installedSkillArg1(name))),
      );
    } catch (error) {
      if (mounted) _showFormError(context, formatCaughtError(error));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _open() {
    if (widget.installedName.isNotEmpty) {
      _openSkillDialog(context, widget.controller, widget.installedName);
      return;
    }
    url_launcher.launchUrl(
      Uri.parse('https://skills.sh/${widget.item.id}'),
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final installed = widget.installedName.isNotEmpty;
    final buttonStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
    return _SkillCardFrame(
      name: item.name,
      onTap: _open,
      meta: Text(
        item.source,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _monoStyle(size: 11, color: _textMuted),
      ),
      trailing: installed
          ? OutlinedButton(
              style: buttonStyle,
              onPressed: _open,
              child: Text(appStrings.open),
            )
          : FilledButton.tonal(
              style: buttonStyle,
              onPressed: _installing ? null : _install,
              child: _IntegrationBusyLabel(
                busy: _installing,
                label: appStrings.skillsGet,
              ),
            ),
      body: Row(
        children: <Widget>[
          if (item.installs != null) ...<Widget>[
            Icon(Icons.download_rounded, size: 14, color: _textMuted),
            const SizedBox(width: 4),
            Text(
              _formatInstallCount(item.installs!),
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (item.official)
            _SkillTag(
              label: appStrings.skillsOfficial,
              color: _info,
              icon: Icons.verified_rounded,
            ),
          if (installed) ...<Widget>[
            if (item.official) const SizedBox(width: 6),
            _SkillTag(
              label: appStrings.skillsInstalled,
              color: _success,
              icon: Icons.check_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatInstallCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}

Future<void> _openSkillDialog(
  BuildContext context,
  NeoAgentController controller,
  String name,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SkillDialog(controller: controller, skillName: name),
  );
}

/// One skill: its SKILL.md in a large editor, the on/off switch, and delete.
class _SkillDialog extends StatefulWidget {
  const _SkillDialog({required this.controller, required this.skillName});

  final NeoAgentController controller;
  final String skillName;

  @override
  State<_SkillDialog> createState() => _SkillDialogState();
}

class _SkillDialogState extends State<_SkillDialog> {
  final TextEditingController _content = TextEditingController();
  String _saved = '';
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  String _error = '';

  bool get _dirty => !_loading && _content.text != _saved;
  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    _content.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final document = await widget.controller.fetchSkillDocument(
        widget.skillName,
      );
      _saved = document.content;
      _content.text = document.content;
    } catch (error) {
      _error = widget.controller.friendlyErrorMessage(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final content = _content.text;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.controller.saveSkillContent(
        name: widget.skillName,
        content: content,
      );
      _saved = content;
    } catch (error) {
      _error = widget.controller.friendlyErrorMessage(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(SkillItem skill) async {
    final confirmed = await _confirmIntegrationAction(
      context,
      title: appStrings.deleteSkill,
      body: skill.builtIn
          ? appStrings.skillBuiltInDeleteBody(skill.name)
          : appStrings.arg1WillBeRemovedPermanently(skill.name),
      confirmLabel: appStrings.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _error = '';
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.controller.deleteSkill(skill.name);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(appStrings.deletedArg1(skill.name))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = widget.controller.friendlyErrorMessage(error);
      });
    }
  }

  /// Leaving with unsaved edits asks first.
  Future<void> _close() async {
    if (_dirty) {
      final discard = await _confirmIntegrationAction(
        context,
        title: appStrings.skillDiscardTitle,
        body: appStrings.skillDiscardBody(widget.skillName),
        confirmLabel: appStrings.discard,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final skill = widget.controller.skills
            .where((item) => item.name == widget.skillName)
            .firstOrNull;
        final editorHeight = (MediaQuery.sizeOf(context).height * 0.58)
            .clamp(240.0, 640.0);
        return PopScope(
          canPop: !_dirty && !_busy,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_busy) _close();
          },
          child: _IntegrationDialog(
            width: 880,
            title: widget.skillName,
            badge: _SkillLetterBadge(name: widget.skillName, size: 38),
            subtitle: skill == null
                ? appStrings.thisSkillIsNoLongerInstalled
                : '${_skillOriginLabel(skill)} · ${skill.category}${skill.draft ? ' · ${appStrings.draft}' : ''}',
            error: _error,
            onClose: _busy ? null : _close,
            leading: skill == null
                ? null
                : _IntegrationDangerButton(
                    label: appStrings.delete,
                    onPressed: _busy ? null : () => _delete(skill),
                  ),
            actions: <Widget>[
              if (skill != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      skill.enabled ? appStrings.on : appStrings.off,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch(
                      value: skill.enabled,
                      onChanged: _busy
                          ? null
                          : (value) => _setSkillEnabled(
                              context,
                              widget.controller,
                              skill,
                              value,
                            ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              FilledButton(
                onPressed: _dirty && !_busy && skill != null ? _save : null,
                child: _IntegrationBusyLabel(
                  busy: _saving,
                  label: appStrings.save,
                ),
              ),
            ],
            body: <Widget>[
              if (skill != null && skill.description.isNotEmpty) ...<Widget>[
                Text(
                  skill.description,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (skill?.builtIn == true)
                _IntegrationHint(
                  appStrings.skillBuiltInEditHint,
                ),
              SizedBox(
                height: editorHeight,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TextField(
                        controller: _content,
                        enabled: !_busy && skill != null,
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: _monoStyle(size: 12.5, color: _textPrimary)
                            .copyWith(height: 1.5),
                        decoration: InputDecoration(
                          hintText: appStrings.skillContent,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A new skill written by hand: a file name and the SKILL.md content.
Future<void> _openCreateSkill(
  BuildContext context,
  NeoAgentController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreateSkillDialog(controller: controller),
  );
}

class _CreateSkillDialog extends StatefulWidget {
  const _CreateSkillDialog({required this.controller});

  final NeoAgentController controller;

  @override
  State<_CreateSkillDialog> createState() => _CreateSkillDialogState();
}

class _CreateSkillDialogState extends State<_CreateSkillDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _content = TextEditingController(
    text: appStrings.nameNewSkillDescriptionDescribeWhat,
  );
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final filename = _name.text.trim();
    if (filename.isEmpty) {
      setState(() => _error = appStrings.pleaseEnterAFilename);
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.controller.createSkill(
        filename: filename,
        content: _content.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = widget.controller.friendlyErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorHeight = (MediaQuery.sizeOf(context).height * 0.5)
        .clamp(220.0, 560.0);
    return _IntegrationDialog(
      width: 880,
      title: appStrings.newSkill2,
      error: _error,
      onClose: _saving ? null : () => Navigator.of(context).pop(),
      actions: <Widget>[
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _IntegrationBusyLabel(busy: _saving, label: appStrings.create),
        ),
      ],
      body: <Widget>[
        TextField(
          controller: _name,
          autofocus: true,
          enabled: !_saving,
          decoration: InputDecoration(
            labelText: appStrings.filename,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: editorHeight,
          child: TextField(
            controller: _content,
            enabled: !_saving,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: _monoStyle(size: 12.5, color: _textPrimary)
                .copyWith(height: 1.5),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}

/// An uploaded skill library folded into one card: its name, how many skills
/// it holds, one switch for all of them, and the skills themselves behind the
/// expand arrow.
class _SkillLibraryCard extends StatefulWidget {
  const _SkillLibraryCard({
    super.key,
    required this.controller,
    required this.library,
    required this.skills,
    required this.expandedByDefault,
  });

  final NeoAgentController controller;
  final String library;
  final List<SkillItem> skills;

  /// Open while a search or filter narrows the list, so matches show.
  final bool expandedByDefault;

  @override
  State<_SkillLibraryCard> createState() => _SkillLibraryCardState();
}

class _SkillLibraryCardState extends State<_SkillLibraryCard> {
  bool? _expanded;

  bool get _isExpanded => _expanded ?? widget.expandedByDefault;

  Future<void> _setEnabled(bool enabled) async {
    try {
      await widget.controller.setSkillLibraryEnabled(widget.library, enabled);
    } catch (error) {
      if (mounted) {
        _showFormError(context, widget.controller.friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmIntegrationAction(
      context,
      title: appStrings.skillLibraryDelete,
      body: appStrings.skillLibraryDeleteBody(
        widget.skills.length,
        widget.library,
      ),
      confirmLabel: appStrings.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.controller.deleteSkillLibrary(widget.library);
    } catch (error) {
      if (mounted) {
        _showFormError(context, widget.controller.friendlyErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.skills;
    final enabledCount = skills.where((skill) => skill.enabled).length;
    final offCount = skills.length - enabledCount;
    final color = _toolAccentFor(widget.library);
    final names = skills.map((skill) => skill.name).toList();
    final preview = names.length <= 4
        ? names.join(' · ')
        : '${names.take(4).join(' · ')}  +${names.length - 4}';

    return Container(
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.34)),
                    ),
                    child: Icon(Icons.folder_copy_rounded, size: 18, color: color),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                widget.library,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SkillTag(
                              label: appStrings.skillLibrarySkillCount(
                                skills.length,
                              ),
                              color: _accentAlt,
                            ),
                            if (offCount > 0 && enabledCount > 0) ...<Widget>[
                              const SizedBox(width: 6),
                              _SkillTag(
                                label: appStrings.skillLibraryOffCount(offCount),
                                color: _textMuted,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _monoStyle(size: 11.5, color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.78,
                    child: Switch(
                      value: enabledCount > 0,
                      onChanged: _setEnabled,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: appStrings.moreActions,
                    icon: Icon(Icons.more_horiz_rounded, color: _textSecondary),
                    onSelected: (_) => _delete(),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.delete_outline_rounded, size: 18, color: _danger),
                            const SizedBox(width: 10),
                            Text(
                              appStrings.skillLibraryDelete,
                              style: TextStyle(color: _danger),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more_rounded, color: _textMuted),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_isExpanded
                ? const SizedBox(width: double.infinity)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 720 ? 2 : 1;
                        final width = (constraints.maxWidth - 12) / columns;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                          child: Wrap(
                            children: <Widget>[
                              for (final skill in skills)
                                SizedBox(
                                  width: width,
                                  child: _SkillLibraryRow(
                                    controller: widget.controller,
                                    skill: skill,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One skill inside an expanded library card.
class _SkillLibraryRow extends StatelessWidget {
  const _SkillLibraryRow({required this.controller, required this.skill});

  final NeoAgentController controller;
  final SkillItem skill;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tag),
      onTap: () => _openSkillDialog(context, controller, skill.name),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: skill.enabled ? 1 : 0.55,
                child: Row(
                  children: <Widget>[
                    _SkillLetterBadge(name: skill.name, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            skill.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            skill.description.ifEmpty(appStrings.noDescription),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: skill.enabled,
                onChanged: (value) =>
                    _setSkillEnabled(context, controller, skill, value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openSkillLibraryUpload(
  BuildContext context,
  NeoAgentController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SkillLibraryUploadDialog(controller: controller),
  );
}

/// Picks a zip of skill folders, names the library, and shows what got
/// installed and what was left out.
class _SkillLibraryUploadDialog extends StatefulWidget {
  const _SkillLibraryUploadDialog({required this.controller});

  final NeoAgentController controller;

  @override
  State<_SkillLibraryUploadDialog> createState() =>
      _SkillLibraryUploadDialogState();
}

class _SkillLibraryUploadDialogState extends State<_SkillLibraryUploadDialog> {
  final TextEditingController _name = TextEditingController();
  PlatformFile? _file;
  bool _uploading = false;
  String _error = '';
  SkillLibraryUploadResult? _result;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _defaultName =>
      (_file?.name ?? '').replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (!mounted || file == null) return;
    setState(() {
      _file = file;
      _error = file.bytes == null ? appStrings.skillLibraryUnreadable : '';
    });
  }

  Future<void> _upload() async {
    final file = _file;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      _uploading = true;
      _error = '';
    });
    try {
      final result = await widget.controller.uploadSkillLibrary(
        filename: file.name,
        bytes: bytes,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error = widget.controller.friendlyErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return _IntegrationDialog(
      width: 620,
      title: appStrings.skillLibraryUpload,
      subtitle: appStrings.skillLibraryUploadSubtitle,
      badge: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.drive_folder_upload_outlined, size: 20, color: _accent),
      ),
      error: _error,
      onClose: _uploading ? null : () => Navigator.of(context).pop(),
      actions: <Widget>[
        if (result != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appStrings.done),
          )
        else
          FilledButton(
            onPressed: _uploading || _file?.bytes == null ? null : _upload,
            child: _IntegrationBusyLabel(
              busy: _uploading,
              label: appStrings.install,
            ),
          ),
      ],
      body: result != null ? _buildResult(result) : _buildForm(),
    );
  }

  List<Widget> _buildForm() {
    final file = _file;
    return <Widget>[
      _IntegrationHint(appStrings.skillLibraryUploadHint),
      Material(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: _uploading ? null : _pick,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: file == null ? _border : _accent.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  file == null ? Icons.upload_file_rounded : Icons.folder_zip_rounded,
                  color: file == null ? _textMuted : _accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        file?.name ?? appStrings.skillLibraryChooseZip,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (file != null)
                        Text(
                          _formatFileSize(file.size),
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (file != null)
                  Text(
                    appStrings.skillLibraryChangeFile,
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _name,
        enabled: !_uploading,
        decoration: InputDecoration(
          isDense: true,
          labelText: appStrings.skillLibraryName,
          hintText: _defaultName.isEmpty ? null : _defaultName,
          helperText: appStrings.skillLibraryNameHelp,
        ),
      ),
    ];
  }

  List<Widget> _buildResult(SkillLibraryUploadResult result) {
    Widget names(List<String> items, Color color) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final name in items) _SkillTag(label: name, color: color),
      ],
    );
    return <Widget>[
      Row(
        children: <Widget>[
          Icon(
            result.installed.isEmpty
                ? Icons.info_outline_rounded
                : Icons.check_circle_rounded,
            color: result.installed.isEmpty ? _warning : _success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.library.isEmpty
                  ? appStrings.skillLibraryInstalledCount(result.installed.length)
                  : appStrings.skillLibraryInstalledInto(
                      result.installed.length,
                      result.library,
                    ),
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      if (result.installed.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        names(result.installed, _success),
      ],
      if (result.removed.isNotEmpty) ...<Widget>[
        const SizedBox(height: 18),
        _TaskEditorSectionLabel(appStrings.skillLibraryRemovedTitle),
        names(result.removed, _textMuted),
      ],
      if (result.skipped.isNotEmpty) ...<Widget>[
        const SizedBox(height: 18),
        _TaskEditorSectionLabel(appStrings.skillLibrarySkippedTitle),
        for (final item in result.skipped)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '${item.name}  ',
                    style: _monoStyle(size: 12.5, color: _textPrimary),
                  ),
                  TextSpan(
                    text: item.reason,
                    style: TextStyle(color: _textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
  }
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}
