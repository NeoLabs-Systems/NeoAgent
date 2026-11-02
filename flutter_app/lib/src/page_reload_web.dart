// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

const bool platformCanReloadPage = true;

void platformReloadPage() => html.window.location.reload();
