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
  await _showPermissionSheet(
    context,
    icon: Icons.phone_in_talk_rounded,
    title: appStrings.letCallsReachYou,
    intro: appStrings.callPermissionsIntro,
    items: _callPermissionItems(status),
    reload: () async =>
        _callPermissionItems(await CallBridge.permissionStatus()),
    onNeverAsk: () async {
      await prefs.setBool(_callPermissionsDismissedKey, true);
    },
  );
}

/// What lets a call ring over other apps and the lock screen, as the shared
/// permission sheet lists it.
List<_PermissionItem> _callPermissionItems(CallPermissionStatus status) =>
    <_PermissionItem>[
      _PermissionItem(
        key: 'overlay',
        icon: Icons.open_in_new_rounded,
        title: appStrings.showOverOtherApps,
        detail: appStrings.showOverOtherAppsDetail,
        granted: status.overlay,
        request: CallBridge.openOverlaySettings,
      ),
      _PermissionItem(
        key: 'fullScreenIntent',
        icon: Icons.screen_lock_portrait_rounded,
        title: appStrings.fullScreenCalls,
        detail: appStrings.fullScreenCallsDetail,
        granted: status.fullScreenIntent,
        request: CallBridge.openFullScreenIntentSettings,
      ),
      _PermissionItem(
        key: 'battery',
        icon: Icons.battery_charging_full_rounded,
        title: appStrings.unrestrictedBattery,
        detail: appStrings.unrestrictedBatteryDetail,
        granted: status.unrestrictedBattery,
        request: CallBridge.requestUnrestrictedBattery,
      ),
    ];
