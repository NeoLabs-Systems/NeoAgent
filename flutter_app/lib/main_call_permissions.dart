part of 'main.dart';

/// Asks, once per launch, for what lets an agent's call reach the user while
/// the app is in the background or the phone is locked. Does nothing when
/// everything is already granted or the platform needs none of it.
Future<void> promptForCallPermissionsIfNeeded(BuildContext context) async {
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _CallColors.textMuted,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(appStrings.notNow),
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
