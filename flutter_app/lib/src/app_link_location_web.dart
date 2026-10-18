// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Uri? launchLocation() => Uri.base;

void resetLaunchLocation() {
  html.window.history.replaceState(null, '', '${Uri.base.origin}/app/');
}
