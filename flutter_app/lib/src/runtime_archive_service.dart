import 'dart:convert';
import 'dart:io';

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

String? rewriteRuntimeSymlinkTarget(String entryName, String target) {
  final normalized = target.replaceAll(r'\', '/').trim();
  if (normalized.isEmpty || normalized.contains('\u0000')) return null;
  final parent = _parentPosix(entryName);
  final absolute =
      normalized.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
  if (!absolute) {
    return isSafeRuntimeArchivePath(normalized, basePath: parent)
        ? normalized
        : null;
  }
  const marker = '/node_modules/';
  final index = normalized.indexOf(marker);
  if (index < 0) return null;
  final archiveTarget = 'app${normalized.substring(index)}';
  if (!isSafeRuntimeArchivePath(archiveTarget)) return null;
  return _relativePosix(parent, archiveTarget);
}

Future<void> extractVerifiedRuntimeArchive(
  String archivePath,
  String outputPath,
) async {
  Directory(outputPath).createSync(recursive: true);
  if (!Platform.isWindows && _unzipAvailable()) {
    await _assertSafeZipEntryNames(archivePath);
    final extracted = await Process.run('unzip', <String>[
      '-q',
      '-o',
      archivePath,
      '-d',
      outputPath,
    ]);
    if (extracted.exitCode != 0) {
      throw const LocalBackendInstallerException(
        'SETUP_RUNTIME_ARCHIVE_INVALID',
        'The NeoAgent runtime archive could not be extracted.',
      );
    }
    rewriteExtractedRuntimeSymlinks(outputPath);
    return;
  }
  await _extractWithArchivePackage(archivePath, outputPath);
}

void rewriteExtractedRuntimeSymlinks(String outputPath) {
  final root = Directory(outputPath);
  if (!root.existsSync()) return;
  final prefix = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (!Platform.isWindows) {
    final listed = Process.runSync('find', <String>[outputPath, '-type', 'l']);
    if (listed.exitCode == 0) {
      for (final path in LineSplitter.split(listed.stdout.toString())) {
        if (path.isEmpty) continue;
        _rewriteExtractedRuntimeSymlink(Link(path), prefix);
      }
      return;
    }
  }
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is Link) _rewriteExtractedRuntimeSymlink(entity, prefix);
  }
}

void _rewriteExtractedRuntimeSymlink(Link entity, String prefix) {
  late final String target;
  try {
    target = entity.targetSync();
  } on FileSystemException {
    return;
  }
  if (!entity.path.startsWith(prefix)) return;
  final entryName = entity.path.substring(prefix.length).replaceAll(r'\', '/');
  final rewritten = rewriteRuntimeSymlinkTarget(entryName, target);
  if (rewritten == null) {
    if (_isAbsolutePath(target)) {
      try {
        entity.deleteSync();
      } on Object {
        return;
      }
    }
    return;
  }
  if (rewritten == target) return;
  entity.deleteSync();
  entity.createSync(rewritten);
}

bool _isAbsolutePath(String value) {
  final normalized = value.replaceAll(r'\', '/');
  return normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
}

String _parentPosix(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final index = normalized.lastIndexOf('/');
  return index <= 0 ? '' : normalized.substring(0, index);
}

String _relativePosix(String fromDir, String toPath) {
  final from = [
    for (final segment in fromDir.replaceAll(r'\', '/').split('/'))
      if (segment.isNotEmpty && segment != '.') segment,
  ];
  final to = [
    for (final segment in toPath.replaceAll(r'\', '/').split('/'))
      if (segment.isNotEmpty && segment != '.') segment,
  ];
  var shared = 0;
  while (shared < from.length &&
      shared < to.length &&
      from[shared] == to[shared]) {
    shared += 1;
  }
  final parts = <String>[
    ...List<String>.filled(from.length - shared, '..'),
    ...to.skip(shared),
  ];
  return parts.isEmpty ? '.' : parts.join('/');
}

String _nativeJoin(String root, String posixRelative) {
  final suffix = posixRelative
      .replaceAll(r'\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.')
      .join(Platform.pathSeparator);
  if (suffix.isEmpty) return root;
  if (root.endsWith('/') || root.endsWith(r'\')) return '$root$suffix';
  return '$root${Platform.pathSeparator}$suffix';
}

void _restoreUnixMode(String path, int unixPermissions) {
  if (Platform.isWindows || unixPermissions == 0) return;
  Process.runSync('chmod', <String>[unixPermissions.toRadixString(8), path]);
}

bool _unzipAvailable() {
  final result = Process.runSync('which', const <String>['unzip']);
  return result.exitCode == 0;
}

Future<void> _assertSafeZipEntryNames(String archivePath) async {
  final listed = await Process.run('unzip', <String>['-Z', '-1', archivePath]);
  if (listed.exitCode != 0) {
    throw const LocalBackendInstallerException(
      'SETUP_RUNTIME_ARCHIVE_INVALID',
      'The NeoAgent runtime archive could not be read.',
      retryable: false,
    );
  }
  for (final name in LineSplitter.split(listed.stdout.toString())) {
    if (name.isEmpty) continue;
    if (!isSafeRuntimeArchivePath(name)) {
      throw const LocalBackendInstallerException(
        'SETUP_RUNTIME_ARCHIVE_INVALID',
        'The NeoAgent runtime archive contains an unsafe path.',
        retryable: false,
      );
    }
  }
}

Future<void> _extractWithArchivePackage(
  String archivePath,
  String outputPath,
) async {
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    Directory(outputPath).createSync(recursive: true);
    for (final entry in archive) {
      if (!isSafeRuntimeArchivePath(entry.name)) {
        throw const LocalBackendInstallerException(
          'SETUP_RUNTIME_ARCHIVE_INVALID',
          'The NeoAgent runtime archive contains an unsafe path.',
          retryable: false,
        );
      }
      final destination = _nativeJoin(outputPath, entry.name);
      if (entry.isDirectory && !entry.isSymbolicLink) {
        Directory(destination).createSync(recursive: true);
        continue;
      }
      File(destination).parent.createSync(recursive: true);
      if (entry.isSymbolicLink) {
        final rewritten = rewriteRuntimeSymlinkTarget(
          entry.name,
          entry.symbolicLink ?? '',
        );
        if (rewritten == null) {
          if (_isAbsolutePath(entry.symbolicLink ?? '')) continue;
          throw const LocalBackendInstallerException(
            'SETUP_RUNTIME_ARCHIVE_INVALID',
            'The NeoAgent runtime archive contains an unsafe link.',
            retryable: false,
          );
        }
        Link(destination).createSync(rewritten);
        continue;
      }
      if (!entry.isFile) continue;
      final output = OutputFileStream(destination);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
      _restoreUnixMode(destination, entry.unixPermissions);
    }
    await archive.clear();
  } finally {
    await input.close();
  }
}
