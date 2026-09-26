// Renders the face the Android home-screen widgets show before the app first
// publishes one, with the app's own mascot painter. Rerun after changing the
// idle frame or the painter:
//
//   flutter test tool/render_widget_face.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/mascot/mascot_mood.dart';
import 'package:neoagent_flutter/src/mascot/neo_mascot.dart';

void main() {
  test('render the widget placeholder face', () async {
    final png = await renderMascotPng(MascotMood.idle, size: 256);
    File(
      'android/app/src/main/res/drawable-nodpi/neoagent_widget_face.png',
    ).writeAsBytesSync(png);
  });
}
