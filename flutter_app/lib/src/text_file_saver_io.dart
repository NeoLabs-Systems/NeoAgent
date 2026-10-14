import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<bool> saveTextFile({
  required String fileName,
  required String contents,
  required String dialogTitle,
}) async {
  final bytes = utf8.encode(contents);
  // Mobile pickers write the bytes themselves; desktop ones return a path.
  if (Platform.isAndroid || Platform.isIOS) {
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
    );
    return saved != null;
  }
  final destination = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
  );
  if (destination == null) return false;
  await File(destination).writeAsBytes(bytes, flush: true);
  return true;
}
