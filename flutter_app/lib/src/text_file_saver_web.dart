// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

Future<bool> saveTextFile({
  required String fileName,
  required String contents,
  required String dialogTitle,
}) async {
  final blob = html.Blob(<String>[contents], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  // The browser reads the blob after this frame; release it a moment later.
  Timer(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(url));
  return true;
}
