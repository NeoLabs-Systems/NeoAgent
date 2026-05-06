import 'package:flutter/foundation.dart';

import 'web_app_update_monitor_stub.dart'
    if (dart.library.html) 'web_app_update_monitor_web.dart';

abstract class WebAppUpdateMonitor implements Listenable {
  bool get isSupported;
  bool get updateAvailable;
  bool get isReloading;

  void start();
  Future<void> reloadToLatest();
  void dispose();
}

WebAppUpdateMonitor createWebAppUpdateMonitor() =>
    createPlatformWebAppUpdateMonitor();
