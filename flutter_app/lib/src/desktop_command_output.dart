import 'dart:convert';
import 'dart:io';

const int desktopCommandArtifactLimitBytes = 16 * 1024 * 1024;
const int desktopCommandStdoutPreviewBytes = 50000;
const int desktopCommandStderrPreviewBytes = 10000;

class _StreamPreview {
  _StreamPreview(this.limitBytes)
    : headLimit = (limitBytes * 0.2).floor(),
      tailLimit = limitBytes - (limitBytes * 0.2).floor();

  final int limitBytes;
  final int headLimit;
  final int tailLimit;
  final List<int> _full = <int>[];
  final List<int> _head = <int>[];
  final List<int> _tail = <int>[];
  int totalBytes = 0;

  void add(List<int> bytes) {
    totalBytes += bytes.length;
    if (_full.length < limitBytes) {
      _full.addAll(bytes.take(limitBytes - _full.length));
    }
    if (_head.length < headLimit) {
      _head.addAll(bytes.take(headLimit - _head.length));
    }
    _tail.addAll(bytes);
    if (_tail.length > tailLimit) {
      _tail.removeRange(0, _tail.length - tailLimit);
    }
  }

  String preview() {
    if (totalBytes <= limitBytes) {
      return utf8.decode(_full, allowMalformed: true).trim();
    }
    final head = utf8.decode(_head, allowMalformed: true).trimRight();
    final tail = utf8.decode(_tail, allowMalformed: true).trimLeft();
    return <String>[
      head,
      '...[truncated preview, $totalBytes bytes total]',
      tail,
    ].where((part) => part.isNotEmpty).join('\n');
  }
}

class DesktopCommandOutputAccumulator {
  DesktopCommandOutputAccumulator({
    this.maxArtifactBytes = desktopCommandArtifactLimitBytes,
    int stdoutPreviewBytes = desktopCommandStdoutPreviewBytes,
    int stderrPreviewBytes = desktopCommandStderrPreviewBytes,
  }) : _stdout = _StreamPreview(stdoutPreviewBytes),
       _stderr = _StreamPreview(stderrPreviewBytes);

  final int maxArtifactBytes;
  final _StreamPreview _stdout;
  final _StreamPreview _stderr;
  final List<int> _tail = <int>[];
  Directory? _directory;
  File? _file;
  IOSink? _sink;
  String? _lastStream;
  int _fileBytes = 0;
  int _artifactBytes = 0;
  bool _finalized = false;

  Future<void> initialize() async {
    _directory = await Directory.systemTemp.createTemp(
      'neoagent-command-output-',
    );
    _file = File('${_directory!.path}${Platform.pathSeparator}command.log');
    _sink = _file!.openWrite();
  }

  void add(String stream, List<int> bytes) {
    if (_sink == null || _finalized) {
      throw StateError('Command output accumulator is not active.');
    }
    if (stream == 'stderr') {
      _stderr.add(bytes);
    } else {
      _stdout.add(bytes);
    }
    final marker = _lastStream == stream
        ? const <int>[]
        : utf8.encode('${_artifactBytes == 0 ? '' : '\n'}[$stream]\n');
    _lastStream = stream;
    final combined = <int>[...marker, ...bytes];
    _artifactBytes += combined.length;
    final writable = (maxArtifactBytes - _fileBytes).clamp(0, combined.length);
    if (writable > 0) {
      _sink!.add(combined.take(writable).toList(growable: false));
      _fileBytes += writable;
    }
    _tail.addAll(combined);
    final tailLimit = maxArtifactBytes ~/ 2;
    if (_tail.length > tailLimit) {
      _tail.removeRange(0, _tail.length - tailLimit);
    }
  }

  Future<Map<String, Object?>> finalize() async {
    if (_finalized) throw StateError('Command output was already finalized.');
    _finalized = true;
    await _sink!.flush();
    await _sink!.close();
    _sink = null;
    final truncated =
        _stdout.totalBytes > _stdout.limitBytes ||
        _stderr.totalBytes > _stderr.limitBytes;
    final result = <String, Object?>{
      'stdout': _stdout.preview(),
      'stderr': _stderr.preview(),
      'stdoutBytes': _stdout.totalBytes,
      'stderrBytes': _stderr.totalBytes,
      'truncated': truncated,
    };
    if (!truncated) {
      await discard();
      return result;
    }

    final complete = _artifactBytes <= maxArtifactBytes;
    if (!complete) {
      final marker = utf8.encode(
        '\n...[artifact bounded, $_artifactBytes bytes total]...\n',
      );
      final headLimit = (maxArtifactBytes ~/ 2).clamp(
        0,
        maxArtifactBytes - marker.length,
      );
      final head = await _file!
          .openRead(0, headLimit)
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      final tailBytes = (maxArtifactBytes - head.length - marker.length).clamp(
        0,
        _tail.length,
      );
      await _file!.writeAsBytes(<int>[
        ...head,
        ...marker,
        ..._tail.skip(_tail.length - tailBytes),
      ], flush: true);
    }
    return <String, Object?>{
      ...result,
      '_outputFilePath': _file!.path,
      '_outputFileByteSize': await _file!.length(),
      '_outputFileComplete': complete,
    };
  }

  Future<void> discard() async {
    if (_sink != null) {
      await _sink!.close();
      _sink = null;
    }
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
