import 'package:archive/archive_io.dart';

import 'local_backend_installer_models.dart';

bool isSafeRuntimeArchivePath(String value, {String basePath = ''}) {
  final normalized = value.replaceAll(r'\', '/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      normalized.contains('\u0000') ||
      RegExp(r'^[A-Za-z]:/').hasMatch(normalized)) {
    return false;
  }
  final stack = <String>[
    for (final segment in basePath.replaceAll(r'\', '/').split('/'))
      if (segment.isNotEmpty && segment != '.') segment,
  ];
  for (final segment in normalized.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (stack.isEmpty) return false;
      stack.removeLast();
      continue;
    }
    stack.add(segment);
  }
  return stack.isNotEmpty;
}

Future<void> extractVerifiedRuntimeArchive(
  String archivePath,
  String outputPath,
) {
  return extractFileToDisk(
    archivePath,
    outputPath,
    callback: (entry) {
      if (!isSafeRuntimeArchivePath(entry.name)) {
        throw const LocalBackendInstallerException(
          'SETUP_RUNTIME_ARCHIVE_INVALID',
          'The NeoAgent runtime archive contains an unsafe path.',
          retryable: false,
        );
      }
      if (!entry.isSymbolicLink) return;
      final segments = entry.name.replaceAll(r'\', '/').split('/');
      final parent = segments.length > 1
          ? segments.sublist(0, segments.length - 1).join('/')
          : '';
      if (!isSafeRuntimeArchivePath(
        entry.symbolicLink ?? '',
        basePath: parent,
      )) {
        throw const LocalBackendInstallerException(
          'SETUP_RUNTIME_ARCHIVE_INVALID',
          'The NeoAgent runtime archive contains an unsafe link.',
          retryable: false,
        );
      }
    },
  );
}
