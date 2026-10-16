import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class TelecomBridge {
  TelecomBridge._();

  static final TelecomBridge instance = TelecomBridge._();

  static const MethodChannel _telecomChannel = MethodChannel('neoagent/telecom');

  Future<bool> startTelecomCallRouting() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _telecomChannel.invokeMethod<void>('startCallRouting');
        return true;
      } on MissingPluginException {
        return false;
      } catch (e) {
        debugPrint(appStrings.starttelecomcallroutingErrorArg1(e));
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
        debugPrint(appStrings.stoptelecomcallroutingErrorArg1(e));
        return false;
      }
    }
    return false;
  }
}
