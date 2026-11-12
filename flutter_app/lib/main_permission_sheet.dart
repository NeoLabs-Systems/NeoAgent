part of 'main.dart';

// One look and one flow for every "the system must allow this" sheet: a list
// of permissions, what each is for, and a single "Allow all" that walks
// through the system screens in order. A sheet only supplies its
// [_PermissionItem]s; this file does the rest.

/// A permission the system grants in its own settings screen.
class _PermissionItem {
  const _PermissionItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.granted,
    required this.request,
  });

  final String key;
  final IconData icon;
  final String title;
  final String detail;
  final bool granted;

  /// Opens the system screen where the person allows it.
  final Future<void> Function() request;
}

/// The order "Allow all" asks in. A permission is asked once per walk, and a
/// screen left without allowing it ends the walk, so a refusal is never
/// followed by more screens.
class PermissionWalk {
  final List<String> _queue = <String>[];
  String? _current;

  /// The key whose screen is open now, else null.
  String? get current => _current;
  bool get active => _current != null;

  /// 1-based position of [current] among the permissions the walk started
  /// with, and how many there were.
  int step = 0;
  int total = 0;

  /// Starts over [missing] and returns the first key to ask for.
  String? start(List<String> missing) {
    _queue
      ..clear()
      ..addAll(missing);
    total = missing.length;
    step = 0;
    _current = null;
    return _next();
  }

  /// Called when the person is back from a system screen: the key to ask
  /// for next, or null when the walk is over (all done, or one was refused).
  String? afterReturn(Set<String> granted) {
    final asked = _current;
    if (asked == null) return null;
    if (!granted.contains(asked)) {
      stop();
      return null;
    }
    return _next();
  }

  String? _next() {
    if (_queue.isEmpty) {
      _current = null;
      return null;
    }
    step += 1;
    return _current = _queue.removeAt(0);
  }

  void stop() {
    _queue.clear();
    _current = null;
  }
}

Future<void> _showPermissionSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String intro,
  required List<_PermissionItem> items,
  required Future<List<_PermissionItem>> Function() reload,
  Future<void> Function()? onNeverAsk,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _PermissionSheet(
    icon: icon,
    title: title,
    intro: intro,
    initial: items,
    reload: reload,
    onNeverAsk: onNeverAsk,
  ),
);

class _PermissionSheet extends StatefulWidget {
  const _PermissionSheet({
    required this.icon,
    required this.title,
    required this.intro,
    required this.initial,
    required this.reload,
    this.onNeverAsk,
  });

  final IconData icon;
  final String title;
  final String intro;
  final List<_PermissionItem> initial;

  /// Reads the items again, with their current state.
  final Future<List<_PermissionItem>> Function() reload;

  /// Shows "Don't ask again" when set.
  final Future<void> Function()? onNeverAsk;

  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet>
    with WidgetsBindingObserver {
  late List<_PermissionItem> _items = widget.initial;
  final PermissionWalk _walk = PermissionWalk();

  int get _granted => _items.where((item) => item.granted).length;
  int get _missing => _items.length - _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Each permission is granted in a system screen; coming back re-reads them.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final items = await widget.reload();
    if (!mounted) return;
    if (items.every((item) => item.granted)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _items = items);
    if (_walk.active) {
      final granted = <String>{
        for (final item in items)
          if (item.granted) item.key,
      };
      _open(_walk.afterReturn(granted));
    }
  }

  void _open(String? key) {
    if (key == null) {
      setState(() {});
      return;
    }
    final item = _items.firstWhere((item) => item.key == key);
    setState(() {});
    unawaited(item.request());
  }

  void _allowAll() => _open(
    _walk.start(<String>[
      for (final item in _items)
        if (!item.granted) item.key,
    ]),
  );

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: _accent, size: 30),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          widget.intro,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, height: 1.45),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: _items.isEmpty ? 0 : _granted / _items.length,
                  backgroundColor: _borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(_success),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              appStrings.arg1OfArg2Set(_granted, _items.length),
              style: GoogleFonts.geistMono(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _footer() {
    final waiting = _walk.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_missing > 1)
          FilledButton(
            onPressed: waiting ? null : _allowAll,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: waiting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(appStrings.allowAll),
          ),
        TextButton(
          onPressed: () {
            _walk.stop();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: _textSecondary,
            minimumSize: const Size.fromHeight(46),
          ),
          child: Text(appStrings.notNow),
        ),
        if (widget.onNeverAsk case final neverAsk?)
          TextButton(
            onPressed: () async {
              _walk.stop();
              await neverAsk();
              if (mounted) Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: _textMuted,
              minimumSize: const Size.fromHeight(40),
            ),
            child: Text(appStrings.dontAskAgain),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(),
            const SizedBox(height: AppSpacing.md),
            for (final item in _items)
              _PermissionTile(
                item: item,
                asking: _walk.current == item.key,
                step: _walk.step,
                steps: _walk.total,
              ),
            const SizedBox(height: AppSpacing.sm),
            _footer(),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.item,
    required this.asking,
    required this.step,
    required this.steps,
  });

  final _PermissionItem item;

  /// Whether "Allow all" has this one's system screen open.
  final bool asking;
  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (item.granted) {
      trailing = Icon(
        Icons.check_circle_rounded,
        color: _success,
        semanticLabel: appStrings.permissionAllowed,
      );
    } else if (asking) {
      trailing = SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
      );
    } else {
      trailing = OutlinedButton(
        onPressed: () => unawaited(item.request()),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(72, 40),
          shape: const StadiumBorder(),
        ),
        child: Text(appStrings.allow),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: asking ? _accent.withValues(alpha: 0.6) : _border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 20, color: _accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (asking) ...<Widget>[
                    Text(
                      appStrings.stepArg1OfArg2(step, steps),
                      style: _sectionEyebrowStyle(),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    item.title,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}
