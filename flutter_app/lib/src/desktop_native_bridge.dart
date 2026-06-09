import 'package:flutter/services.dart';

class DesktopNativeBridge {
  static const MethodChannel _channel = MethodChannel(
    'neoagent/desktop_companion_native',
  );

  Future<Map<String, Object?>> getStatus() async {
    final result = await _channel.invokeMapMethod<String, Object?>('getStatus');
    return result ?? const <String, Object?>{};
  }

  Future<Map<String, Object?>> captureFrame({String? displayId}) async {
    final result = await _channel
        .invokeMapMethod<String, Object?>('captureFrame', <String, Object?>{
          if (displayId != null && displayId.trim().isNotEmpty)
            'displayId': displayId.trim(),
        });
    return result ?? const <String, Object?>{};
  }

  Future<List<Map<String, Object?>>> listDisplays() async {
    final result = await _channel.invokeListMethod<Object?>('listDisplays');
    return (result ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }

  Future<void> click({
    required int x,
    required int y,
    required String button,
    String? displayId,
  }) {
    return _channel.invokeMethod<void>('click', <String, Object?>{
      'x': x,
      'y': y,
      'button': button,
      if (displayId != null && displayId.trim().isNotEmpty)
        'displayId': displayId.trim(),
    });
  }

  Future<void> mouseMove({
    required int x,
    required int y,
    String? displayId,
  }) {
    return _channel.invokeMethod<void>('mouseMove', <String, Object?>{
      'x': x,
      'y': y,
      if (displayId != null && displayId.trim().isNotEmpty)
        'displayId': displayId.trim(),
    });
  }

  Future<void> drag({
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int durationMs,
    String? displayId,
  }) {
    return _channel.invokeMethod<void>('drag', <String, Object?>{
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'durationMs': durationMs,
      if (displayId != null && displayId.trim().isNotEmpty)
        'displayId': displayId.trim(),
    });
  }

  Future<void> scroll({
    required int deltaX,
    required int deltaY,
    String? displayId,
  }) {
    return _channel.invokeMethod<void>('scroll', <String, Object?>{
      'deltaX': deltaX,
      'deltaY': deltaY,
      if (displayId != null && displayId.trim().isNotEmpty)
        'displayId': displayId.trim(),
    });
  }

  Future<void> typeText({required String text, required bool pressEnter}) {
    return _channel.invokeMethod<void>('typeText', <String, Object?>{
      'text': text,
      'pressEnter': pressEnter,
    });
  }

  Future<void> pressKey(String key) {
    return _channel.invokeMethod<void>('pressKey', <String, Object?>{
      'key': key,
    });
  }
}
