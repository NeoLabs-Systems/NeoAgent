import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'android_apk_drop_zone_stub.dart'
    if (dart.library.html) 'android_apk_drop_zone_web.dart';

typedef AndroidApkInstallCallback =
    Future<void> Function({required String filename, required Uint8List bytes});

class AndroidApkDropZone extends StatelessWidget {
  const AndroidApkDropZone({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onInstall,
  });

  final bool enabled;
  final bool busy;
  final AndroidApkInstallCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return buildAndroidApkDropZone(
      context,
      enabled: enabled,
      busy: busy,
      onInstall: onInstall,
    );
  }
}
