import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidAutoBridge {
  AndroidAutoBridge._() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _autoChannel.setMethodCallHandler(_handleMethodCall);
    }
  }

  static final AndroidAutoBridge instance = AndroidAutoBridge._();

  static const MethodChannel _autoChannel = MethodChannel('neoagent/car_auto');
  static const MethodChannel _telecomChannel = MethodChannel('neoagent/telecom');

  VoidCallback? onStartVoiceMode;
  VoidCallback? onStopVoiceMode;

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'startVoiceMode':
        onStartVoiceMode?.call();
        break;
      case 'stopVoiceMode':
        onStopVoiceMode?.call();
        break;
      default:
        throw MissingPluginException();
    }
  }

  Future<bool> startTelecomCallRouting() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _telecomChannel.invokeMethod<void>('startCallRouting');
        return true;
      } on MissingPluginException {
        return false;
      } catch (e) {
        debugPrint('startTelecomCallRouting Error: $e');
        rethrow;
      }
    }
    return false;
  }

  Future<bool> stopTelecomCallRouting() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _telecomChannel.invokeMethod<void>('stopCallRouting');
        return true;
      } catch (e) {
        debugPrint('stopTelecomCallRouting Error: $e');
        return false;
      }
    }
    return false;
  }
}
