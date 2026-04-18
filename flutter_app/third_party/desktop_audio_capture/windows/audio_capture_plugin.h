#ifndef FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace audio_capture {

class AudioCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AudioCapturePlugin();

  virtual ~AudioCapturePlugin();

  // Disallow copy and assign.
  AudioCapturePlugin(const AudioCapturePlugin&) = delete;
  AudioCapturePlugin& operator=(const AudioCapturePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace audio_capture

#endif  // FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
