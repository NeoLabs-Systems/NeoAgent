import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppDiagnostics {
  AppDiagnostics._();

  static bool enabled = const bool.fromEnvironment(
    'NEOAGENT_VERBOSE_LOGS',
    defaultValue: true,
  );

  static int _sequence = 0;

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
    final now = DateTime.now().toIso8601String();
    final normalized = <String, Object?>{
      'ts': now,
      'area': area,
      'event': event,
      if (data.isNotEmpty) 'data': _normalizeMap(data),
      if (error != null) 'error': error.toString(),
    };

    debugPrint('[NeoDiag][$seq] ${jsonEncode(normalized)}');
    if (stackTrace != null) {
      debugPrint('[NeoDiag][$seq][stack] $stackTrace');
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
