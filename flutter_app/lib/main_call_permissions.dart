part of 'main.dart';

const _callPermissionsDismissedKey = 'call_permissions_dont_ask_again';

/// Set once the sheet has been offered in this process, so rebuilt or
/// remounted shells never bring it back during the same launch.
bool _callPermissionsPromptedThisLaunch = false;

/// Asks, once per launch, for what lets an agent's call reach the user while
/// the app is in the background or the phone is locked. Does nothing when
/// everything is already granted, the platform needs none of it, or the user
/// chose "Don't ask again".
Future<void> promptForCallPermissionsIfNeeded(BuildContext context) async {
  if (_callPermissionsPromptedThisLaunch) return;
  _callPermissionsPromptedThisLaunch = true;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_callPermissionsDismissedKey) ?? false) return;
  final status = await CallBridge.permissionStatus();
  if (status.allGranted || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CallPermissionSheet(initial: status),
  );
}

class _CallPermissionSheet extends StatefulWidget {
  const _CallPermissionSheet({required this.initial});

  final CallPermissionStatus initial;

  @override
  State<_CallPermissionSheet> createState() => _CallPermissionSheetState();
}

class _CallPermissionSheetState extends State<_CallPermissionSheet>
    with WidgetsBindingObserver {
  late CallPermissionStatus _status = widget.initial;

  /// Set while "Allow all" walks through the missing permissions one system
  /// screen after another; [_asked] keeps a refused one from being asked
  /// again in the same walk.
  bool _walking = false;
  final Set<String> _asked = <String>{};

  /// What the sheet asks for, in the order "Allow all" goes through it.
  List<({String key, bool granted, Future<void> Function() open})> get _steps =>
      <({String key, bool granted, Future<void> Function() open})>[
        (
          key: 'overlay',
          granted: _status.overlay,
          open: CallBridge.openOverlaySettings,
        ),
        (
          key: 'fullScreenIntent',
          granted: _status.fullScreenIntent,
          open: CallBridge.openFullScreenIntentSettings,
        ),
        (
          key: 'battery',
          granted: _status.unrestrictedBattery,
          open: CallBridge.requestUnrestrictedBattery,
        ),
      ];

  int get _missing => _steps.where((step) => !step.granted).length;

  void _allowAll() {
    _walking = true;
    _asked.clear();
    unawaited(_askNext());
  }

  /// Opens the next missing permission's system screen; coming back from it
  /// re-reads the status and continues here.
  Future<void> _askNext() async {
    for (final step in _steps) {
      if (step.granted || _asked.contains(step.key)) continue;
      _asked.add(step.key);
      await step.open();
      return;
    }
    _walking = false;
  }

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

  /// Each permission is granted in system settings; coming back re-reads them.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await CallBridge.permissionStatus();
    if (!mounted) return;
    if (status.allGranted) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _status = status);
    if (_walking) unawaited(_askNext());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CallColors.backdropTop,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _CallColors.controlBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              appStrings.letCallsReachYou,
              style: GoogleFonts.geist(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: _CallColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appStrings.callPermissionsIntro,
              style: GoogleFonts.geist(
                fontSize: 15,
                height: 1.45,
                color: _CallColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            _CallPermissionRow(
              icon: Icons.open_in_new_rounded,
              title: appStrings.showOverOtherApps,
              detail: appStrings.showOverOtherAppsDetail,
              granted: _status.overlay,
              onAllow: CallBridge.openOverlaySettings,
            ),
            _CallPermissionRow(
              icon: Icons.screen_lock_portrait_rounded,
              title: appStrings.fullScreenCalls,
              detail: appStrings.fullScreenCallsDetail,
              granted: _status.fullScreenIntent,
              onAllow: CallBridge.openFullScreenIntentSettings,
            ),
            _CallPermissionRow(
              icon: Icons.battery_charging_full_rounded,
              title: appStrings.unrestrictedBattery,
              detail: appStrings.unrestrictedBatteryDetail,
              granted: _status.unrestrictedBattery,
              onAllow: CallBridge.requestUnrestrictedBattery,
            ),
            const SizedBox(height: 12),
            if (_missing > 1)
              FilledButton(
                onPressed: _walking ? null : _allowAll,
                style: FilledButton.styleFrom(
                  backgroundColor: _CallColors.accent,
                  foregroundColor: _CallColors.onAccent,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: Text(appStrings.allowAll),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _CallColors.textMuted,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(appStrings.notNow),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_callPermissionsDismissedKey, true);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: _CallColors.textMuted,
                minimumSize: const Size.fromHeight(40),
              ),
              child: Text(appStrings.dontAskAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallPermissionRow extends StatelessWidget {
  const _CallPermissionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.granted,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool granted;
  final Future<void> Function() onAllow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _CallColors.control,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: _CallColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: _CallColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: _CallColors.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (granted)
            Icon(
              Icons.check_circle_rounded,
              color: _CallColors.answer,
              semanticLabel: appStrings.permissionAllowed,
            )
          else
            FilledButton(
              onPressed: () => unawaited(onAllow()),
              style: FilledButton.styleFrom(
                backgroundColor: _CallColors.accent,
                foregroundColor: _CallColors.onAccent,
                minimumSize: const Size(72, 40),
                shape: const StadiumBorder(),
              ),
              child: Text(appStrings.allow),
            ),
        ],
      ),
    );
  }
}
