import 'dart:io';
import 'dart:typed_data';

class DesktopOcrResult {
  const DesktopOcrResult({
    required this.text,
    required this.engine,
    this.confidence,
  });

  final String text;
  final String engine;
  final double? confidence;
}

class DesktopOcrBridge {
  const DesktopOcrBridge();

  static const String _binaryName = 'tesseract';

  Future<String?> unavailableReason() async {
    try {
      final result = await Process.run(_binaryName, <String>['--version']);
      if (result.exitCode == 0) {
        return null;
      }
    } catch (_) {}
    return 'Passive screen history OCR requires Tesseract to be installed and available on PATH.';
  }

  Future<DesktopOcrResult> recognize({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final reason = await unavailableReason();
    if (reason != null) {
      throw ProcessException(_binaryName, const <String>['--version'], reason, 127);
    }
    final extension =
        mimeType.toLowerCase().contains('jpeg') ||
            mimeType.toLowerCase().contains('jpg')
        ? 'jpg'
        : 'png';
    final directory = await Directory.systemTemp.createTemp(
      'neoagent-passive-ocr-',
    );
    final inputFile = File('${directory.path}/capture.$extension');
    try {
      await inputFile.writeAsBytes(bytes, flush: true);
      final result = await Process.run(_binaryName, <String>[
        inputFile.path,
        'stdout',
        '--psm',
        '6',
        'tsv',
        'quiet',
      ]);
      if (result.exitCode != 0) {
        final stderr = result.stderr?.toString().trim();
        final stdout = result.stdout?.toString().trim();
        throw ProcessException(
          _binaryName,
          <String>[inputFile.path],
          stderr?.isNotEmpty == true
              ? stderr!
              : (stdout?.isNotEmpty == true ? stdout! : 'OCR failed.'),
          result.exitCode,
        );
      }
      final parsed = _parseTsv(result.stdout?.toString() ?? '');
      return DesktopOcrResult(
        text: parsed.text,
        engine: 'tesseract',
        confidence: parsed.confidence,
      );
    } finally {
      try {
        if (await inputFile.exists()) {
          await inputFile.delete();
        }
        if (await directory.exists()) {
          await directory.delete();
        }
      } catch (_) {}
    }
  }

  ({String text, double? confidence}) _parseTsv(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.length <= 1) {
      return (text: '', confidence: null);
    }

    final words = <String>[];
    var confidenceTotal = 0.0;
    var confidenceCount = 0;
    for (final line in lines.skip(1)) {
      final columns = line.split('\t');
      if (columns.length < 12) {
        continue;
      }
      final word = columns[11].replaceAll(RegExp(r'\s+'), ' ').trim();
      if (word.isEmpty) {
        continue;
      }
      words.add(word);
      final confidence = double.tryParse(columns[10]);
      if (confidence != null && confidence >= 0) {
        confidenceTotal += confidence;
        confidenceCount += 1;
      }
    }
    return (
      text: words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      confidence: confidenceCount == 0
          ? null
          : confidenceTotal / confidenceCount,
    );
  }
}

DesktopOcrBridge createDesktopOcrBridge() => const DesktopOcrBridge();
