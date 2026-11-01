part of 'main.dart';

/// This phone's calendar and contacts sharing: which kinds it shares, with
/// which agent, and when it last synced. The native side does the syncing,
/// in the background too; this turns it on, off, and nudges it.
class PhoneSync extends ChangeNotifier {
  PhoneSync(this._controller);

  static const List<String> kinds = <String>['calendar', 'contacts'];
  static const String _deviceIdKey = 'phone_sync_device_id';
  static const String _ownerKey = 'phone_sync_owner';
  static const String _agentKey = 'phone_sync_agent_id';
  static const String _kindsKey = 'phone_sync_kinds';
  static const String _promptedKey = 'phone_sync_prompted';

  final NeoAgentController _controller;
  final DeviceSyncBridge _bridge = DeviceSyncBridge();

  DeviceSyncStatus status = const DeviceSyncStatus();
  List<String> grantedKinds = const <String>[];
  bool busy = false;

  /// The native status has been read at least once.
  bool loaded = false;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  SharedPreferences? get _prefs => _controller._prefs;

  List<String> get _storedKinds =>
      _prefs?.getStringList(_kindsKey) ?? const <String>[];

  /// Shared with the agent the app is showing now, not another one.
  bool get isSharingWithCurrentAgent =>
      status.enabled &&
      _prefs?.getString(_agentKey) == (_controller.selectedAgentId ?? '');

  /// Asked once per install, after sign-in, while nothing is shared yet.
  bool get shouldOfferSetup =>
      supported &&
      loaded &&
      _controller.isAuthenticated &&
      !_controller.showOnboarding &&
      !status.enabled &&
      _prefs?.getBool(_promptedKey) != true;

  Future<void> markOffered() async {
    await _prefs?.setBool(_promptedKey, true);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!supported) return;
    status = await _bridge.status();
    grantedKinds = await _bridge.grantedKinds();
    loaded = true;
    notifyListeners();
  }

  Future<String> _deviceId() async {
    final stored = _prefs?.getString(_deviceIdKey) ?? '';
    if (stored.isNotEmpty) return stored;
    final random = math.Random.secure();
    final id = List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    await _prefs?.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> _configureNative(List<String> shared) async {
    await _bridge.configure(
      enabled: true,
      backendUrl: _controller.backendUrl,
      sessionCookie: _controller.sessionCookie ?? '',
      agentId: _prefs?.getString(_agentKey) ?? '',
      deviceId: await _deviceId(),
      kinds: shared,
    );
  }

  Future<T> _run<T>(Future<T> Function() work) async {
    busy = true;
    notifyListeners();
    try {
      return await work();
    } finally {
      busy = false;
      await refresh();
    }
  }

  /// Asks for access to [wanted], then shares whatever was granted. Returns the
  /// kinds now shared; empty when the phone refused access.
  Future<List<String>> enable(List<String> wanted) => _run(() async {
    final granted = (await _bridge.requestPermissions(
      wanted,
    )).where(wanted.contains).toList();
    if (granted.isEmpty) return granted;
    final agentId = _controller.selectedAgentId ?? '';
    final previousAgent = _prefs?.getString(_agentKey);
    if (status.enabled && previousAgent != null && previousAgent != agentId) {
      await _forget(previousAgent);
    }
    final client = _controller._backendClient;
    await client.registerDeviceSync(
      _controller.backendUrl,
      deviceId: await _deviceId(),
      deviceName: await _bridge.deviceName(),
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      kinds: granted,
      agentId: agentId,
    );
    await _prefs?.setString(_ownerKey, _controller.username);
    await _prefs?.setString(_agentKey, agentId);
    await _prefs?.setStringList(_kindsKey, granted);
    await _prefs?.setBool(_promptedKey, true);
    await _configureNative(granted);
    status = await _bridge.syncNow();
    await _controller.refreshSkills();
    return granted;
  });

  Future<void> disable() => _run(() async {
    await _forget(_prefs?.getString(_agentKey) ?? '');
    await _prefs?.remove(_kindsKey);
    await _prefs?.remove(_agentKey);
    await _controller.refreshSkills();
  });

  Future<void> _forget(String agentId) async {
    await _bridge.configure(enabled: false);
    try {
      await _controller._backendClient.unregisterDeviceSync(
        _controller.backendUrl,
        deviceId: await _deviceId(),
        agentId: agentId,
      );
    } catch (error) {
      // The server may already have forgotten this phone.
      debugPrint('[PhoneSync] unregister failed: $error');
    }
  }

  Future<void> syncNow() => _run(() async {
    status = await _bridge.syncNow();
    // The server forgot this phone (disconnected from another device).
    if (!status.enabled) await _controller.refreshSkills();
  });

  Future<void> openSettings() => _bridge.openSettings();

  /// After sign-in and when the app comes back: hand the native sync the
  /// current session and sync. Another account on this phone starts fresh.
  Future<void> resume() async {
    if (!supported) return;
    final owner = _prefs?.getString(_ownerKey);
    if (owner != null && owner != _controller.username) {
      await _prefs?.remove(_kindsKey);
      await _prefs?.remove(_agentKey);
      await _prefs?.remove(_ownerKey);
      await _bridge.configure(enabled: false);
    }
    final shared = _storedKinds;
    if (shared.isNotEmpty) {
      await _configureNative(shared);
      status = await _bridge.syncNow();
    }
    await refresh();
  }

  /// Signed out: background sync stops until the same account signs in again.
  Future<void> pause() async {
    if (!supported) return;
    await _bridge.configure(enabled: false);
    status = const DeviceSyncStatus();
    notifyListeners();
  }

  void handleWake(dynamic data) {
    final deviceId = data is Map ? data['deviceId']?.toString() : null;
    if (deviceId == null || deviceId != _prefs?.getString(_deviceIdKey)) return;
    unawaited(syncNow());
  }
}
