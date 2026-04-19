import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class AppDiagnosticEntry {
  const AppDiagnosticEntry({
    required this.sequence,
    required this.timestamp,
    required this.area,
    required this.event,
    this.data = const <String, Object?>{},
    this.error,
    this.stackTrace,
  });

  final int sequence;
  final DateTime timestamp;
  final String area;
  final String event;
  final Map<String, Object?> data;
  final String? error;
  final String? stackTrace;
}

class AppDiagnostics {
  AppDiagnostics._();

  static bool enabled = const bool.fromEnvironment(
    'NEOAGENT_VERBOSE_LOGS',
    defaultValue: true,
  );

  static int _sequence = 0;
  static const int _maxRetainedEntries = 400;
  static final StreamController<AppDiagnosticEntry> _controller =
      StreamController<AppDiagnosticEntry>.broadcast(sync: true);
  static final List<AppDiagnosticEntry> _entries = <AppDiagnosticEntry>[];

  static Stream<AppDiagnosticEntry> get stream => _controller.stream;

  static List<AppDiagnosticEntry> get recentEntries =>
      List<AppDiagnosticEntry>.unmodifiable(_entries);

  static void log(
    String area,
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) {
      return;
    }

    final seq = ++_sequence;
    final timestamp = DateTime.now();
    final now = timestamp.toIso8601String();
    final normalizedData = data.isEmpty
        ? const <String, Object?>{}
        : _normalizeMap(data);
    final normalized = <String, Object?>{
      'ts': now,
      'area': area,
      'event': event,
      if (normalizedData.isNotEmpty) 'data': normalizedData,
      if (error != null) 'error': error.toString(),
    };

    debugPrint('[NeoDiag][$seq] ${jsonEncode(normalized)}');
    if (stackTrace != null) {
      debugPrint('[NeoDiag][$seq][stack] $stackTrace');
    }

    final entry = AppDiagnosticEntry(
      sequence: seq,
      timestamp: timestamp,
      area: area,
      event: event,
      data: normalizedData,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
    _entries.add(entry);
    if (_entries.length > _maxRetainedEntries) {
      _entries.removeRange(0, _entries.length - _maxRetainedEntries);
    }
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  static Map<String, Object?> _normalizeMap(Map<String, Object?> input) {
    final output = <String, Object?>{};
    input.forEach((key, value) {
      output[key] = _normalizeValue(value);
    });
    return output;
  }

  static Object? _normalizeValue(Object? value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String ||
        value is Map<String, Object?> ||
        value is List<Object?>) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Duration) {
      return value.inMilliseconds;
    }
    return value.toString();
  }
}
