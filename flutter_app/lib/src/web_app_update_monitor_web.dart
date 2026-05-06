// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'web_app_update_monitor.dart';

const String _currentWebBuildId = String.fromEnvironment(
  'NEOAGENT_WEB_BUILD_ID',
);

WebAppUpdateMonitor createPlatformWebAppUpdateMonitor() =>
    _WebPlatformAppUpdateMonitor();

class _WebPlatformAppUpdateMonitor extends ChangeNotifier
    implements WebAppUpdateMonitor {
  static const Duration _pollInterval = Duration(minutes: 1);

  Timer? _pollTimer;
  bool _updateAvailable = false;
  bool _isReloading = false;

  @override
  bool get isSupported => _currentWebBuildId.trim().isNotEmpty;

  @override
  bool get updateAvailable => _updateAvailable;

  @override
  bool get isReloading => _isReloading;

  @override
  void start() {
    if (!isSupported || _pollTimer != null) {
      return;
    }
    unawaited(_checkForUpdate());
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_checkForUpdate()),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_updateAvailable || _isReloading) {
      return;
    }
    try {
      final buildInfoUri = Uri.base.resolve(
        '/app-build.json?ts=${DateTime.now().microsecondsSinceEpoch}',
      );
      final response = await http.get(
        buildInfoUri,
        headers: const <String, String>{
          'cache-control': 'no-cache, no-store, max-age=0',
          'pragma': 'no-cache',
        },
      );
      if (response.statusCode != 200) {
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return;
      }
      final latestBuildId = payload['buildId']?.toString().trim() ?? '';
      if (latestBuildId.isEmpty || latestBuildId == _currentWebBuildId) {
        return;
      }
      _updateAvailable = true;
      notifyListeners();
    } catch (_) {}
  }

  @override
  Future<void> reloadToLatest() async {
    if (!isSupported || _isReloading) {
      return;
    }
    _isReloading = true;
    notifyListeners();

    try {
      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker != null) {
        final registrations = await serviceWorker.getRegistrations();
        for (final registration in registrations) {
          await registration.unregister();
        }
      }
    } catch (_) {}

    try {
      final cacheNames = await html.window.caches?.keys();
      if (cacheNames != null) {
        for (final cacheName in cacheNames) {
          await html.window.caches?.delete(cacheName);
        }
      }
    } catch (_) {}

    final reloadUri = Uri(
      path: Uri.base.path.isEmpty ? '/' : Uri.base.path,
      queryParameters: <String, String>{
        ...Uri.base.queryParameters,
        'reload': DateTime.now().microsecondsSinceEpoch.toString(),
      },
      fragment: Uri.base.fragment.isEmpty ? null : Uri.base.fragment,
    );
    html.window.location.replace(reloadUri.toString());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }
}
