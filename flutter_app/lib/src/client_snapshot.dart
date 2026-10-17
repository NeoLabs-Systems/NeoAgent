import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

/// The device facts usage data sharing reports: the platform and the app
/// version, nothing that names the device or its owner.
Future<Map<String, dynamic>> describeClientForDataSharing() async {
  String? appVersion;
  try {
    appVersion = (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    appVersion = null;
  }
  return <String, dynamic>{
    'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    'appVersion': appVersion,
  };
}
