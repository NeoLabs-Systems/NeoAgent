import 'package:flutter/foundation.dart';

import 'web_app_update_monitor.dart';

WebAppUpdateMonitor createPlatformWebAppUpdateMonitor() =>
    _UnsupportedWebAppUpdateMonitor();

class _UnsupportedWebAppUpdateMonitor extends ChangeNotifier
    implements WebAppUpdateMonitor {
  @override
  bool get isSupported => false;

  @override
  bool get isReloading => false;

  @override
  bool get updateAvailable => false;

  @override
  void start() {}

  @override
  Future<void> reloadToLatest() async {}
}
