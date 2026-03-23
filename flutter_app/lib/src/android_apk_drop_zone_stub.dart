import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Widget buildAndroidApkDropZone(
  BuildContext context, {
  required bool enabled,
  required bool busy,
  required Future<void> Function({
    required String filename,
    required Uint8List bytes,
  })
  onInstall,
}) {
  return const SizedBox.shrink();
}
